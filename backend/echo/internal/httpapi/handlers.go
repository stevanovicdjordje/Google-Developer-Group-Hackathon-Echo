package httpapi

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/Ilij4n/eho/backend/echo/internal/assist"
	"github.com/Ilij4n/eho/backend/echo/internal/auth"
	"github.com/Ilij4n/eho/backend/echo/internal/store"
)

const (
	maxBodyBytes       = 16 << 10
	maxTranslateLines  = 50
	translateChunk     = 10
	translateParallel  = 4
	defaultLanguage    = "en"
	notStartedResponse = "The talk hasn't started yet."
)

var sessionIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)

type fieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

type aiText struct {
	Text         string `json:"text"`
	Model        string `json:"model"`
	BasedOnLines int    `json:"basedOnLines"`
}

type questionJSON struct {
	ID        string    `json:"id"`
	Text      string    `json:"text"`
	Votes     int       `json:"votes"`
	Mine      bool      `json:"mine"`
	Voted     bool      `json:"voted"`
	CreatedAt time.Time `json:"createdAt"`
}

func decode(w http.ResponseWriter, r *http.Request, dst any) bool {
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	if err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "body_too_large", fmt.Sprintf("request body exceeds %d bytes", maxBodyBytes), nil)
		return false
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json", "request body is not valid JSON for this operation", err.Error())
		return false
	}
	return true
}

func invalid(w http.ResponseWriter, errs ...fieldError) {
	writeError(w, http.StatusUnprocessableEntity, "validation_failed", "request is invalid", errs)
}

func (s *server) respondErr(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "not_found", "not found", nil)
	case errors.Is(err, store.ErrNoTranscript):
		writeError(w, http.StatusNotFound, "no_transcript", "this session has no transcript yet", nil)
	case errors.Is(err, assist.ErrModel), errors.Is(err, context.DeadlineExceeded):
		s.log.WarnContext(r.Context(), "ai call failed", "route", r.Pattern, "err", err)
		writeError(w, http.StatusBadGateway, "ai_unavailable", "the AI model is unavailable, try again", nil)
	default:
		s.log.ErrorContext(r.Context(), "request failed", "route", r.Pattern, "err", err)
		writeError(w, http.StatusInternalServerError, "internal", "internal server error", nil)
	}
}

type errRateLimited struct{ retryAfter int }

func (e errRateLimited) Error() string { return "rate limited" }

func (s *server) rateLimited(w http.ResponseWriter, retryAfter int) {
	w.Header().Set("Retry-After", strconv.Itoa(retryAfter))
	writeError(w, http.StatusTooManyRequests, "rate_limited", "too many requests, slow down", nil)
}

// session resolves the path to a visible event and its transcript so far.
// Attendees see published events; the owner sees their event before publishing.
func (s *server) session(w http.ResponseWriter, r *http.Request, p auth.Principal) (eventID, sessionID string, t store.Transcript, ok bool) {
	eventID, sessionID = r.PathValue("eventId"), r.PathValue("sessionId")
	if !sessionIDPattern.MatchString(sessionID) {
		writeError(w, http.StatusNotFound, "not_found", "not found", nil)
		return "", "", t, false
	}
	ev, err := s.store.GetEvent(r.Context(), eventID)
	if err == nil && !ev.Published() && ev.OwnerUID != p.UID {
		err = store.ErrNotFound
	}
	if err == nil {
		t, err = s.store.GetTranscript(r.Context(), eventID, sessionID)
	}
	if err != nil {
		s.respondErr(w, r, err)
		return "", "", t, false
	}
	return eventID, sessionID, t, true
}

func languageParam(w http.ResponseWriter, field, lang string) (string, bool) {
	if lang == "" {
		return defaultLanguage, true
	}
	if _, ok := assist.Languages[lang]; !ok {
		invalid(w, fieldError{field, "unsupported language"})
		return "", false
	}
	return lang, true
}

// cachedAI returns the cached result for key or generates it once, even when
// many attendees ask at the same moment. Only cache misses count against the
// caller's AI budget. The offline assistant is cheap and never cached.
func (s *server) cachedAI(ctx context.Context, uid, eventID, sessionID, key string, n int, gen func(context.Context) (string, error)) (store.Cached, error) {
	if s.ai.Model() == assist.OfflineModel {
		text, err := gen(ctx)
		return store.Cached{Text: text, Model: assist.OfflineModel, Lines: n}, err
	}
	key = s.ai.Model() + "_" + assist.PromptVersion + "_" + key
	if c, ok, err := s.store.GetCached(ctx, eventID, sessionID, key); err != nil {
		return store.Cached{}, err
	} else if ok {
		return c, nil
	}
	if ok, retry := s.aiLimit.allow(uid); !ok {
		return store.Cached{}, errRateLimited{retry}
	}
	v, err, _ := s.inflight.Do(eventID+"/"+sessionID+"/"+key, func() (any, error) {
		text, err := gen(context.WithoutCancel(ctx))
		if err != nil {
			return nil, err
		}
		c := store.Cached{Text: text, Model: s.ai.Model(), Lines: n}
		if err := s.store.PutCached(context.WithoutCancel(ctx), eventID, sessionID, key, c); err != nil {
			s.log.WarnContext(ctx, "cache write failed", "err", err)
		}
		return c, nil
	})
	if err != nil {
		return store.Cached{}, err
	}
	return v.(store.Cached), nil
}

