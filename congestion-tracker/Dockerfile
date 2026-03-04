FROM rocker/shiny:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c( \
  'plumber', 'httr2', 'dplyr', 'lubridate', 'jsonlite', \
  'shiny', 'bslib', 'ggplot2', 'leaflet', 'callr' \
), repos='https://cloud.r-project.org')"

WORKDIR /app
COPY api/       api/
COPY dashboard/ dashboard/
COPY data/locations.csv  data/locations.csv
COPY data/readings.csv   data/readings.csv
COPY db/        db/
COPY start.R    start.R

EXPOSE 3838

CMD ["Rscript", "start.R"]
