library(shiny)
library(bslib)
library(httr2)
library(dplyr)
library(lubridate)
library(ggplot2)
library(leaflet)
library(jsonlite)

API_BASE       <- Sys.getenv("API_BASE", "http://localhost:8000")
OPENAI_API_KEY <- Sys.getenv("OPENAI_API_KEY")

api_alive <- tryCatch(
  { request(paste0(API_BASE, "/locations")) |> req_perform(); TRUE },
  error = function(e) FALSE
)
if (!api_alive) {
  api_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), "..", "api"))
  bg_api <<- callr::r_bg(function(d) {
    readRenviron(file.path(d, "..", ".env"))
    plumber::pr_run(plumber::pr(file.path(d, "plumber.R")), port = 8000)
  }, args = list(d = api_dir), supervise = TRUE)
  Sys.sleep(3)
  message("Plumber API started in background on port 8000")
}

api_get <- function(path, ...) {
  resp <- request(paste0(API_BASE, path)) |>
    req_url_query(...) |>
    req_perform()
  resp_body_json(resp, simplifyVector = TRUE)
}

loc_names_cache <- NULL
get_loc_names <- function() {
  if (is.null(loc_names_cache)) {
    locs <- api_get("/locations") |> as_tibble()
    loc_names_cache <<- setNames(locs$name, locs$location_id)
  }
  loc_names_cache
}

get_ai_summary <- function(data_text) {
  prompt <- paste0(
    "You are a city traffic analyst. Analyze ONLY the data provided below.\n",
    "STRICT RULES:\n",
    "- Use ONLY the numbers and locations from the DATA section.\n",
    "- NEVER invent, assume, or estimate data not explicitly provided.\n",
    "- If data for a location is not listed, do NOT mention it.\n",
    "- Keep the entire response under 100 words.\n",
    "- Use plain text only. No markdown headers, no bullet symbols.\n\n",
    "Write exactly 4 short paragraphs with these labels:\n\n",
    "Status: One sentence on overall congestion severity (use the avg number).\n\n",
    "Worst Areas: List the top 2-3 locations from the data with their exact numbers.\n\n",
    "Pattern: One sentence about which hours are worst (use the peak hour numbers).\n\n",
    "Recommendation: One sentence on what to avoid.\n\n",
    "DATA:\n", data_text
  )

  resp <- request("https://api.openai.com/v1/chat/completions") |>
    req_headers(
      "Content-Type"  = "application/json",
      "Authorization" = paste("Bearer", OPENAI_API_KEY)
    ) |>
    req_body_json(list(
      model    = "gpt-4o-mini",
      messages = list(list(role = "user", content = prompt)),
      max_tokens = 300
    )) |>
    req_timeout(60) |>
    req_perform()

  resp_body_json(resp)$choices[[1]]$message$content
}

ui <- page_sidebar(
  title = "City Congestion Tracker",
  theme = bs_theme(bootswatch = "flatly"),
  sidebar = sidebar(
    selectInput("location", "Filter by Location", choices = c("All Locations")),
    dateRangeInput("daterange", "Date Range",
                   start = Sys.Date() - 30, end = Sys.Date()),
    hr(),
    actionButton("summarize", "AI Summary", class = "btn-success w-100")
  ),
  layout_columns(
    col_widths = c(8, 4),
    card(card_header("Congestion Map"),
         leafletOutput("map", height = 350)),
    card(card_header("Top Congested Now"),
         tableOutput("top_table"))
  ),
  card(card_header("Hourly Pattern (Last 7 Days)"),
       plotOutput("hourly_plot", height = 250)),
  card(card_header("AI Insight"),
       uiOutput("ai_summary"))
)

