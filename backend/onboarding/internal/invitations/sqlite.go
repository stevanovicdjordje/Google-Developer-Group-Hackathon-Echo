package invitations

import (
	"database/sql"
	"errors"
	"strings"
	"time"
)

type SQLiteRepo struct{ db *sql.DB }

func NewSQLiteRepo(db *sql.DB) *SQLiteRepo { return &SQLiteRepo{db: db} }

const cols = `id, event_id, email, token, status, COALESCE(user_id, ''), expires_at, created_at, responded_at`

type scanner interface{ Scan(...any) error }

func scan(row scanner) (Invitation, error) {
	var inv Invitation
	var st string
	var exp, created int64
	var resp sql.NullInt64
	if err := row.Scan(&inv.ID, &inv.EventID, &inv.Email, &inv.Token, &st, &inv.UserID, &exp, &created, &resp); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Invitation{}, ErrNotFound
		}
		return Invitation{}, err
	}
	inv.Status = Status(st)
	inv.ExpiresAt, inv.CreatedAt = time.Unix(exp, 0).UTC(), time.Unix(created, 0).UTC()
	if resp.Valid {
		t := time.Unix(resp.Int64, 0).UTC()
		inv.RespondedAt = &t
	}
	return inv, nil
}

func (r *SQLiteRepo) list(query string, args ...any) ([]Invitation, error) {
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Invitation
	for rows.Next() {
		inv, err := scan(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, inv)
	}
	return out, rows.Err()
}

func (r *SQLiteRepo) Create(inv Invitation) error {
	var user any
	if inv.UserID != "" {
		user = inv.UserID
	}
	_, err := r.db.Exec(`INSERT INTO invitations (id, event_id, email, token, status, user_id, expires_at, created_at)
		VALUES (?,?,?,?,?,?,?,?)`, inv.ID, inv.EventID, inv.Email, inv.Token, string(inv.Status), user,
		inv.ExpiresAt.Unix(), inv.CreatedAt.Unix())
	if err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed: invitations.event_id") {
		return ErrDuplicate
	}
	return err
}

func (r *SQLiteRepo) ListByEvent(eventID string) ([]Invitation, error) {
	return r.list(`SELECT `+cols+` FROM invitations WHERE event_id = ? ORDER BY created_at DESC, email`, eventID)
}

func (r *SQLiteRepo) GetByToken(token string) (Invitation, error) {
	return scan(r.db.QueryRow(`SELECT `+cols+` FROM invitations WHERE token = ?`, token))
}

func (r *SQLiteRepo) Respond(id, userID string, st Status, at time.Time) error {
	var user any
	if userID != "" {
		user = userID
	}
	// Keep an existing binding when an anonymous visitor declines.
	_, err := r.db.Exec(`UPDATE invitations SET status = ?, user_id = COALESCE(?, user_id), responded_at = ? WHERE id = ?`,
		string(st), user, at.Unix(), id)
	return err
}

func (r *SQLiteRepo) HasAccepted(eventID, userID string) (bool, error) {
	var n int
	err := r.db.QueryRow(`SELECT COUNT(*) FROM invitations WHERE event_id = ? AND user_id = ? AND status = 'accepted'`,
		eventID, userID).Scan(&n)
	return n > 0, err
}

func (r *SQLiteRepo) ListForParticipant(userID, email string) ([]Invitation, error) {
	return r.list(`SELECT `+cols+` FROM invitations
		WHERE user_id = ? OR (user_id IS NULL AND email = ?) ORDER BY created_at DESC`, userID, email)
}
