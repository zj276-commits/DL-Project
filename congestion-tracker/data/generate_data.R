library(dplyr)
library(lubridate)
library(httr2)
library(jsonlite)

set.seed(42)

# ── Supabase credentials (loaded from .env) ──────────────────────────
readRenviron("../.env")
SUPABASE_URL <- Sys.getenv("SUPABASE_URL")
SUPABASE_KEY <- Sys.getenv("SUPABASE_KEY")

if (SUPABASE_URL == "" || SUPABASE_KEY == "") {
  stop("Missing SUPABASE_URL or SUPABASE_KEY. Check your .env file.")
}

# ── 1. Generate locations ─────────────────────────────────────────────
locations <- tibble(
  location_id = paste0("LOC", 1:10),
  name = c("Main St & 1st Ave", "Broadway & 5th", "Harbor Tunnel",
            "Elm Rd & Park Blvd", "Central Bridge", "Airport Connector",
            "Riverside Dr", "Downtown Loop", "West Gate Rd", "South Bypass"),
  zone = rep(c("Downtown", "Midtown", "Outskirts"), c(4, 3, 3)),
  lat  = runif(10, 40.70, 40.80),
  lng  = runif(10, -74.02, -73.92)
)

# ── 2. Generate readings (7 days × 24 hours × 10 locations) ──────────
timestamps <- seq(
  from = Sys.time() - days(7),
  to   = Sys.time(),
  by   = "1 hour"
)

readings <- expand.grid(
  location_id = locations$location_id,
  timestamp   = timestamps
) |>
  as_tibble() |>
  mutate(
    hour = hour(timestamp),
    base = case_when(
      hour %in% 7:9   ~ 7,
      hour %in% 17:19  ~ 8,
      hour %in% c(22:23, 0:5) ~ 2,
      TRUE             ~ 4
    ),
    congestion_level = pmin(10, pmax(0, base + rnorm(n(), 0, 1.2))),
    speed_mph  = pmax(5, 60 - congestion_level * 5 + rnorm(n(), 0, 3)),
    delay_min  = pmax(0, congestion_level * 2 + rnorm(n(), 0, 1))
  ) |>
  select(location_id, timestamp, congestion_level, speed_mph, delay_min)

# ── 3. Save local CSVs ───────────────────────────────────────────────
write.csv(locations, "locations.csv", row.names = FALSE)
write.csv(readings,  "readings.csv",  row.names = FALSE)
cat("Generated", nrow(readings), "rows locally\n")

# ── 4. Upload to Supabase ────────────────────────────────────────────
upload <- function(table, df, batch_size = 500) {
  n <- nrow(df)
  batches <- ceiling(n / batch_size)
  cat("Uploading", n, "rows to", table, "in", batches, "batches...\n")

  for (i in seq_len(batches)) {
    start <- (i - 1) * batch_size + 1
    end   <- min(i * batch_size, n)
    chunk <- df[start:end, ]

    resp <- request(paste0(SUPABASE_URL, "/rest/v1/", table)) |>
      req_headers(
        apikey        = SUPABASE_KEY,
        Authorization = paste("Bearer", SUPABASE_KEY),
        `Content-Type`  = "application/json",
        Prefer          = "return=minimal"
      ) |>
      req_body_json(chunk, auto_unbox = TRUE) |>
      req_perform()

    if (resp_status(resp) >= 300) {
      stop("Upload failed for ", table, " batch ", i, ": ", resp_body_string(resp))
    }
    cat("  batch", i, "/", batches, "done\n")
  }
  cat("✓", table, "upload complete\n")
}

upload("locations", locations)
upload("readings", readings)

cat("\nAll done! Check Supabase Table Editor to verify.\n")
