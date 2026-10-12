CREATE TABLE event (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  name text NOT NULL DEFAULT 'Testevent',
  start_lat double precision,
  start_lng double precision,
  reveal_time timestamptz,
  start_time timestamptz NOT NULL DEFAULT now(),
  duration_h int NOT NULL DEFAULT 24,
  checkin_interval_min int NOT NULL DEFAULT 300,
  checkin_window_min int NOT NULL DEFAULT 30,
  silence_alarm_min int NOT NULL DEFAULT 360,
  speed_flag_kmh double precision NOT NULL DEFAULT 12,
  orga_phone text NOT NULL DEFAULT ''
);
INSERT INTO event (id) VALUES (1);

CREATE TABLE team (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','aborted','finished')),
  status_changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE participant (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES team(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  device_id text NOT NULL UNIQUE,
  token_hash text NOT NULL,
  joined_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE location_point (
  id uuid PRIMARY KEY,  -- client-generated
  team_id uuid NOT NULL REFERENCES team(id) ON DELETE CASCADE,
  participant_id uuid NOT NULL REFERENCES participant(id) ON DELETE CASCADE,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  accuracy double precision,
  speed double precision,
  battery double precision,
  recorded_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX location_point_team_recorded ON location_point (team_id, recorded_at);

CREATE TABLE checkin (
  id uuid PRIMARY KEY,  -- client-generated
  team_id uuid NOT NULL REFERENCES team(id) ON DELETE CASCADE,
  participant_id uuid NOT NULL REFERENCES participant(id) ON DELETE CASCADE,
  slot int NOT NULL,
  media_path text NOT NULL,
  media_type text NOT NULL CHECK (media_type IN ('photo','video')),
  captured_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX checkin_team_captured ON checkin (team_id, captured_at);

CREATE TABLE alert (
  id uuid PRIMARY KEY,  -- client-generated
  team_id uuid NOT NULL REFERENCES team(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('sos','abort')),
  lat double precision,
  lng double precision,
  created_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  note text
);

CREATE TABLE ranking_snapshot (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  computed_at timestamptz NOT NULL,
  team_id uuid NOT NULL REFERENCES team(id) ON DELETE CASCADE,
  rank int NOT NULL,
  distance_km double precision,
  is_final boolean NOT NULL DEFAULT false
);
CREATE INDEX ranking_snapshot_computed ON ranking_snapshot (computed_at);
