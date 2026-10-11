-- Users, organizations, participant profiles, consents, login sessions.
-- IDs are random hex strings (portable to Firestore later). Times are unix seconds (UTC).

CREATE TABLE users (
    id            TEXT PRIMARY KEY,
    email         TEXT NOT NULL UNIQUE,
    full_name     TEXT NOT NULL,
    -- 'admin' is reserved for a future platform super-admin; not used yet.
    role          TEXT NOT NULL CHECK (role IN ('organizer', 'participant', 'admin')),
    password_hash TEXT NOT NULL,
    created_at    INTEGER NOT NULL
);

CREATE TABLE organizations (
    id         TEXT PRIMARY KEY,
    owner_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    website    TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL
);
CREATE INDEX idx_organizations_owner ON organizations(owner_id);

CREATE TABLE participant_profiles (
    user_id                 TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    caption_language        TEXT NOT NULL DEFAULT '',
    goal                    TEXT NOT NULL DEFAULT '',
    -- Networking visibility is opt-in: default OFF.
    visible                 INTEGER NOT NULL DEFAULT 0,
    onboarding_step         INTEGER NOT NULL DEFAULT 1,
    onboarding_completed_at INTEGER,
    updated_at              INTEGER NOT NULL
);

-- One row per interest, so it can later feed AI matching.
CREATE TABLE participant_interests (
    user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    topic     TEXT NOT NULL,
    is_custom INTEGER NOT NULL DEFAULT 0,
    position  INTEGER NOT NULL,
    PRIMARY KEY (user_id, topic)
);

CREATE TABLE consents (
    id           TEXT PRIMARY KEY,
    user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind         TEXT NOT NULL,
    version      TEXT NOT NULL,
    granted_at   INTEGER NOT NULL,
    withdrawn_at INTEGER
);
CREATE INDEX idx_consents_user ON consents(user_id, kind);

-- Only a SHA-256 of the cookie token is stored.
CREATE TABLE auth_sessions (
    token_hash TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
);
CREATE INDEX idx_auth_sessions_expires ON auth_sessions(expires_at);
