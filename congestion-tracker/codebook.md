# Codebook

## Table: `locations`

| Column | Type | Description |
|--------|------|-------------|
| `location_id` | TEXT (PK) | Unique identifier, e.g. `LOC1` – `LOC10` |
| `name` | TEXT | Human-readable intersection name, e.g. "Main St & 1st Ave" |
| `zone` | TEXT | City zone: `Downtown`, `Midtown`, or `Outskirts` |
| `lat` | NUMERIC | Latitude (synthetic, NYC area ~40.70–40.80) |
| `lng` | NUMERIC | Longitude (synthetic, NYC area ~-74.02 to -73.92) |

## Table: `readings`

| Column | Type | Description |
|--------|------|-------------|
| `id` | BIGSERIAL (PK) | Auto-incrementing row ID |
| `location_id` | TEXT (FK → locations) | References `locations.location_id` |
| `timestamp` | TIMESTAMPTZ | UTC timestamp of the reading (hourly intervals) |
| `congestion_level` | NUMERIC | Congestion severity, 0 (free flow) to 10 (gridlock) |
| `speed_mph` | NUMERIC | Average traffic speed in miles per hour |
| `delay_min` | NUMERIC | Estimated delay in minutes compared to free-flow conditions |

## Data Generation

- **Script:** `data/generate_data.R`
- **Seed:** `set.seed(42)` for reproducibility
- **Locations:** 10 fixed intersections across 3 zones
- **Readings:** 7 days × 24 hours × 10 locations = ~1,690 rows
- **Congestion model:** Base level varies by time of day with Gaussian noise (sd = 1.2)

## Files

| File | Rows | Description |
|------|------|-------------|
| `data/locations.csv` | 10 | All monitoring locations |
| `data/readings.csv` | ~1,690 | Hourly congestion readings for 7 days |
