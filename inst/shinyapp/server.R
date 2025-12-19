#' Server Logic for Netwalker Shiny Application
#'
#' This file contains the server-side logic and reactive expressions
#' for the Netwalker network analysis application.
#'
#' @name server
NULL

#' Main Server Function
#'
#' Defines the server logic for the Shiny application
#'
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @return NULL
server <- function(input, output, session) {

  # ============================================================================
  # Reactive Values and Session Management
  # ============================================================================

  # Initialize session data
  initialize_shiny_session(session)

  # Reactive values for application state
  rv <- reactiveValues(
    current_trace = create_empty_trace_data(),
    trace_history = list(),
    is_loading = FALSE,
    last_error = NULL
  )

  # ============================================================================
  # Reactive Expressions
  # ============================================================================

  # Current trace data (reactive)
  current_trace_data <- reactive({
    rv$current_trace
  })

  # Validate target input
  target_valid <- reactive({
    target <- stringr::str_trim(input$target_input)
    if (target == "") return(list(valid = FALSE, message = "Please enter a target"))

    if (validate_ip(target) || validate_hostname(target)) {
      return(list(valid = TRUE, message = "Valid target"))
    } else {
      return(list(valid = FALSE, message = "Invalid IP address or hostname"))
    }
  })

  # ============================================================================
  # Event Handlers
  # ============================================================================

  # Handle traceroute button click
  observeEvent(input$trace_button, {
    target <- stringr::str_trim(input$target_input)

    # Validate input
    validation <- target_valid()
    if (!validation$valid) {
      rv$last_error <- validation$message
      showModal(error_modal(validation$message))
      return()
    }

    # Set loading state
    rv$is_loading <- TRUE
    session$userData$last_target <- target

    # Show progress modal
    showModal(progress_modal())

    # Perform traceroute in background
    tryCatch({
      # Get parameters
      max_hops <- input$max_hops
      timeout <- input$timeout

      # Run traceroute (this would call netwalker functions)
      # For now, create mock data - replace with actual traceroute call
      trace_result <- perform_mock_traceroute(target, max_hops)

      # Update reactive values
      rv$current_trace <- trace_result
      rv$trace_history <- c(rv$trace_history, list(trace_result))
      rv$is_loading <- FALSE
      rv$last_error <- NULL

      # Close progress modal and show success
      removeModal()
      showModal(success_modal("Traceroute completed successfully!"))

    }, error = function(e) {
      rv$is_loading <- FALSE
      rv$last_error <- e$message
      removeModal()
      showModal(error_modal(e$message))
    })
  })

  # Handle clear button click
  observeEvent(input$clear_button, {
    rv$current_trace <- create_empty_trace_data()
    rv$last_error <- NULL
    session$userData$last_target <- NULL

    # Clear input field
    updateTextInput(session, "target_input", value = "")

    # Show confirmation
    showNotification("Results cleared", type = "info")
  })

  # Handle theme change
  observeEvent(input$theme_select, {
    # Update theme (this would require page reload in real implementation)
    showNotification("Theme change requires page refresh", type = "warning")
  })

  # ============================================================================
  # Output Renderers
  # ============================================================================

  # Status output
  output$status_output <- renderUI({
    if (rv$is_loading) {
      div(class = "alert alert-info",
          icon("spinner", class = "fa-spin"),
          "Running traceroute...")
    } else if (!is.null(rv$last_error)) {
      div(class = "alert alert-danger",
          icon("exclamation-triangle"),
          rv$last_error)
    } else if (nrow(rv$current_trace) > 0) {
      div(class = "alert alert-success",
          icon("check-circle"),
          sprintf("Traceroute completed: %d hops found", nrow(rv$current_trace)))
    } else {
      div(class = "alert alert-info",
          icon("info-circle"),
          "Ready to start traceroute")
    }
  })

  # Statistics cards
  output$stats_cards <- renderUI({
    create_stats_cards(current_trace_data())
  })

  # Data table
  output$trace_table <- DT::renderDataTable({
    data <- current_trace_data()
    if (nrow(data) == 0) {
      return(DT::datatable(data.frame(Message = "No data available")))
    }

    # Format data for display
    display_data <- format_trace_display(data)

    DT::datatable(
      display_data,
      options = list(
        pageLength = 25,
        lengthMenu = c(10, 25, 50, 100),
        scrollX = TRUE,
        searching = TRUE,
        ordering = TRUE,
        columnDefs = list(
          list(width = '80px', targets = 0),  # Hop column
          list(width = '120px', targets = 1), # IP column
          list(width = '150px', targets = 2), # Hostname column
          list(width = '100px', targets = 3), # ASN column
          list(width = '100px', targets = 4), # Country column
          list(width = '80px', targets = 5)   # RTT column
        )
      ),
      rownames = FALSE,
      class = 'cell-border stripe'
    ) %>%
      DT::formatStyle(
        'RTT_ms',
        backgroundColor = DT::styleInterval(
          c(10, 50, 100, 200),
          c('#e6f7ff', '#bae7ff', '#91d5ff', '#69c0ff', '#ffccc7')
        )
      )
  })

  # RTT plot
  output$rtt_plot <- plotly::renderPlotly({
    create_rtt_plot(current_trace_data())
  })

  # Geographic map
  output$geo_map <- leaflet::renderLeaflet({
    create_geo_map(current_trace_data())
  })

  # ASN chart
  output$asn_chart <- plotly::renderPlotly({
    create_asn_chart(current_trace_data())
  })

  # Country pie chart
  output$country_pie <- plotly::renderPlotly({
    create_country_pie(current_trace_data())
  })

  # Latency heatmap
  output$latency_heatmap <- plotly::renderPlotly({
    create_latency_heatmap(current_trace_data())
  })

  # Route analysis
  output$route_analysis <- renderUI({
    route_analysis_ui(current_trace_data())
  })

  # Session info
  output$session_info <- renderUI({
    session_info_ui(session)
  })

  # ============================================================================
  # Download Handlers
  # ============================================================================

  # CSV export
  output$export_csv <- downloadHandler(
    filename = function() {
      paste0("traceroute_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
    },
    content = function(file) {
      write.csv(current_trace_data(), file, row.names = FALSE)
    }
  )

  # JSON export
  output$export_json <- downloadHandler(
    filename = function() {
      paste0("traceroute_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".json")
    },
    content = function(file) {
      jsonlite::write_json(current_trace_data(), file, pretty = TRUE)
    }
  )

  # ============================================================================
  # Session Cleanup
  # ============================================================================

  # Clean up on session end
  session$onSessionEnded(function() {
    cleanup_session_data(session)
  })
}

# ============================================================================
# Helper Functions
# ============================================================================

#' Perform Mock Traceroute
#'
#' Creates mock traceroute data for demonstration purposes
#' In a real implementation, this would call netwalker::traceroute()
#'
#' @param target Target IP or hostname
#' @param max_hops Maximum number of hops
#' @return Data frame with traceroute results
perform_mock_traceroute <- function(target, max_hops = 30) {
  # Simulate network delay
  Sys.sleep(2)

  # Create mock data
  hops <- sample(8:25, 1)  # Random number of hops

  # Mock IP addresses and hostnames
  mock_ips <- c(
    "192.168.1.1", "10.0.0.1", "172.16.0.1",
    "203.0.113.1", "198.51.100.1", "192.0.2.1",
    "8.8.8.8", "1.1.1.1", "208.67.222.222"
  )

  mock_hosts <- c(
    "router.local", "gateway.isp.net", "core.router.net",
    "border.router.com", "dns.google", "one.one.one.one",
    "resolver2.opendns.com", target
  )

  # Generate trace data
  trace_data <- data.frame(
    Hop = 1:hops,
    IP = sample(mock_ips, hops, replace = TRUE),
    Hostname = sample(mock_hosts, hops, replace = TRUE),
    ASN = sample(1000:50000, hops, replace = TRUE),
    Country = sample(c("US", "DE", "GB", "FR", "JP", "AU", "CA"), hops, replace = TRUE),
    RTT_ms = runif(hops, 1, 150),
    stringsAsFactors = FALSE
  )

  # Add some geographic coordinates (mock)
  country_coords <- list(
    "US" = c(-98.5795, 39.8283),
    "DE" = c(10.4515, 51.1657),
    "GB" = c(-3.4359, 55.3781),
    "FR" = c(2.2137, 46.2276),
    "JP" = c(138.2529, 36.2048),
    "AU" = c(133.7751, -25.2744),
    "CA" = c(-106.3468, 56.1304)
  )

  trace_data$latitude <- sapply(trace_data$Country, function(country) {
    coords <- country_coords[[country]]
    if (!is.null(coords)) coords[2] + rnorm(1, 0, 5) else NA
  })

  trace_data$longitude <- sapply(trace_data$Country, function(country) {
    coords <- country_coords[[country]]
    if (!is.null(coords)) coords[1] + rnorm(1, 0, 5) else NA
  })

  # Set final hop to target
  if (hops > 0) {
    trace_data$IP[hops] <- target
    trace_data$Hostname[hops] <- target
  }

  return(trace_data)
}
