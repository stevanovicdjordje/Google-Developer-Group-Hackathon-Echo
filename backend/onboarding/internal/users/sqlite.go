package users

import (
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
)

type SQLiteRepo struct {
	db  *sql.DB
	now func() time.Time
}

func NewSQLiteRepo(db *sql.DB) *SQLiteRepo {
	return &SQLiteRepo{db: db, now: time.Now}
}

func isUnique(err error) bool {
	return err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed")
}

func (r *SQLiteRepo) insertUser(tx *sql.Tx, u User) error {
	_, err := tx.Exec(
		`INSERT INTO users (id, email, full_name, role, password_hash, created_at) VALUES (?,?,?,?,?,?)`,
		u.ID, u.Email, u.FullName, string(u.Role), u.PasswordHash, u.CreatedAt.Unix())
	if isUnique(err) {
		return ErrEmailTaken
	}
	return err
}

func (r *SQLiteRepo) CreateOrganizer(u User, org Organization) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := r.insertUser(tx, u); err != nil {
		return err
	}
	if _, err := tx.Exec(
		`INSERT INTO organizations (id, owner_id, name, website, created_at) VALUES (?,?,?,?,?)`,
		org.ID, org.OwnerID, org.Name, org.Website, org.CreatedAt.Unix()); err != nil {
		return err
	}
	return tx.Commit()
}

func (r *SQLiteRepo) CreateParticipant(u User) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := r.insertUser(tx, u); err != nil {
		return err
	}
	if _, err := tx.Exec(
		`INSERT INTO participant_profiles (user_id, onboarding_step, updated_at) VALUES (?,1,?)`,
		u.ID, u.CreatedAt.Unix()); err != nil {
		return err
	}
	return tx.Commit()
}

func (r *SQLiteRepo) scanUser(row *sql.Row) (User, error) {
	var u User
	var role string
	var created int64
	err := row.Scan(&u.ID, &u.Email, &u.FullName, &role, &u.PasswordHash, &created)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, err
	}
	u.Role = Role(role)
	u.CreatedAt = time.Unix(created, 0).UTC()
	return u, nil
}

const userCols = `SELECT id, email, full_name, role, password_hash, created_at FROM users`

func (r *SQLiteRepo) GetByID(id string) (User, error) {
	return r.scanUser(r.db.QueryRow(userCols+` WHERE id = ?`, id))
}

func (r *SQLiteRepo) GetByEmail(email string) (User, error) {
	return r.scanUser(r.db.QueryRow(userCols+` WHERE email = ?`, email))
}

func (r *SQLiteRepo) GetOrganizationByOwner(ownerID string) (Organization, error) {
	var o Organization
	var created int64
	err := r.db.QueryRow(
		`SELECT id, owner_id, name, website, created_at FROM organizations WHERE owner_id = ? ORDER BY created_at LIMIT 1`,
		ownerID).Scan(&o.ID, &o.OwnerID, &o.Name, &o.Website, &created)
	if errors.Is(err, sql.ErrNoRows) {
		return Organization{}, ErrNotFound
	}
	if err != nil {
		return Organization{}, err
	}
	o.CreatedAt = time.Unix(created, 0).UTC()
	return o, nil
}

func (r *SQLiteRepo) GetProfile(userID string) (Profile, error) {
	p := Profile{UserID: userID}
	var goal string
	var visible int
	var completed sql.NullInt64
	err := r.db.QueryRow(
		`SELECT caption_language, goal, visible, onboarding_step, onboarding_completed_at
		   FROM participant_profiles WHERE user_id = ?`, userID).
		Scan(&p.CaptionLanguage, &goal, &visible, &p.OnboardingStep, &completed)
	if errors.Is(err, sql.ErrNoRows) {
		return Profile{}, ErrNotFound
	}
	if err != nil {
		return Profile{}, err
	}
	p.Goal = Goal(goal)
	p.Visible = visible == 1
	if completed.Valid {
		t := time.Unix(completed.Int64, 0).UTC()
		p.CompletedAt = &t
	}
	rows, err := r.db.Query(
		`SELECT topic, is_custom FROM participant_interests WHERE user_id = ? ORDER BY position`, userID)
	if err != nil {
		return Profile{}, err
	}
	defer rows.Close()
	for rows.Next() {
		var topic string
		var custom int
		if err := rows.Scan(&topic, &custom); err != nil {
			return Profile{}, err
		}
		p.Interests = append(p.Interests, topic)
		if custom == 1 {
			p.CustomInterests = append(p.CustomInterests, topic)
		}
	}
	return p, rows.Err()
}

func (r *SQLiteRepo) SaveProfile(p Profile) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var completed any
	if p.CompletedAt != nil {
		completed = p.CompletedAt.Unix()
	}
	visible := 0
	if p.Visible {
		visible = 1
	}
	res, err := tx.Exec(
		`UPDATE participant_profiles
		    SET caption_language = ?, goal = ?, visible = ?, onboarding_step = ?,
		        onboarding_completed_at = ?, updated_at = ?
		  WHERE user_id = ?`,
		p.CaptionLanguage, string(p.Goal), visible, p.OnboardingStep, completed, r.now().Unix(), p.UserID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	if _, err := tx.Exec(`DELETE FROM participant_interests WHERE user_id = ?`, p.UserID); err != nil {
		return err
	}
	custom := map[string]bool{}
	for _, c := range p.CustomInterests {
		custom[c] = true
	}
	for i, topic := range p.Interests {
		isCustom := 0
		if custom[topic] {
			isCustom = 1
		}
		if _, err := tx.Exec(
			`INSERT OR IGNORE INTO participant_interests (user_id, topic, is_custom, position) VALUES (?,?,?,?)`,
			p.UserID, topic, isCustom, i); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *SQLiteRepo) GrantConsent(userID, kind, version string) error {
	_, err := r.db.Exec(
		`INSERT INTO consents (id, user_id, kind, version, granted_at) VALUES (?,?,?,?,?)`,
		id.New(), userID, kind, version, r.now().Unix())
	return err
}

func (r *SQLiteRepo) HasConsent(userID, kind string) (bool, error) {
	var n int
	err := r.db.QueryRow(
		`SELECT COUNT(*) FROM consents WHERE user_id = ? AND kind = ? AND withdrawn_at IS NULL`,
		userID, kind).Scan(&n)
	return n > 0, err
}
