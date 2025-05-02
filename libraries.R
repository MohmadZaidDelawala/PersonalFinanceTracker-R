# libraries.R
packages <- c(
  "shiny", "shinydashboard", "shinydashboardPlus", "plotly", "RMySQL",
  "dplyr", "openxlsx", "shinythemes", "rmarkdown", "knitr", "httr",
  "jsonlite", "sodium", "lubridate", "prophet", "ggplot2", "tinytex",
  "shinyjs", "blastula"
)
invisible(lapply(packages, function(pkg) {
  if (!require(pkg, character.only = TRUE)) install.packages(pkg)
}))