func (s *server) writeAI(w http.ResponseWriter, r *http.Request, c store.Cached, err error) {
	var rl errRateLimited
	if errors.As(err, &rl) {
		s.rateLimited(w, rl.retryAfter)
		return
	}
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, aiText{Text: c.Text, Model: c.Model, BasedOnLines: c.Lines})
}

func (s *server) notStarted(w http.ResponseWriter) {
	writeJSON(w, http.StatusOK, aiText{Text: notStartedResponse, Model: s.ai.Model(), BasedOnLines: 0})
}

func (s *server) ask(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, sessionID, t, ok := s.session(w, r, p)
	if !ok {
		return
	}
	var in struct {
		Question string `json:"question"`
		Language string `json:"language"`
	}
	if !decode(w, r, &in) {
		return
	}
	q := strings.Join(strings.Fields(in.Question), " ")
	if n := utf8.RuneCountInString(q); n < 1 || n > 500 {
		invalid(w, fieldError{"question", "must be 1 to 500 characters"})
		return
	}
	lang, ok := languageParam(w, "language", in.Language)
	if !ok {
		return
	}
	if len(t.Lines) == 0 {
		s.notStarted(w)
		return
	}
	sum := sha256.Sum256([]byte(strings.ToLower(q)))
	key := fmt.Sprintf("ask_%s_%d_%s", lang, len(t.Lines), hex.EncodeToString(sum[:8]))
	c, err := s.cachedAI(r.Context(), p.UID, eventID, sessionID, key, len(t.Lines), func(ctx context.Context) (string, error) {
		return s.ai.Ask(ctx, t, q, lang)
	})
	s.writeAI(w, r, c, err)
}

func (s *server) catchUp(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	s.summarize(w, r, p, "catchup", s.ai.CatchUp)
}

func (s *server) summary(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	s.summarize(w, r, p, "summary", s.ai.Summary)
}

func (s *server) summarize(w http.ResponseWriter, r *http.Request, p auth.Principal, kind string,
	gen func(context.Context, store.Transcript, string) (string, error)) {
	eventID, sessionID, t, ok := s.session(w, r, p)
	if !ok {
		return
	}
	lang, ok := languageParam(w, "language", r.URL.Query().Get("language"))
	if !ok {
		return
	}
	if len(t.Lines) == 0 {
		s.notStarted(w)
		return
	}
	key := fmt.Sprintf("%s_%s_%d", kind, lang, len(t.Lines))
	c, err := s.cachedAI(r.Context(), p.UID, eventID, sessionID, key, len(t.Lines), func(ctx context.Context) (string, error) {
		return gen(ctx, t, lang)
	})
	s.writeAI(w, r, c, err)
}

type translatedLine struct {
	Index int    `json:"index"`
	Text  string `json:"text"`
}

func (s *server) translate(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, sessionID, t, ok := s.session(w, r, p)
	if !ok {
		return
	}
	var in struct {
		Language  string `json:"language"`
		FromIndex int    `json:"fromIndex"`
	}
	if !decode(w, r, &in) {
		return
	}
	if in.Language == "" {
		invalid(w, fieldError{"language", "is required"})
		return
	}
	lang, ok := languageParam(w, "language", in.Language)
	if !ok {
		return
	}
	if in.FromIndex < 0 {
		invalid(w, fieldError{"fromIndex", "must be 0 or more"})
		return
	}
	from := min(in.FromIndex, len(t.Lines))
	window := t.Lines[from:min(from+maxTranslateLines, len(t.Lines))]
	resp := struct {
		Language  string           `json:"language"`
		Lines     []translatedLine `json:"lines"`
		NextIndex int              `json:"nextIndex"`
		Model     string           `json:"model"`
	}{Language: lang, Lines: []translatedLine{}, NextIndex: from + len(window), Model: s.ai.Model()}
	if len(window) == 0 {
		writeJSON(w, http.StatusOK, resp)
		return
	}

	cacheLang := s.ai.Model() + "_" + assist.PromptVersion + "_" + lang
	have, err := s.store.GetTranslations(r.Context(), eventID, sessionID, cacheLang)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	var missing []store.Line
	for _, l := range window {
		if _, ok := have[l.Index]; !ok {
			missing = append(missing, l)
		}
	}
	if len(missing) > 0 {
		if ok, retry := s.aiLimit.allow(p.UID); !ok {
			s.rateLimited(w, retry)
			return
		}
		key := fmt.Sprintf("%s/%s/%s/%d-%d", eventID, sessionID, cacheLang, missing[0].Index, missing[len(missing)-1].Index)
		v, err, _ := s.inflight.Do(key, func() (any, error) {
			return s.translateLines(context.WithoutCancel(r.Context()), eventID, sessionID, cacheLang, lang, missing)
		})
		if err != nil {
			s.respondErr(w, r, err)
			return
		}
		for i, text := range v.(map[int]string) {
			have[i] = text
		}
	}
	for _, l := range window {
		resp.Lines = append(resp.Lines, translatedLine{Index: l.Index, Text: have[l.Index]})
	}
	writeJSON(w, http.StatusOK, resp)
}

