library(callr)

api_proc <- r_bg(function() {
  library(plumber)
  pr_run(pr("api/plumber.R"), host = "0.0.0.0", port = 8000)
}, supervise = TRUE)

Sys.sleep(3)
message("Plumber API started on port 8000")

shiny::runApp("dashboard/app.R", host = "0.0.0.0", port = 3838)
