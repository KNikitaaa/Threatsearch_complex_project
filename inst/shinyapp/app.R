#' Netwalker Shiny Application
#'
#' Main application file for the Netwalker network analysis tool.
#' This file initializes and runs the Shiny application.
#'
#' @name app
#' @docType package
NULL

#' Run Netwalker Shiny Application
#'
#' Launches the Netwalker Shiny application for interactive network analysis
#'
#' @param host Host address to bind to (default: "127.0.0.1")
#' @param port Port number to listen on (default: 3838)
#' @param launch.browser Whether to launch the default browser (default: TRUE)
#' @param display.mode Display mode for the application (default: "normal")
#' @return A Shiny application object
#' @export
#' @examples
#' \dontrun{
#' # Run the application
#' run_netwalker_app()
#'
#' # Run on a specific port
#' run_netwalker_app(port = 8080)
#' }
run_netwalker_app <- function(host = "127.0.0.1",
                              port = 3838,
                              launch.browser = TRUE,
                              display.mode = "normal") {

  # Validate inputs
  if (!is.numeric(port) || port < 1 || port > 65535) {
    stop("Port must be a number between 1 and 65535")
  }

  if (!display.mode %in% c("auto", "normal", "showcase")) {
    stop("display.mode must be one of: 'auto', 'normal', 'showcase'")
  }

  # Ensure required packages are available
  required_packages <- c(
    "shiny", "shinythemes", "shinyjs", "shinyWidgets",
    "plotly", "leaflet", "DT", "dplyr", "ggplot2",
    "stringr", "lubridate", "RColorBrewer"
  )

  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

  if (length(missing_packages) > 0) {
    stop("Missing required packages: ", paste(missing_packages, collapse = ", "),
         ". Please install them with install.packages().")
  }

  # Source required files if not already loaded
  # (This is typically handled by the package loading mechanism)

  # Create and run the application
  app <- shiny::shinyApp(
    ui = ui,
    server = server,
    options = list(
      host = host,
      port = port,
      launch.browser = launch.browser,
      display.mode = display.mode
    )
  )

  return(app)
}

#' Create Netwalker Shiny App Object
#'
#' Creates a Shiny application object without running it
#'
#' @return A Shiny application object
#' @export
netwalker_app <- function() {
  shiny::shinyApp(
    ui = ui,
    server = server
  )
}

# ============================================================================
# Package Level Documentation
# ============================================================================

#' Netwalker Shiny Application
#'
#' A comprehensive Shiny application for network analysis and traceroute visualization.
#' The application provides interactive tools for:
#' \itemize{
#'   \item Performing traceroute operations
#'   \item Visualizing network routes geographically
#'   \item Analyzing latency patterns and statistics
#'   \item Exporting results in various formats
#' }
#'
#' @section Features:
#' \describe{
#'   \item{Interactive Maps}{Geographic visualization of network routes using Leaflet}
#'   \item{Real-time Charts}{Dynamic plots showing latency and routing data}
#'   \item{Data Export}{Export results as CSV or JSON files}
#'   \item{Responsive Design}{Works on desktop and mobile devices}
#'   \item{Multiple Themes}{Customizable appearance with various Bootstrap themes}
#' }
#'
#' @section Usage:
#' To run the application:
#' \preformatted{
#' library(netwalker)
#' run_netwalker_app()
#' }
#'
#' @section Dependencies:
#' The application requires the following R packages:
#' \itemize{
#'   \item shiny
#'   \item plotly
#'   \item leaflet
#'   \item DT
#'   \item dplyr
#'   \item ggplot2
#'   \item shinythemes
#'   \item shinyjs
#'   \item shinyWidgets
#' }
#'
#' @name netwalker-shiny
#' @aliases netwalker_app
#' @docType package
#' @author Netwalker Development Team
#' @keywords package
NULL
