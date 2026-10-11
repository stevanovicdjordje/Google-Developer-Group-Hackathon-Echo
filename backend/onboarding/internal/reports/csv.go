package reports

import (
	"encoding/csv"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/reviews"
)

// safeCell neutralizes spreadsheet formula injection (cells starting with
// = + - @ or a control character are prefixed with a quote).
func safeCell(s string) string {
	if s != "" && strings.ContainsRune("=+-@\t\r", rune(s[0])) {
		return "'" + s
	}
	return s
}

// WriteCSV writes one row per review with the raw event rating, comment and
// one column per session. Anonymous reviews have no author columns.
func WriteCSV(w io.Writer, revs []reviews.WithAuthor, sessions []events.Session, loc *time.Location) error {
	cw := csv.NewWriter(w)
	header := []string{"review_id", "updated_at", "author_name", "author_email", "anonymous", "event_rating", "comment"}
	for _, s := range sessions {
		header = append(header, "session: "+safeCell(s.Title))
	}
	if err := cw.Write(header); err != nil {
		return err
	}
	for _, rv := range revs {
		name, email := rv.AuthorName, rv.AuthorEmail
		if rv.Anonymous {
			name, email = "", ""
		}
		row := []string{rv.ID, rv.UpdatedAt.In(loc).Format(time.RFC3339), safeCell(name), safeCell(email),
			strconv.FormatBool(rv.Anonymous), strconv.Itoa(rv.Rating), safeCell(rv.Comment)}
		for _, s := range sessions {
			if n, ok := rv.SessionRatings[s.ID]; ok {
				row = append(row, strconv.Itoa(n))
			} else {
				row = append(row, "")
			}
		}
		if err := cw.Write(row); err != nil {
			return err
		}
	}
	cw.Flush()
	return cw.Error()
}
