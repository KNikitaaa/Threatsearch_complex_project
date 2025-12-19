#' Visualization Functions for Netwalker Shiny App
#'
#' This file contains functions for creating plots and visualizations
#' for traceroute data analysis and network mapping.
#'
#' @name visualization
#' @import ggplot2
#' @import plotly
#' @import leaflet
#' @importFrom dplyr mutate filter group_by summarize arrange
#' @importFrom tidyr drop_na
#' @importFrom scales comma
NULL

#' Create RTT Timeline Plot
#'
#' Creates an interactive plot showing RTT (Round Trip Time) over hops
#'
#' @param trace_data Data frame with traceroute results
#' @param title Plot title
#' @return Plotly object
#' @export
create_rtt_plot <- function(trace_data, title = "RTT by Hop") {
  if (is.null(trace_data) || nrow(trace_data) == 0) {
    return(plotly::plot_ly() %>%
             layout(title = "No data available"))
  }

  # Prepare data
  plot_data <- trace_data %>%
    dplyr::filter(!is.na(RTT_ms) & RTT_ms > 0) %>%
    dplyr::mutate(Hop = as.numeric(Hop))

  if (nrow(plot_data) == 0) {
    return(plotly::plot_ly() %>%
             layout(title = "No RTT data available"))
  }

  # Create plot
  p <- plotly::plot_ly(plot_data,
                       x = ~Hop,
                       y = ~RTT_ms,
                       type = "scatter",
                       mode = "lines+markers",
                       line = list(color = "#1f77b4", width = 2),
                       marker = list(size = 8, color = "#1f77b4"),
                       hovertemplate = paste(
                         "Hop: %{x}<br>",
                         "RTT: %{y} ms<br>",
                         "IP: %{text}<br>",
                         "Host: %{customdata}",
                         "<extra></extra>"
                       ),
                       text = ~IP,
                       customdata = ~Hostname) %>%
    layout(
      title = list(text = title, font = list(size = 16)),
      xaxis = list(
        title = "Hop Number",
        tickmode = "linear",
        dtick = 1
      ),
      yaxis = list(
        title = "Round Trip Time (ms)",
        rangemode = "tozero"
      ),
      hovermode = "x unified"
    )

  return(p)
}

#' Create Geographic Map
#'
#' Creates an interactive map showing traceroute locations
#'
#' @param trace_data Data frame with traceroute results including lat/lon
#' @param title Map title
#' @return Leaflet map object
#' @export
create_geo_map <- function(trace_data, title = "Network Route Map") {
  if (is.null(trace_data) || nrow(trace_data) == 0) {
    # Return empty map
    return(leaflet::leaflet() %>%
             addTiles() %>%
             setView(lng = 0, lat = 0, zoom = 2))
  }

  # Filter data with valid coordinates
  map_data <- trace_data %>%
    dplyr::filter(!is.na(latitude) & !is.na(longitude)) %>%
    dplyr::mutate(
      popup_text = sprintf(
        "<strong>Hop %d</strong><br/>IP: %s<br/>Host: %s<br/>ASN: %s<br/>Country: %s",
        Hop, IP, ifelse(is.na(Hostname), "", Hostname),
        ifelse(is.na(ASN), "", ASN), ifelse(is.na(Country), "", Country)
      )
    )

  if (nrow(map_data) == 0) {
    return(leaflet::leaflet() %>%
             addTiles() %>%
             setView(lng = 0, lat = 0, zoom = 2) %>%
             addPopups(0, 0, "No geographic data available"))
  }

  # Create route lines if we have multiple points
  route_lines <- if (nrow(map_data) > 1) {
    map_data %>% dplyr::arrange(Hop)
  } else {
    NULL
  }

  # Create map
  map <- leaflet::leaflet(map_data) %>%
    addTiles() %>%
    addCircleMarkers(
      lng = ~longitude,
      lat = ~latitude,
      radius = 6,
      color = "#1f77b4",
      fillColor = "#1f77b4",
      fillOpacity = 0.8,
      weight = 2,
      popup = ~popup_text,
      label = ~sprintf("Hop %d: %s", Hop, IP)
    )

  # Add route lines if available
  if (!is.null(route_lines)) {
    map <- map %>%
      addPolylines(
        lng = ~longitude,
        lat = ~latitude,
        color = "#ff7f0e",
        weight = 3,
        opacity = 0.7,
        dashArray = "5, 10"
      )
  }

  # Fit bounds to show all points
  if (nrow(map_data) > 1) {
    map <- map %>% fitBounds(
      lng1 = min(map_data$longitude),
      lat1 = min(map_data$latitude),
      lng2 = max(map_data$longitude),
      lat2 = max(map_data$latitude)
    )
  }

  return(map)
}

