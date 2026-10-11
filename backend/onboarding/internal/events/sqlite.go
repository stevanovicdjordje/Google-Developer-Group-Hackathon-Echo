package events

import (
	"database/sql"
	"errors"
	"time"
)

type SQLiteRepo struct{ db *sql.DB }

func NewSQLiteRepo(db *sql.DB) *SQLiteRepo { return &SQLiteRepo{db: db} }

func unixPtr(t *time.Time) any {
	if t == nil {
		return nil
	}
	return t.Unix()
}

func floatPtr(f *float64) any {
	if f == nil {
		return nil
	}
	return *f
}

func timePtr(n sql.NullInt64) *time.Time {
	if !n.Valid {
		return nil
	}
	t := time.Unix(n.Int64, 0).UTC()
	return &t
}

func fPtr(n sql.NullFloat64) *float64 {
	if !n.Valid {
		return nil
	}
	v := n.Float64
	return &v
}

const eventCols = `e.id, e.organization_id, e.title, e.description, e.starts_at, e.ends_at,
	e.address, e.lat, e.lng, e.published_at, e.created_at, e.updated_at`

type scanner interface{ Scan(...any) error }

func scanEvent(row scanner, extra ...any) (Event, error) {
	var e Event
	var starts, ends, published sql.NullInt64
	var lat, lng sql.NullFloat64
	var created, updated int64
	dest := append([]any{&e.ID, &e.OrganizationID, &e.Title, &e.Description, &starts, &ends,
		&e.Address, &lat, &lng, &published, &created, &updated}, extra...)
	if err := row.Scan(dest...); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return Event{}, ErrNotFound
		}
		return Event{}, err
	}
	e.StartsAt, e.EndsAt, e.PublishedAt = timePtr(starts), timePtr(ends), timePtr(published)
	e.Lat, e.Lng = fPtr(lat), fPtr(lng)
	e.CreatedAt, e.UpdatedAt = time.Unix(created, 0).UTC(), time.Unix(updated, 0).UTC()
	return e, nil
}

