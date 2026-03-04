library(plumber)
library(httr2)
library(dplyr)
library(lubridate)
library(jsonlite)

SUPABASE_URL <- Sys.getenv("SUPABASE_URL")
SUPABASE_KEY <- Sys.getenv("SUPABASE_KEY")

sb_get <- function(table, params = list()) {
  req <- request(paste0(SUPABASE_URL, "/rest/v1/", table)) |>
    req_headers(
      "apikey"        = SUPABASE_KEY,
      "Authorization" = paste("Bearer", SUPABASE_KEY)
    ) |>
    req_url_query(!!!params, select = "*")
  resp <- req_perform(req)
  resp_body_json(resp, simplifyVector = TRUE)
}

#* @apiTitle Congestion Tracker API
#* @apiVersion 1.0

#* Get all locations
#* @get /locations
function() {
  sb_get("locations")
}

#* Get congestion readings
#* @param location_id:character Filter by location (optional)
#* @param from:character Start timestamp ISO8601 (optional)
#* @param to:character End timestamp ISO8601 (optional)
#* @param min_level:character Minimum congestion level 0-10 (optional)
#* @get /congestion
function(location_id = "", from = "", to = "", min_level = "") {
  params <- list(order = "timestamp.desc", limit = 500)
  if (location_id != "") params[["location_id"]] <- paste0("eq.", location_id)
  if (from != "")        params[["timestamp"]]   <- paste0("gte.", from)
  if (min_level != "")   params[["congestion_level"]] <- paste0("gte.", min_level)
  sb_get("readings", params)
}

#* Get current top congested locations
#* @param n Number of top locations (default 5)
#* @get /congestion/top
function(n = 5) {
  data <- sb_get("readings", list(
    order  = "timestamp.desc",
    limit  = 200,
    select = "location_id,congestion_level,timestamp"
  ))
  data |>
    as_tibble() |>
    group_by(location_id) |>
    slice_max(timestamp, n = 1) |>
    ungroup() |>
    arrange(desc(congestion_level)) |>
    head(as.integer(n))
}

#* Get hourly average congestion (last 7 days)
#* @get /congestion/hourly-pattern
function() {
  data <- sb_get("readings", list(limit = 5000, order = "timestamp.desc"))
  as_tibble(data) |>
    mutate(hour = hour(ymd_hms(timestamp, quiet = TRUE))) |>
    group_by(hour) |>
    summarise(avg_congestion = mean(congestion_level, na.rm = TRUE), .groups = "drop") |>
    arrange(hour)
}