#' Create ASN Distribution Chart
#'
#' Creates a bar chart showing distribution of Autonomous Systems
#'
#' @param trace_data Data frame with traceroute results
#' @param title Chart title
#' @return Plotly object
#' @export
create_asn_chart <- function(trace_data, title = "ASN Distribution") {
  if (is.null(trace_data) || nrow(trace_data) == 0) {
    return(plotly::plot_ly() %>%
             layout(title = "No data available"))
  }

  # Prepare ASN data
  asn_data <- trace_data %>%
    dplyr::filter(!is.na(ASN) & ASN != "") %>%
    dplyr::group_by(ASN) %>%
    dplyr::summarize(
      count = n(),
      avg_rtt = mean(RTT_ms, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::arrange(desc(count))

  if (nrow(asn_data) == 0) {
    return(plotly::plot_ly() %>%
             layout(title = "No ASN data available"))
  }

  # Create horizontal bar chart
  p <- plotly::plot_ly(asn_data,
                       x = ~count,
                       y = ~reorder(ASN, count),
                       type = "bar",
                       orientation = "h",
                       marker = list(color = "#2ca02c"),
                       hovertemplate = paste(
                         "ASN: %{y}<br>",
                         "Hops: %{x}<br>",
                         "Avg RTT: %{text} ms",
                         "<extra></extra>"
                       ),
                       text = ~round(avg_rtt, 1)) %>%
    layout(
      title = list(text = title, font = list(size = 16)),
      xaxis = list(title = "Number of Hops"),
      yaxis = list(title = "Autonomous System Number"),
      margin = list(l = 100)
    )

  return(p)
}

#' Create Country Distribution Pie Chart
#'
#' Creates a pie chart showing geographic distribution of hops
#'
#' @param trace_data Data frame with traceroute results
#' @param title Chart title
#' @return Plotly object
#' @export
create_country_pie <- function(trace_data, title = "Geographic Distribution") {
  if (is.null(trace_data) || nrow(trace_data) == 0) {
    return(plotly::plot_ly() %>%
             layout(title = "No data available"))
  }

  # Prepare country data
  country_data <- trace_data %>%
    dplyr::filter(!is.na(Country) & Country != "") %>%
    dplyr::group_by(Country) %>%
    dplyr::summarize(
      count = n(),
      .groups = "drop"
    ) %>%
    dplyr::arrange(desc(count)) %>%
    dplyr::mutate(
      percentage = count / sum(count) * 100,
      label = sprintf("%s (%d)", Country, count)
    )

  if (nrow(country_data) == 0) {
    return(plotly::plot_ly() %>%
             layout(title = "No country data available"))
  }

  # Create pie chart
  colors <- RColorBrewer::brewer.pal(min(nrow(country_data), 9), "Set3")
  if (nrow(country_data) > 9) {
    colors <- colorRampPalette(colors)(nrow(country_data))
  }

  p <- plotly::plot_ly(country_data,
                       labels = ~Country,
                       values = ~count,
                       type = "pie",
                       textinfo = "label+percent",
                       hoverinfo = "label+value+percent",
                       marker = list(colors = colors)) %>%
    layout(
      title = list(text = title, font = list(size = 16)),
      showlegend = TRUE,
      legend = list(orientation = "h", y = -0.1)
    )

  return(p)
}

#' Create Network Latency Heatmap
#'
#' Creates a heatmap showing latency patterns over time
#'
#' @param trace_data Data frame with traceroute results
#' @param title Chart title
#' @return Plotly object
#' @export
create_latency_heatmap <- function(trace_data, title = "Latency Heatmap") {
  if (is.null(trace_data) || nrow(trace_data) == 0) {
    return(plotly::plot_ly() %>%
             layout(title = "No data available"))
  }

  # Prepare data for heatmap
  heatmap_data <- trace_data %>%
    dplyr::filter(!is.na(RTT_ms) & !is.na(Hop)) %>%
    dplyr::mutate(
      Hop = as.numeric(Hop),
      RTT_category = cut(RTT_ms,
                        breaks = c(0, 10, 50, 100, 200, Inf),
                        labels = c("<10ms", "10-50ms", "50-100ms", "100-200ms", ">200ms"))
    )

  if (nrow(heatmap_data) == 0) {
    return(plotly::plot_ly() %>%
             layout(title = "No latency data available"))
  }

  # Create heatmap
  p <- plotly::plot_ly(heatmap_data,
                       x = ~Hop,
                       y = ~RTT_category,
                       z = ~RTT_ms,
                       type = "heatmap",
                       colorscale = "Viridis",
                       hovertemplate = paste(
                         "Hop: %{x}<br>",
                         "Latency: %{z} ms<br>",
                         "Category: %{y}",
                         "<extra></extra>"
                       )) %>%
    layout(
      title = list(text = title, font = list(size = 16)),
      xaxis = list(title = "Hop Number"),
      yaxis = list(title = "Latency Range")
    )

  return(p)
}

#' Create Summary Statistics Cards
#'
#' Creates HTML cards displaying key network statistics
#'
#' @param trace_data Data frame with traceroute results
#' @return Shiny UI elements with statistics cards
#' @export
create_stats_cards <- function(trace_data) {
  if (is.null(trace_data) || nrow(trace_data) == 0) {
    return(div(class = "stats-cards",
               p("No data available for statistics")))
  }

  # Calculate statistics
  total_hops <- nrow(trace_data)
  valid_ips <- sum(!is.na(trace_data$IP) & trace_data$IP != "*")
  avg_rtt <- mean(trace_data$RTT_ms, na.rm = TRUE)
  max_rtt <- max(trace_data$RTT_ms, na.rm = TRUE)
  unique_asn <- length(unique(trace_data$ASN[!is.na(trace_data$ASN) & trace_data$ASN != ""]))
  unique_countries <- length(unique(trace_data$Country[!is.na(trace_data$Country) & trace_data$Country != ""]))

  # Create cards
  fluidRow(
    column(2,
           div(class = "stat-card",
               div(class = "stat-value", total_hops),
               div(class = "stat-label", "Total Hops")
           )
    ),
    column(2,
           div(class = "stat-card",
               div(class = "stat-value", valid_ips),
               div(class = "stat-label", "Valid IPs")
           )
    ),
    column(2,
           div(class = "stat-card",
               div(class = "stat-value", ifelse(is.na(avg_rtt), "N/A", sprintf("%.1f", avg_rtt))),
               div(class = "stat-label", "Avg RTT (ms)")
           )
    ),
    column(2,
           div(class = "stat-card",
               div(class = "stat-value", ifelse(is.na(max_rtt), "N/A", sprintf("%.1f", max_rtt))),
               div(class = "stat-label", "Max RTT (ms)")
           )
    ),
    column(2,
           div(class = "stat-card",
               div(class = "stat-value", unique_asn),
               div(class = "stat-label", "Unique ASNs")
           )
    ),
    column(2,
           div(class = "stat-card",
               div(class = "stat-value", unique_countries),
               div(class = "stat-label", "Countries")
           )
    )
  )
}
