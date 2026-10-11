-- Events, venue maps, zones, sessions, invitations, reviews.
-- "ongoing" and "finished" are derived from dates and are not stored.

CREATE TABLE events (
    id              TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    description     TEXT NOT NULL DEFAULT '',
    starts_at       INTEGER,
    ends_at         INTEGER,
    address         TEXT NOT NULL DEFAULT '',
    lat             REAL,
    lng             REAL,
    published_at    INTEGER,
    created_at      INTEGER NOT NULL,
    updated_at      INTEGER NOT NULL
);
CREATE INDEX idx_events_org ON events(organization_id);

CREATE TABLE venue_maps (
    event_id     TEXT PRIMARY KEY REFERENCES events(id) ON DELETE CASCADE,
    file_name    TEXT NOT NULL,
    content_type TEXT NOT NULL,
    width        INTEGER NOT NULL,
    height       INTEGER NOT NULL,
    uploaded_at  INTEGER NOT NULL
);

-- Positions are percentages of the floor-plan image.
CREATE TABLE zones (
    id         TEXT PRIMARY KEY,
    event_id   TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    kind       TEXT NOT NULL CHECK (kind IN ('hall', 'booth', 'entrance', 'toilet', 'food', 'info', 'other')),
    x          REAL NOT NULL CHECK (x >= 0 AND x < 100),
    y          REAL NOT NULL CHECK (y >= 0 AND y < 100),
    w          REAL NOT NULL CHECK (w > 0 AND x + w <= 100),
    h          REAL NOT NULL CHECK (h > 0 AND y + h <= 100),
    created_at INTEGER NOT NULL
);
CREATE INDEX idx_zones_event ON zones(event_id);

CREATE TABLE sessions (
    id          TEXT PRIMARY KEY,
    event_id    TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    zone_id     TEXT REFERENCES zones(id) ON DELETE SET NULL,
    title       TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    speaker     TEXT NOT NULL DEFAULT '',
    starts_at   INTEGER NOT NULL,
    ends_at     INTEGER NOT NULL CHECK (ends_at > starts_at),
    created_at  INTEGER NOT NULL
);
CREATE INDEX idx_sessions_event ON sessions(event_id, starts_at);

-- Topic tags; together with participant_interests they can feed AI matching.
CREATE TABLE session_tags (
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    tag        TEXT NOT NULL,
    PRIMARY KEY (session_id, tag)
);

-- "expired" is derived (time-to-live or event finished), not stored.
CREATE TABLE invitations (
    id           TEXT PRIMARY KEY,
    event_id     TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    email        TEXT NOT NULL,
    token        TEXT NOT NULL UNIQUE,
    status       TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'accepted', 'declined')),
    user_id      TEXT REFERENCES users(id) ON DELETE SET NULL,
    expires_at   INTEGER NOT NULL,
    created_at   INTEGER NOT NULL,
    responded_at INTEGER,
    UNIQUE (event_id, email)
);
CREATE INDEX idx_invitations_user ON invitations(user_id);

CREATE TABLE reviews (
    id         TEXT PRIMARY KEY,
    event_id   TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment    TEXT NOT NULL DEFAULT '',
    anonymous  INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE (event_id, user_id)
);

CREATE TABLE session_ratings (
    review_id  TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    PRIMARY KEY (review_id, session_id)
);
