#' Shiny Utilities for Netwalker Package
#'
#' This file contains utility functions for the Shiny application
#' including data validation, UI helpers, and common operations.
#'
#' @name shiny_utils
#' @import shiny
#' @importFrom dplyr filter mutate select
#' @importFrom stringr str_detect str_trim
NULL

#' Validate IP Address Input
#'
#' Checks if the provided string is a valid IP address
#'
#' @param ip_string Character string containing IP address
#' @return Logical indicating if IP is valid
#' @export
validate_ip <- function(ip_string) {
  if (is.null(ip_string) || ip_string == "") return(FALSE)

  # Basic IPv4 validation regex
  ip_pattern <- "^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.){3}(25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)$"
  grepl(ip_pattern, stringr::str_trim(ip_string))
}

#' Validate Hostname Input
#'
#' Checks if the provided string is a valid hostname
#'
#' @param hostname Character string containing hostname
#' @return Logical indicating if hostname is valid
#' @export
validate_hostname <- function(hostname) {
  if (is.null(hostname) || hostname == "") return(FALSE)

  # Basic hostname validation (simplified)
  hostname_pattern <- "^[a-zA-Z0-9]([a-zA-Z0-9\\-\\.]*[a-zA-Z0-9])?$"
  grepl(hostname_pattern, stringr::str_trim(hostname)) &&
    nchar(hostname) <= 253 &&
    !grepl("\\.\\.", hostname)
}

#' Create Loading Spinner
#'
#' Creates a standardized loading spinner for async operations
#'
#' @param message Character string for loading message
#' @return Shiny UI element
#' @export
create_loading_spinner <- function(message = "Loading...") {
  div(class = "loading-container",
      div(class = "spinner"),
      p(message)
  )
}

#' Format Traceroute Results for Display
#'
#' Formats traceroute data for display in Shiny tables
#'
#' @param trace_data Data frame with traceroute results
#' @return Formatted data frame
#' @export
format_trace_display <- function(trace_data) {
  if (is.null(trace_data) || nrow(trace_data) == 0) {
    return(data.frame(
      Hop = integer(),
      IP = character(),
      Hostname = character(),
      ASN = character(),
      Country = character(),
      RTT_ms = numeric()
    ))
  }

  trace_data %>%
    dplyr::mutate(
      Hop = as.integer(Hop),
      RTT_ms = round(as.numeric(RTT_ms), 2),
      IP = ifelse(is.na(IP), "*", IP),
      Hostname = ifelse(is.na(Hostname), "", Hostname),
      ASN = ifelse(is.na(ASN), "", ASN),
      Country = ifelse(is.na(Country), "", Country)
    ) %>%
    dplyr::select(Hop, IP, Hostname, ASN, Country, RTT_ms)
}

#' Create Error Alert
#'
#' Creates a standardized error alert for the UI
#'
#' @param message Character string containing error message
#' @return Shiny UI element
#' @export
create_error_alert <- function(message) {
  div(class = "alert alert-danger",
      role = "alert",
      icon("exclamation-triangle"),
      strong("Error: "),
      message
  )
}

#' Create Success Alert
#'
#' Creates a standardized success alert for the UI
#'
#' @param message Character string containing success message
#' @return Shiny UI element
#' @export
create_success_alert <- function(message) {
  div(class = "alert alert-success",
      role = "alert",
      icon("check-circle"),
      strong("Success: "),
      message
  )
}

#' Update Select Input Choices Safely
#'
#' Safely updates select input choices with validation
#'
#' @param session Shiny session object
#' @param input_id Character string of input ID
#' @param choices Vector of choices
#' @param selected Default selected value
#' @export
update_select_input_safe <- function(session, input_id, choices, selected = NULL) {
  tryCatch({
    if (is.null(choices) || length(choices) == 0) {
      choices <- ""
      selected <- ""
    }

    updateSelectInput(
      session = session,
      inputId = input_id,
      choices = choices,
      selected = selected %||% choices[1]
    )
  }, error = function(e) {
    warning("Failed to update select input: ", e$message)
  })
}

#' Debounce Function Calls
#'
#' Creates a debounced version of a function to limit execution frequency
#'
#' @param func Function to debounce
#' @param delay_ms Delay in milliseconds
#' @return Debounced function
#' @export
debounce <- function(func, delay_ms = 500) {
  timer <- NULL

  function(...) {
    args <- list(...)

    if (!is.null(timer)) {
      timer$callback <- NULL
    }

    timer <<- later::later(function() {
      do.call(func, args)
    }, delay = delay_ms / 1000)
  }
}

#' Get Available Themes
#'
#' Returns available theme options for the application
#'
#' @return Named vector of theme options
#' @export
get_available_themes <- function() {
  c(
    "Default" = "default",
    "Dark" = "darkly",
    "Light" = "flatly",
    "Cosmo" = "cosmo",
    "Cerulean" = "cerulean"
  )
}

#' Initialize Shiny Session
#'
#' Performs common initialization tasks for Shiny sessions
#'
#' @param session Shiny session object
#' @export
initialize_shiny_session <- function(session) {
  # Set session options
  session$userData$start_time <- Sys.time()
  session$userData$trace_history <- list()

  # Initialize reactive values if needed
  if (is.null(session$userData$reactive_vals)) {
    session$userData$reactive_vals <- reactiveValues(
      current_trace = NULL,
      last_error = NULL,
      is_loading = FALSE
    )
  }
}

#' Clean Up Session Data
#'
#' Cleans up temporary session data
#'
#' @param session Shiny session object
#' @export
cleanup_session_data <- function(session) {
  # Clear large objects from memory
  session$userData$trace_history <- NULL
  session$userData$reactive_vals <- NULL

  # Force garbage collection
  gc()
}
