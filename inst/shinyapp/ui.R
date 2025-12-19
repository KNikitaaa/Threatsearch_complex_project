#' User Interface for Netwalker Shiny Application
#'
#' This file defines the user interface components and layout
#' for the Netwalker network analysis application.
#'
#' @name ui
NULL

#' Main UI Function
#'
#' Creates the main user interface for the application
#'
#' @return Shiny UI object
ui <- function() {
  fluidPage(
    # Initialize shinyjs
    useShinyjs(),

    # Theme and styling
    theme = shinytheme(DEFAULT_THEME),

    # Custom CSS
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
      tags$title(APP_TITLE)
    ),

    # Application header
    titlePanel(
      div(
        class = "app-header",
        h1(APP_TITLE, class = "app-title"),
        h4(APP_DESCRIPTION, class = "app-subtitle")
      )
    ),

    # Main application layout
    sidebarLayout(
      # Sidebar panel for inputs
      sidebarPanel(
        width = 3,
        div(class = "input-section",

            # Target input section
            h4(icon("crosshairs"), "Target Selection"),
            textInput("target_input", "IP Address or Hostname:",
                     placeholder = "e.g., google.com or 8.8.8.8",
                     value = ""),

            # Advanced options
            h4(icon("cogs"), "Advanced Options"),
            numericInput("max_hops", "Maximum Hops:",
                        value = DEFAULT_MAX_HOPS, min = 1, max = 100),

            numericInput("timeout", "Timeout (seconds):",
                        value = DEFAULT_TIMEOUT, min = 1, max = 300),

            # Action buttons
            h4(icon("play"), "Actions"),
            actionButton("trace_button", "Start Traceroute",
                        class = "btn-primary btn-block",
                        icon = icon("route")),

            actionButton("clear_button", "Clear Results",
                        class = "btn-secondary btn-block",
                        icon = icon("trash")),

            # Status and progress
            uiOutput("status_output")
        )
      ),

      # Main panel for results
      mainPanel(
        width = 9,

        # Tabset for different views
        tabsetPanel(
          id = "main_tabs",
          type = "tabs",

          # Overview tab
          tabPanel(
            title = "Overview",
            icon = icon("dashboard"),
            br(),

            # Statistics cards
            uiOutput("stats_cards"),

            br(),

            # Data table
            h4(icon("table"), "Traceroute Results"),
            DT::dataTableOutput("trace_table")
          ),

          # Visualization tab
          tabPanel(
            title = "Visualization",
            icon = icon("chart-line"),
            br(),

            fluidRow(
              column(6,
                     h4(icon("route"), "RTT Timeline"),
                     plotly::plotlyOutput("rtt_plot", height = "400px")
              ),
              column(6,
                     h4(icon("map"), "Network Map"),
                     leaflet::leafletOutput("geo_map", height = "400px")
              )
            ),

            br(),

            fluidRow(
              column(6,
                     h4(icon("network-wired"), "ASN Distribution"),
                     plotly::plotlyOutput("asn_chart", height = "400px")
              ),
              column(6,
                     h4(icon("globe"), "Geographic Distribution"),
                     plotly::plotlyOutput("country_pie", height = "400px")
              )
            )
          ),

          # Analysis tab
          tabPanel(
            title = "Analysis",
            icon = icon("search"),
            br(),

            fluidRow(
              column(12,
                     h4(icon("fire"), "Latency Heatmap"),
                     plotly::plotlyOutput("latency_heatmap", height = "500px")
              )
            ),

            br(),

            h4(icon("info-circle"), "Route Analysis"),
            uiOutput("route_analysis")
          ),

          # Settings tab
          tabPanel(
            title = "Settings",
            icon = icon("wrench"),
            br(),

            h4(icon("palette"), "Appearance"),
            selectInput("theme_select", "Application Theme:",
                       choices = get_available_themes(),
                       selected = DEFAULT_THEME),

            h4(icon("download"), "Export Options"),
            downloadButton("export_csv", "Export as CSV",
                          class = "btn-info"),
            downloadButton("export_json", "Export as JSON",
                          class = "btn-info"),

            br(),
            br(),

            h4(icon("history"), "Session Information"),
            uiOutput("session_info")
          )
        )
      )
    ),

    # Footer
    div(class = "app-footer",
        hr(),
        p(class = "text-center text-muted",
          paste("Netwalker v", APP_VERSION, " | ",
                format(Sys.Date(), "%Y"), " | ",
                "Built with Shiny"))
    )
  )
}

