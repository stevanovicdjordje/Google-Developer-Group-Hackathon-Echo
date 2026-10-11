package reviews

import (
	"database/sql"
	"errors"
	"time"
)

type SQLiteRepo struct{ db *sql.DB }

func NewSQLiteRepo(db *sql.DB) *SQLiteRepo { return &SQLiteRepo{db: db} }

func (r *SQLiteRepo) sessionRatings(reviewIDs ...string) (map[string]map[string]int, error) {
	out := map[string]map[string]int{}
	for _, id := range reviewIDs {
		rows, err := r.db.Query(`SELECT session_id, rating FROM session_ratings WHERE review_id = ?`, id)
		if err != nil {
			return nil, err
		}
		m := map[string]int{}
		for rows.Next() {
			var sid string
			var n int
			if err := rows.Scan(&sid, &n); err != nil {
				rows.Close()
				return nil, err
			}
			m[sid] = n
		}
		rows.Close()
		out[id] = m
	}
	return out, nil
}

func (r *SQLiteRepo) Get(eventID, userID string) (Review, error) {
	var rv Review
	var anon int
	var created, updated int64
	err := r.db.QueryRow(`SELECT id, event_id, user_id, rating, comment, anonymous, created_at, updated_at
		FROM reviews WHERE event_id = ? AND user_id = ?`, eventID, userID).
		Scan(&rv.ID, &rv.EventID, &rv.UserID, &rv.Rating, &rv.Comment, &anon, &created, &updated)
	if errors.Is(err, sql.ErrNoRows) {
		return Review{}, ErrNotFound
	}
	if err != nil {
		return Review{}, err
	}
	rv.Anonymous = anon == 1
	rv.CreatedAt, rv.UpdatedAt = time.Unix(created, 0).UTC(), time.Unix(updated, 0).UTC()
	m, err := r.sessionRatings(rv.ID)
	if err != nil {
		return Review{}, err
	}
	rv.SessionRatings = m[rv.ID]
	return rv, nil
}

func (r *SQLiteRepo) Save(rv Review) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	anon := 0
	if rv.Anonymous {
		anon = 1
	}
	// The UNIQUE(event_id, user_id) constraint enforces one review per participant.
	if _, err := tx.Exec(`INSERT INTO reviews (id, event_id, user_id, rating, comment, anonymous, created_at, updated_at)
		VALUES (?,?,?,?,?,?,?,?)
		ON CONFLICT(event_id, user_id) DO UPDATE SET rating=excluded.rating, comment=excluded.comment,
		anonymous=excluded.anonymous, updated_at=excluded.updated_at`,
		rv.ID, rv.EventID, rv.UserID, rv.Rating, rv.Comment, anon, rv.CreatedAt.Unix(), rv.UpdatedAt.Unix()); err != nil {
		return err
	}
	var id string
	if err := tx.QueryRow(`SELECT id FROM reviews WHERE event_id = ? AND user_id = ?`, rv.EventID, rv.UserID).Scan(&id); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM session_ratings WHERE review_id = ?`, id); err != nil {
		return err
	}
	for sid, n := range rv.SessionRatings {
		if _, err := tx.Exec(`INSERT INTO session_ratings (review_id, session_id, rating)
			SELECT ?, s.id, ? FROM sessions s WHERE s.id = ? AND s.event_id = ?`, id, n, sid, rv.EventID); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *SQLiteRepo) ListByEvent(eventID string) ([]WithAuthor, error) {
	rows, err := r.db.Query(`SELECT v.id, v.event_id, v.user_id, v.rating, v.comment, v.anonymous, v.created_at, v.updated_at,
		u.full_name, u.email FROM reviews v JOIN users u ON u.id = v.user_id
		WHERE v.event_id = ? ORDER BY v.updated_at DESC`, eventID)
	if err != nil {
		return nil, err
	}
	var out []WithAuthor
	var ids []string
	for rows.Next() {
		var w WithAuthor
		var anon int
		var created, updated int64
		if err := rows.Scan(&w.ID, &w.EventID, &w.UserID, &w.Rating, &w.Comment, &anon, &created, &updated,
			&w.AuthorName, &w.AuthorEmail); err != nil {
			rows.Close()
			return nil, err
		}
		w.Anonymous = anon == 1
		w.CreatedAt, w.UpdatedAt = time.Unix(created, 0).UTC(), time.Unix(updated, 0).UTC()
		out = append(out, w)
		ids = append(ids, w.ID)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	m, err := r.sessionRatings(ids...)
	if err != nil {
		return nil, err
	}
	for i := range out {
		out[i].SessionRatings = m[out[i].ID]
	}
	return out, nil
}
