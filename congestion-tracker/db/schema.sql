-- Table 1: locations
CREATE TABLE locations (
  location_id   TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  zone          TEXT,
  lat           NUMERIC,
  lng           NUMERIC
);

-- Table 2: readings
CREATE TABLE readings (
  id              BIGSERIAL PRIMARY KEY,
  location_id     TEXT REFERENCES locations(location_id),
  timestamp       TIMESTAMPTZ NOT NULL,
  congestion_level NUMERIC CHECK (congestion_level BETWEEN 0 AND 10),
  speed_mph       NUMERIC,
  delay_min       NUMERIC
);