// translateLines translates in chunks of translateChunk lines, up to
// translateParallel chunks at a time, so a 50-line backlog takes about as long
// as two model calls.
func (s *server) translateLines(ctx context.Context, eventID, sessionID, cacheLang, lang string, lines []store.Line) (map[int]string, error) {
	var (
		mu       sync.Mutex
		out      = make(map[int]string, len(lines))
		firstErr error
		wg       sync.WaitGroup
		sem      = make(chan struct{}, translateParallel)
	)
	for start := 0; start < len(lines); start += translateChunk {
		chunk := lines[start:min(start+translateChunk, len(lines))]
		wg.Add(1)
		sem <- struct{}{}
		go func() {
			defer func() { <-sem; wg.Done() }()
			got, err := s.translateChunk(ctx, lang, chunk)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				if firstErr == nil {
					firstErr = err
				}
				return
			}
			for i, t := range got {
				out[i] = t
			}
		}()
	}
	wg.Wait()
	if len(out) > 0 {
		if err := s.store.PutTranslations(ctx, eventID, sessionID, cacheLang, out); err != nil {
			s.log.WarnContext(ctx, "translation cache write failed", "err", err)
		}
	}
	if firstErr != nil {
		return nil, firstErr
	}
	return out, nil
}

func (s *server) translateChunk(ctx context.Context, lang string, chunk []store.Line) (map[int]string, error) {
	texts := make([]string, len(chunk))
	for i, l := range chunk {
		texts[i] = l.Text
	}
	res, err := s.ai.Translate(ctx, texts, lang)
	if err != nil {
		return nil, err
	}
	if len(res) != len(chunk) {
		return nil, fmt.Errorf("%w: got %d translations for %d lines", assist.ErrModel, len(res), len(chunk))
	}
	got := make(map[int]string, len(chunk))
	for i, l := range chunk {
		got[l.Index] = res[i]
	}
	return got, nil
}

func toJSON(q store.Question, uid string) questionJSON {
	return questionJSON{
		ID: q.ID, Text: q.Text, Votes: q.Votes(), Mine: q.AuthorUID == uid, Voted: q.VotedBy(uid), CreatedAt: q.CreatedAt,
	}
}

func (s *server) listQuestions(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, sessionID, _, ok := s.session(w, r, p)
	if !ok {
		return
	}
	qs, err := s.store.ListQuestions(r.Context(), eventID, sessionID)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	slices.SortStableFunc(qs, func(a, b store.Question) int {
		if a.Votes() != b.Votes() {
			return b.Votes() - a.Votes()
		}
		return a.CreatedAt.Compare(b.CreatedAt)
	})
	out := make([]questionJSON, len(qs))
	for i, q := range qs {
		out[i] = toJSON(q, p.UID)
	}
	writeJSON(w, http.StatusOK, map[string]any{"questions": out})
}

func (s *server) submitQuestion(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	eventID, sessionID, _, ok := s.session(w, r, p)
	if !ok {
		return
	}
	var in struct {
		Text string `json:"text"`
	}
	if !decode(w, r, &in) {
		return
	}
	text := strings.Join(strings.Fields(in.Text), " ")
	if n := utf8.RuneCountInString(text); n < 3 || n > 300 {
		invalid(w, fieldError{"text", "must be 3 to 300 characters"})
		return
	}
	if ok, retry := s.askLimit.allow(p.UID); !ok {
		s.rateLimited(w, retry)
		return
	}
	q := store.Question{Text: text, AuthorUID: p.UID, VoterUIDs: []string{p.UID}}
	if err := s.store.CreateQuestion(r.Context(), eventID, sessionID, &q); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, toJSON(q, p.UID))
}

func (s *server) vote(on bool) func(http.ResponseWriter, *http.Request, auth.Principal) {
	return func(w http.ResponseWriter, r *http.Request, p auth.Principal) {
		eventID, sessionID, _, ok := s.session(w, r, p)
		if !ok {
			return
		}
		q, err := s.store.SetVote(r.Context(), eventID, sessionID, r.PathValue("questionId"), p.UID, on)
		if err != nil {
			s.respondErr(w, r, err)
			return
		}
		writeJSON(w, http.StatusOK, toJSON(q, p.UID))
	}
}