server <- function(input, output, session) {

  observe({
    locs <- api_get("/locations")
    choices <- c("All Locations", setNames(locs$location_id, locs$name))
    updateSelectInput(session, "location", choices = choices)

    readings <- api_get("/congestion")
    if (nrow(readings) > 0) {
      dates <- as.Date(readings$timestamp)
      updateDateRangeInput(session, "daterange",
                           start = min(dates, na.rm = TRUE),
                           end   = max(dates, na.rm = TRUE))
    }
  })

  filtered_data <- reactive({
    loc <- if (input$location == "All Locations") "" else input$location
    api_get("/congestion",
      location_id = loc,
      from        = paste0(input$daterange[1], "T00:00:00Z"),
      to          = paste0(input$daterange[2], "T23:59:59Z")
    ) |> as_tibble()
  })

  output$map <- renderLeaflet({
    locs <- api_get("/locations")
    top  <- api_get("/congestion/top", n = 10)
    locs <- left_join(as_tibble(locs), as_tibble(top), by = "location_id")
    pal  <- colorNumeric("RdYlGn", domain = c(0, 10), reverse = TRUE)
    leaflet(locs) |>
      addTiles() |>
      addCircleMarkers(
        ~lng, ~lat,
        color  = ~pal(congestion_level),
        radius = ~(congestion_level + 2),
        popup  = ~paste0("<b>", name, "</b><br>Congestion: ",
                         round(congestion_level, 1))
      )
  })

  output$top_table <- renderTable({
    loc_map <- get_loc_names()
    api_get("/congestion/top", n = 5) |>
      as_tibble() |>
      transmute(
        Location   = unname(loc_map[location_id]),
        Congestion = round(congestion_level, 1)
      )
  })

  output$hourly_plot <- renderPlot({
    df <- filtered_data()
    if (nrow(df) == 0) return(NULL)

    pattern <- df |>
      mutate(hour = hour(ymd_hms(timestamp, quiet = TRUE))) |>
      group_by(hour) |>
      summarise(avg_congestion = mean(congestion_level, na.rm = TRUE),
                .groups = "drop") |>
      arrange(hour)

    loc_label <- if (input$location == "All Locations") {
      "All Locations"
    } else {
      get_loc_names()[input$location]
    }

    ggplot(pattern, aes(hour, avg_congestion)) +
      geom_line(color = "#e74c3c", linewidth = 1.2) +
      geom_area(fill = "#e74c3c", alpha = 0.2) +
      scale_x_continuous(breaks = seq(0, 23, 3)) +
      scale_y_continuous(limits = c(0, 10)) +
      labs(x = "Hour of Day", y = "Avg Congestion Level",
           title = paste("Congestion by Hour \u2014", loc_label)) +
      theme_minimal(base_size = 14)
  })

  ai_text <- reactiveVal("Click 'AI Summary' to generate an insight.")

  output$ai_summary <- renderUI({
    tags$div(
      style = "white-space: pre-wrap; word-wrap: break-word;
               font-size: 14px; line-height: 1.7; padding: 8px 4px;
               max-height: 300px; overflow-y: auto;",
      ai_text()
    )
  })

  observeEvent(input$summarize, {
    df <- filtered_data()
    if (nrow(df) == 0) {
      ai_text("No data available for the selected filters.")
      return()
    }

    loc_map  <- get_loc_names()
    loc_label <- if (input$location == "All Locations") {
      "all locations"
    } else {
      paste0(get_loc_names()[input$location], " (", input$location, ")")
    }

    hourly <- df |>
      mutate(hour = hour(ymd_hms(timestamp, quiet = TRUE))) |>
      group_by(hour) |>
      summarise(avg = round(mean(congestion_level), 1), .groups = "drop") |>
      arrange(desc(avg)) |>
      head(3)

    top_locs <- df |>
      group_by(location_id) |>
      summarise(
        avg = round(mean(congestion_level), 1),
        max = round(max(congestion_level), 1),
        .groups = "drop"
      ) |>
      arrange(desc(avg)) |>
      head(5) |>
      mutate(name = unname(loc_map[location_id]))

    stats <- paste0(
      "Scope: ", loc_label, "\n",
      "Period: ", input$daterange[1], " to ", input$daterange[2], "\n",
      "Total readings: ", nrow(df), "\n",
      "Average congestion: ", round(mean(df$congestion_level), 1), " / 10\n",
      "Maximum congestion: ", round(max(df$congestion_level), 1), " / 10\n",
      "Worst hours: ",
      paste0(hourly$hour, ":00 (", hourly$avg, "/10)", collapse = ", "), "\n",
      "Worst locations:\n",
      paste0("  ", top_locs$name, ": avg ", top_locs$avg,
             ", max ", top_locs$max, collapse = "\n")
    )

    ai_text("Generating insight...")

    tryCatch({
      result <- get_ai_summary(stats)
      ai_text(result)
    }, error = function(e) {
      ai_text(paste("Error generating summary:", e$message))
    })
  })
}

shinyApp(ui, server)
