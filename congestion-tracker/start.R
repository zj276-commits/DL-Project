library(callr)
library(httr2)

api_proc <- r_bg(function() {
  library(plumber)
  pr_run(pr("api/plumber.R"), host = "0.0.0.0", port = 8000)
}, supervise = TRUE)

for (i in 1:30) {
  ready <- tryCatch(
    { request("http://localhost:8000/locations") |> req_perform(); TRUE },
    error = function(e) FALSE
  )
  if (ready) break
  Sys.sleep(2)
}

if (ready) {
  message("Plumber API is ready on port 8000")
} else {
  stop("Plumber API failed to start after 60 seconds")
}

shiny::runApp("dashboard/app.R", host = "0.0.0.0", port = 3838)