func (r *SQLiteRepo) Create(e Event) error {
	_, err := r.db.Exec(`INSERT INTO events (id, organization_id, title, description, starts_at, ends_at,
		address, lat, lng, published_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
		e.ID, e.OrganizationID, e.Title, e.Description, unixPtr(e.StartsAt), unixPtr(e.EndsAt),
		e.Address, floatPtr(e.Lat), floatPtr(e.Lng), unixPtr(e.PublishedAt), e.CreatedAt.Unix(), e.UpdatedAt.Unix())
	return err
}

func (r *SQLiteRepo) Update(e Event) error {
	res, err := r.db.Exec(`UPDATE events SET title=?, description=?, starts_at=?, ends_at=?, address=?,
		lat=?, lng=?, published_at=?, updated_at=? WHERE id=?`,
		e.Title, e.Description, unixPtr(e.StartsAt), unixPtr(e.EndsAt), e.Address,
		floatPtr(e.Lat), floatPtr(e.Lng), unixPtr(e.PublishedAt), e.UpdatedAt.Unix(), e.ID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *SQLiteRepo) Get(id string) (Event, error) {
	return scanEvent(r.db.QueryRow(`SELECT `+eventCols+` FROM events e WHERE e.id = ?`, id))
}

const statsCols = `
	(SELECT COUNT(*) FROM invitations i WHERE i.event_id = e.id),
	(SELECT COUNT(*) FROM invitations i WHERE i.event_id = e.id AND i.status = 'accepted'),
	(SELECT COUNT(*) FROM invitations i WHERE i.event_id = e.id AND i.status = 'declined'),
	(SELECT COUNT(*) FROM reviews v WHERE v.event_id = e.id),
	(SELECT COALESCE(AVG(v.rating), 0) FROM reviews v WHERE v.event_id = e.id)`

func (r *SQLiteRepo) ListByOrganization(orgID string) ([]Summary, error) {
	rows, err := r.db.Query(`SELECT `+eventCols+`,`+statsCols+` FROM events e WHERE e.organization_id = ?`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Summary
	for rows.Next() {
		var s Summary
		ev, err := scanEvent(rows, &s.Invited, &s.Accepted, &s.Declined, &s.Reviews, &s.AvgRating)
		if err != nil {
			return nil, err
		}
		s.Event = ev
		out = append(out, s)
	}
	return out, rows.Err()
}

func (r *SQLiteRepo) StatsFor(eventID string) (Stats, error) {
	var s Stats
	err := r.db.QueryRow(`SELECT `+statsCols[1:]+` FROM events e WHERE e.id = ?`, eventID).
		Scan(&s.Invited, &s.Accepted, &s.Declined, &s.Reviews, &s.AvgRating)
	if errors.Is(err, sql.ErrNoRows) {
		return Stats{}, ErrNotFound
	}
	return s, err
}

func (r *SQLiteRepo) GetVenueMap(eventID string) (VenueMap, error) {
	m := VenueMap{EventID: eventID}
	var up int64
	err := r.db.QueryRow(`SELECT file_name, content_type, width, height, uploaded_at FROM venue_maps WHERE event_id = ?`,
		eventID).Scan(&m.FileName, &m.ContentType, &m.Width, &m.Height, &up)
	if errors.Is(err, sql.ErrNoRows) {
		return VenueMap{}, ErrNotFound
	}
	m.UploadedAt = time.Unix(up, 0).UTC()
	return m, err
}

func (r *SQLiteRepo) SaveVenueMap(m VenueMap) error {
	_, err := r.db.Exec(`INSERT INTO venue_maps (event_id, file_name, content_type, width, height, uploaded_at)
		VALUES (?,?,?,?,?,?) ON CONFLICT(event_id) DO UPDATE SET file_name=excluded.file_name,
		content_type=excluded.content_type, width=excluded.width, height=excluded.height, uploaded_at=excluded.uploaded_at`,
		m.EventID, m.FileName, m.ContentType, m.Width, m.Height, m.UploadedAt.Unix())
	return err
}

func (r *SQLiteRepo) ListZones(eventID string) ([]Zone, error) {
	rows, err := r.db.Query(`SELECT id, event_id, name, kind, x, y, w, h, created_at FROM zones
		WHERE event_id = ? ORDER BY created_at, name`, eventID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Zone
	for rows.Next() {
		var z Zone
		var kind string
		var created int64
		if err := rows.Scan(&z.ID, &z.EventID, &z.Name, &kind, &z.X, &z.Y, &z.W, &z.H, &created); err != nil {
			return nil, err
		}
		z.Kind, z.Created = ZoneKind(kind), time.Unix(created, 0).UTC()
		out = append(out, z)
	}
	return out, rows.Err()
}

func (r *SQLiteRepo) CreateZone(z Zone) error {
	_, err := r.db.Exec(`INSERT INTO zones (id, event_id, name, kind, x, y, w, h, created_at) VALUES (?,?,?,?,?,?,?,?,?)`,
		z.ID, z.EventID, z.Name, string(z.Kind), z.X, z.Y, z.W, z.H, z.Created.Unix())
	return err
}

func (r *SQLiteRepo) DeleteZone(eventID, zoneID string) error {
	_, err := r.db.Exec(`DELETE FROM zones WHERE id = ? AND event_id = ?`, zoneID, eventID)
	return err
}

func (r *SQLiteRepo) ListSessions(eventID string) ([]Session, error) {
	rows, err := r.db.Query(`SELECT id, event_id, COALESCE(zone_id, ''), title, description, speaker, starts_at, ends_at
		FROM sessions WHERE event_id = ? ORDER BY starts_at, title`, eventID)
	if err != nil {
		return nil, err
	}
	var out []Session
	idx := map[string]int{}
	for rows.Next() {
		var s Session
		var st, en int64
		if err := rows.Scan(&s.ID, &s.EventID, &s.ZoneID, &s.Title, &s.Description, &s.Speaker, &st, &en); err != nil {
			rows.Close()
			return nil, err
		}
		s.StartsAt, s.EndsAt = time.Unix(st, 0).UTC(), time.Unix(en, 0).UTC()
		idx[s.ID] = len(out)
		out = append(out, s)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	tags, err := r.db.Query(`SELECT t.session_id, t.tag FROM session_tags t JOIN sessions s ON s.id = t.session_id
		WHERE s.event_id = ? ORDER BY t.tag`, eventID)
	if err != nil {
		return nil, err
	}
	defer tags.Close()
	for tags.Next() {
		var sid, tag string
		if err := tags.Scan(&sid, &tag); err != nil {
			return nil, err
		}
		if i, ok := idx[sid]; ok {
			out[i].Tags = append(out[i].Tags, tag)
		}
	}
	return out, tags.Err()
}

func (r *SQLiteRepo) CreateSession(s Session) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var zone any
	if s.ZoneID != "" {
		zone = s.ZoneID
	}
	if _, err := tx.Exec(`INSERT INTO sessions (id, event_id, zone_id, title, description, speaker, starts_at, ends_at, created_at)
		VALUES (?,?,?,?,?,?,?,?,?)`, s.ID, s.EventID, zone, s.Title, s.Description, s.Speaker,
		s.StartsAt.Unix(), s.EndsAt.Unix(), time.Now().Unix()); err != nil {
		return err
	}
	for _, t := range s.Tags {
		if _, err := tx.Exec(`INSERT OR IGNORE INTO session_tags (session_id, tag) VALUES (?,?)`, s.ID, t); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *SQLiteRepo) DeleteSession(eventID, sessionID string) error {
	_, err := r.db.Exec(`DELETE FROM sessions WHERE id = ? AND event_id = ?`, sessionID, eventID)
	return err
}
