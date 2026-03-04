# City Congestion Tracker

**Live Demo:** https://dl-l7al8.ondigitalocean.app/

A full-stack congestion-tracking system that stores traffic data in Supabase, exposes it through a REST API, visualizes it in a Shiny dashboard, and generates AI-powered insights via OpenAI.

## Architecture

```
Supabase (PostgreSQL)
       │
       ▼
  Plumber REST API  ──▶  Shiny Dashboard  ──▶  OpenAI (GPT-4o-mini)
   :8000                  :3838
```

**Pipeline:** Database → API → Dashboard → AI

## Project Structure

```
congestion-tracker/
├── data/
│   ├── generate_data.R     # Synthetic data generator + Supabase upload
│   ├── locations.csv        # 10 monitoring locations
│   └── readings.csv         # ~1,690 hourly congestion readings
├── db/
│   └── schema.sql           # Supabase table definitions
├── api/
│   └── plumber.R            # REST API (4 endpoints)
├── dashboard/
│   └── app.R                # Shiny dashboard with AI summary
├── Dockerfile               # Container for deployment
├── docker-compose.yml
├── start.R                  # Entrypoint: starts API + Shiny
├── codebook.md              # Data dictionary
└── README.md
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/locations` | All 10 monitoring locations |
| GET | `/congestion` | Readings with optional filters (`location_id`, `from`, `min_level`) |
| GET | `/congestion/top?n=5` | Top N most congested locations right now |
| GET | `/congestion/hourly-pattern` | Average congestion by hour of day |

## Data

Synthetic data simulating 7 days of traffic across 10 intersections in 3 zones (Downtown, Midtown, Outskirts). Congestion levels follow realistic rush-hour patterns:

- **Morning rush** (7–9 AM): avg ~7/10
- **Evening rush** (5–7 PM): avg ~8/10
- **Night** (10 PM–5 AM): avg ~2/10
- **Off-peak**: avg ~4/10

Each reading includes: `congestion_level` (0–10), `speed_mph`, and `delay_min`.

## Setup

### Prerequisites

- R 4.3+
- R packages: `shiny`, `bslib`, `plumber`, `httr2`, `dplyr`, `lubridate`, `ggplot2`, `leaflet`, `jsonlite`, `callr`
- A Supabase project with tables created from `db/schema.sql`
- An OpenAI API key

### 1. Install R packages

```r
install.packages(c(
  "shiny", "bslib", "plumber", "httr2", "dplyr",
  "lubridate", "ggplot2", "leaflet", "jsonlite", "callr"
))
```

### 2. Create `.env` file

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key
OPENAI_API_KEY=sk-your-openai-key
```

### 3. Set up Supabase

Run `db/schema.sql` in the Supabase SQL Editor to create the `locations` and `readings` tables, then enable RLS policies for public read/insert access.

### 4. Generate and upload data

```r
setwd("data")
readRenviron("../.env")
source("generate_data.R")
```

This generates ~1,690 rows and uploads them to Supabase.

### 5. Run locally

```r
readRenviron(".env")
shiny::runApp("dashboard/app.R")
```

The Shiny app auto-starts the Plumber API in the background. No need for two consoles.

## Deployment (DigitalOcean App Platform)

1. Push repo to GitHub
2. DigitalOcean → Create App → connect GitHub repo
3. Set **Source Directory** to `/congestion-tracker`
4. Add environment variables: `SUPABASE_URL`, `SUPABASE_KEY`, `OPENAI_API_KEY`, `API_BASE=http://localhost:8000`
5. Set HTTP port to `3838`
6. Deploy

## AI Integration

The dashboard includes an **AI Summary** button that sends aggregated congestion statistics to OpenAI's `gpt-4o-mini` model. The AI returns a structured insight covering:

- **Status** — overall congestion severity
- **Worst Areas** — top locations by congestion level
- **Pattern** — peak hour analysis
- **Recommendation** — areas/times to avoid

The prompt is constrained to use only the provided data, preventing hallucination.