#' Status Output UI
#'
#' Creates the status display for traceroute operations
#'
#' @return Shiny UI element
status_output_ui <- function() {
  uiOutput("status_output")
}

#' Progress Modal
#'
#' Creates a modal dialog for showing operation progress
#'
#' @return Shiny modal dialog
progress_modal <- function() {
  modalDialog(
    title = "Running Traceroute...",
    div(
      class = "text-center",
      div(class = "spinner-border text-primary", role = "status",
          span(class = "sr-only", "Loading...")),
      br(),
      br(),
      p("Please wait while we trace the network route."),
      p("This may take several seconds depending on the target and network conditions.")
    ),
    footer = NULL,
    easyClose = FALSE,
    size = "s"
  )
}

#' Error Modal
#'
#' Creates a modal dialog for displaying errors
#'
#' @param message Error message to display
#' @return Shiny modal dialog
error_modal <- function(message) {
  modalDialog(
    title = "Error",
    div(
      class = "alert alert-danger",
      icon("exclamation-triangle"),
      strong("An error occurred:"),
      br(),
      message
    ),
    footer = modalButton("Close"),
    easyClose = TRUE
  )
}

#' Success Modal
#'
#' Creates a modal dialog for displaying success messages
#'
#' @param message Success message to display
#' @return Shiny modal dialog
success_modal <- function(message) {
  modalDialog(
    title = "Success",
    div(
      class = "alert alert-success",
      icon("check-circle"),
      message
    ),
    footer = modalButton("Close"),
    easyClose = TRUE
  )
}

#' Route Analysis UI
#'
#' Creates the route analysis display
#'
#' @param trace_data Traceroute data
#' @return Shiny UI element
route_analysis_ui <- function(trace_data) {
  if (is.null(trace_data) || nrow(trace_data) == 0) {
    return(div(class = "alert alert-info",
               icon("info-circle"),
               "No route data available for analysis."))
  }

  # Calculate route statistics
  total_distance <- sum(trace_data$RTT_ms, na.rm = TRUE)
  unique_countries <- length(unique(trace_data$Country[!is.na(trace_data$Country)]))
  unique_asns <- length(unique(trace_data$ASN[!is.na(trace_data$ASN)]))

  div(
    class = "route-analysis",
    h5("Route Summary"),
    p(sprintf("Total estimated latency: %.1f ms", total_distance)),
    p(sprintf("Countries traversed: %d", unique_countries)),
    p(sprintf("Autonomous Systems: %d", unique_asns)),

    br(),

    h5("Route Details"),
    tags$ul(
      lapply(seq_len(nrow(trace_data)), function(i) {
        row <- trace_data[i, ]
        tags$li(
          sprintf("Hop %d: %s (%s) - %s ms",
                  row$Hop,
                  ifelse(is.na(row$IP) || row$IP == "*", "Unknown", row$IP),
                  ifelse(is.na(row$Country), "Unknown", row$Country),
                  ifelse(is.na(row$RTT_ms), "N/A", sprintf("%.1f", row$RTT_ms)))
        )
      })
    )
  )
}

#' Session Info UI
#'
#' Creates the session information display
#'
#' @param session Shiny session object
#' @return Shiny UI element
session_info_ui <- function(session) {
  div(
    class = "session-info",
    p(strong("Session Start:"), format_timestamp(session$userData$start_time)),
    p(strong("Session Duration:"), calculate_session_duration(session$userData$start_time)),
    p(strong("Traces Performed:"), length(session$userData$trace_history)),
    p(strong("Last Target:"), ifelse(is.null(session$userData$last_target),
                                    "None", session$userData$last_target))
  )
}
