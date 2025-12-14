#' Global Configuration for Netwalker Shiny Application
#'
#' This file contains global settings, library imports, and initialization
#' code for the Netwalker Shiny application.
#'
#' @name global
NULL

# ============================================================================
# Library Imports
# ============================================================================

# Shiny and UI libraries
library(shiny)
library(shinydashboard)
library(shinythemes)
library(shinyjs)
library(shinyWidgets)

# Data manipulation and visualization
library(dplyr)
library(ggplot2)
library(plotly)
library(leaflet)
library(DT)

# Netwalker package functions
library(netwalker)

# Additional utility libraries
library(stringr)
library(lubridate)
library(RColorBrewer)

# ============================================================================
# Global Constants and Configuration
# ============================================================================

# Application metadata
APP_TITLE <- "Netwalker - Network Analysis Tool"
APP_VERSION <- "1.0.0"
APP_DESCRIPTION <- "Interactive traceroute visualization and network analysis"

# Default UI settings
DEFAULT_THEME <- "flatly"
MAX_HOPS_DISPLAY <- 50
DEFAULT_TIMEOUT <- 30
DEFAULT_MAX_HOPS <- 30

# Color scheme
COLORS <- list(
  primary = "#1f77b4",
  secondary = "#ff7f0e",
  success = "#2ca02c",
  danger = "#d62728",
  warning = "#ff9900",
  info = "#17becf"
)

# ============================================================================
# Global Variables
# ============================================================================

# Reactive values template for session management
SESSION_TEMPLATE <- list(
  current_trace = NULL,
  trace_history = list(),
  last_target = NULL,
  last_error = NULL,
  is_loading = FALSE,
  start_time = NULL
)

# ============================================================================
# Utility Functions
# ============================================================================

#' Initialize Application Environment
#'
#' Sets up the application environment and checks dependencies
#'
#' @return Logical indicating successful initialization
initialize_app <- function() {
  tryCatch({
    # Check for required data files
    check_data_availability()

    # Initialize logging if needed
    if (getOption("netwalker.verbose", FALSE)) {
      message("Netwalker Shiny app initialized successfully")
    }

    return(TRUE)
  }, error = function(e) {
    warning("Failed to initialize application: ", e$message)
    return(FALSE)
  })
}

#' Check Data Availability
#'
#' Verifies that required data files are available
#'
#' @return Logical indicating data availability
check_data_availability <- function() {
  # Check for DBIP data
  dbip_available <- tryCatch({
    netwalker::check_dbip_data()
  }, error = function(e) FALSE)

  if (!dbip_available) {
    warning("DBIP data not available. Some features may be limited.")
  }

  return(dbip_available)
}

#' Get Application Info
#'
#' Returns application metadata
#'
#' @return List with application information
get_app_info <- function() {
  list(
    title = APP_TITLE,
    version = APP_VERSION,
    description = APP_DESCRIPTION,
    theme = DEFAULT_THEME,
    max_hops = DEFAULT_MAX_HOPS,
    timeout = DEFAULT_TIMEOUT
  )
}

#' Create Default Empty Trace Data
#'
#' Creates an empty data frame for traceroute results
#'
#' @return Empty data frame with proper column structure
create_empty_trace_data <- function() {
  data.frame(
    Hop = integer(),
    IP = character(),
    Hostname = character(),
    ASN = character(),
    Country = character(),
    RTT_ms = numeric(),
    latitude = numeric(),
    longitude = numeric(),
    stringsAsFactors = FALSE
  )
}

#' Validate Trace Data Structure
#'
#' Validates that trace data has the correct structure
#'
#' @param data Data frame to validate
#' @return Logical indicating validity
validate_trace_data <- function(data) {
  if (!is.data.frame(data)) return(FALSE)

  required_cols <- c("Hop", "IP", "Hostname", "ASN", "Country", "RTT_ms")
  missing_cols <- setdiff(required_cols, colnames(data))

  if (length(missing_cols) > 0) {
    warning("Missing required columns: ", paste(missing_cols, collapse = ", "))
    return(FALSE)
  }

  return(TRUE)
}

#' Format Timestamp for Display
#'
#' Formats timestamp for user display
#'
#' @param timestamp POSIXct timestamp
#' @return Formatted character string
format_timestamp <- function(timestamp) {
  if (is.null(timestamp)) return("N/A")

  format(timestamp, "%Y-%m-%d %H:%M:%S")
}

#' Calculate Session Duration
#'
#' Calculates how long the current session has been active
#'
#' @param start_time Session start time
#' @return Character string with duration
calculate_session_duration <- function(start_time) {
  if (is.null(start_time)) return("N/A")

  duration <- difftime(Sys.time(), start_time, units = "secs")
  seconds <- as.numeric(duration)

  if (seconds < 60) {
    sprintf("%.1f seconds", seconds)
  } else if (seconds < 3600) {
    sprintf("%.1f minutes", seconds / 60)
  } else {
    sprintf("%.1f hours", seconds / 3600)
  }
}

# ============================================================================
# Application Initialization
# ============================================================================

# Initialize the application
app_initialized <- initialize_app()

# Set Shiny options
options(shiny.maxRequestSize = 100*1024^2)  # 100MB max upload size
options(shiny.sanitize.errors = TRUE)
options(shiny.deprecation.messages = FALSE)

# Set plotly defaults
plotly::config(plotly::plot_ly(), displayModeBar = TRUE, displaylogo = FALSE)

# ============================================================================
# Export Global Objects
# ============================================================================

# Make key objects available to the application
assign("APP_CONFIG", get_app_info(), envir = .GlobalEnv)
assign("COLOR_PALETTE", COLORS, envir = .GlobalEnv)
