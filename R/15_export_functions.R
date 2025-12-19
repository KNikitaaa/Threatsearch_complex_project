#' Экспорт данных о маршрутизации в различные форматы
#'
#' @param data Данные для экспорта (data.frame или список)
#' @param format Формат экспорта: "csv", "json", "rds", "xlsx", "html"
#' @param file_path Путь к файлу для сохранения
#' @param include_metadata Включить метаданные?
#'
#' @return Путь к сохраненному файлу
#' @export
#'
#' @examples
#' \dontrun{
#' # Экспорт в CSV
#' export_route_data(trace_data, "csv", "trace_results.csv")
#'
#' # Экспорт в JSON
#' export_route_data(trace_data, "json", "trace_results.json")
#' }
export_route_data <- function(
    data,
    format = "csv",
    file_path = NULL,
    include_metadata = TRUE
) {
  
  # Проверка данных
  if (is.null(data)) {
    stop("Данные для экспорта не предоставлены")
  }
  
  # Если путь не указан, генерируем автоматически
  if (is.null(file_path)) {
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    file_path <- paste0("netwalker_export_", timestamp, ".", format)
  }
  
  # Добавляем метаданные если нужно
  if (include_metadata) {
    metadata <- list(
      export_date = Sys.time(),
      netwalker_version = utils::packageVersion("netwalker"),
      data_type = class(data),
      rows = if (is.data.frame(data)) nrow(data) else length(data),
      columns = if (is.data.frame(data)) ncol(data) else NA
    )
    
    # Для data.frame добавляем метаданные как атрибут
    if (is.data.frame(data)) {
      attr(data, "metadata") <- metadata
    } else if (is.list(data)) {
      data$metadata <- metadata
    }
  }
  
  # Экспорт в зависимости от формата
  message("Экспорт данных в формат: ", toupper(format))
  message("Путь сохранения: ", normalizePath(file_path, mustWork = FALSE))
  
  switch(format,
         "csv" = {
           if (!requireNamespace("data.table", quietly = TRUE)) {
             utils::write.csv(data, file_path, row.names = FALSE)
           } else {
             data.table::fwrite(data, file_path)
           }
         },
         
         "json" = {
           if (!requireNamespace("jsonlite", quietly = TRUE)) {
             stop("Для экспорта в JSON требуется пакет 'jsonlite'")
           }
           jsonlite::write_json(data, file_path, pretty = TRUE, auto_unbox = TRUE)
         },
         
         "rds" = {
           saveRDS(data, file_path)
         },
         
         "xlsx" = {
           if (!requireNamespace("openxlsx", quietly = TRUE)) {
             stop("Для экспорта в Excel требуется пакет 'openxlsx'")
           }
           openxlsx::write.xlsx(data, file_path)
         },
         
         "html" = {
           if (!requireNamespace("DT", quietly = TRUE)) {
             stop("Для экспорта в HTML требуется пакет 'DT'")
           }
           
           # Создаем интерактивную таблицу
           dt <- DT::datatable(
             data,
             extensions = c('Buttons', 'Scroller'),
             options = list(
               dom = 'Bfrtip',
               buttons = c('copy', 'csv', 'excel', 'pdf', 'print'),
               scrollX = TRUE,
               pageLength = 20
             ),
             rownames = FALSE
           )
           
           htmlwidgets::saveWidget(dt, file_path)
         },
         
         stop("Неподдерживаемый формат: ", format, 
              ". Доступные форматы: csv, json, rds, xlsx, html")
  )
  
  message("✓ Данные успешно экспортированы: ", normalizePath(file_path))
  return(normalizePath(file_path))
}

#' Генерация отчета о маршрутизации
#'
#' @param trace_results Результаты traceroute
#' @param output_format Формат отчета: "html", "pdf", "word"
#' @param output_file Путь к файлу отчета
#' @param template_path Путь к шаблону RMarkdown (опционально)
#'
#' @return Путь к созданному отчету
#' @export
generate_route_report <- function(
    trace_results,
    output_format = "html",
    output_file = NULL,
    template_path = NULL
) {
  
  # Проверяем наличие rmarkdown
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop("Для генерации отчетов требуется пакет 'rmarkdown'")
  }
  
  # Генерируем имя файла если не указано
  if (is.null(output_file)) {
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    output_file <- paste0("netwalker_report_", timestamp, ".", output_format)
  }
  
  # Если не указан шаблон, используем встроенный
  if (is.null(template_path)) {
    template_path <- system.file("report_template.Rmd", package = "netwalker")
    
    # Если встроенного шаблона нет, создаем временный
    if (template_path == "") {
      template_path <- tempfile(fileext = ".Rmd")
      create_report_template(template_path)
    }
  }
  
  message("Генерация отчета о маршрутизации...")
  message("Формат: ", output_format)
  message("Выходной файл: ", output_file)
  
  # Подготавливаем параметры для отчета
  report_params <- list(
    trace_data = trace_results,
    generation_date = Sys.time(),
    target = attr(trace_results, "target") %||% "Неизвестно",
    hops_count = if (is.data.frame(trace_results)) nrow(trace_results) else length(trace_results)
  )
  
  # Рендерим отчет
  rmarkdown::render(
    input = template_path,
    output_format = paste0(output_format, "_document"),
    output_file = output_file,
    params = report_params,
    envir = new.env(),
    quiet = FALSE
  )
  
  message("✓ Отчет успешно создан: ", normalizePath(output_file))
  return(normalizePath(output_file))
}

#' Создание шаблона отчета RMarkdown
#'
#' @param template_path Путь для сохранения шаблона
#'
#' @return Путь к созданному шаблону
#' @export
create_report_template <- function(template_path) {
  
  template_content <- c(
    "---",
    "title: 'Отчет NetWalker: Анализ маршрутизации'",
    "author: 'NetWalker Package'",
    "date: '`r Sys.Date()`'",
    "output:",
    "  html_document:",
    "    toc: true",
    "    toc_float: true",
    "    code_folding: show",
    "params:",
    "  trace_data: NULL",
    "  generation_date: NULL",
    "  target: 'Неизвестно'",
    "  hops_count: 0",
    "---",
    "",
    "```{r setup, include=FALSE}",
    "knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE)",
    "library(dplyr)",
    "library(knitr)",
    "```",
    "",
    "# Анализ маршрутизации",
    "",
    "## Общая информация",
    "",
    "```{r info}",
    "cat('Целевой хост:', params$target, '\\n')",
    "cat('Дата анализа:', format(params$generation_date, '%Y-%m-%d %H:%M:%S'), '\\n')",
    "cat('Количество прыжков:', params$hops_count, '\\n')",
    "```",
    "",
    "## Результаты traceroute",
    "",
    "```{r results-table}",
    "if (!is.null(params$trace_data) && nrow(params$trace_data) > 0) {",
    "  knitr::kable(params$trace_data, format = 'html') %>%",
    "    kableExtra::kable_styling(bootstrap_options = c('striped', 'hover'))",
    "} else {",
    "  cat('Данные traceroute не доступны')",
    "}",
    "```",
    "",
    "## Статистика по странам",
    "",
    "```{r stats}",
    "if (!is.null(params$trace_data) && 'country' %in% names(params$trace_data)) {",
    "  country_stats <- params$trace_data %>%",
    "    filter(!is.na(country)) %>%",
    "    count(country, name = 'hops') %>%",
    "    arrange(desc(hops))",
    "  ",
    "  knitr::kable(country_stats)",
    "}",
    "```",
    "",
    "## Визуализация маршрута",
    "",
    "```{r map, fig.width=10, fig.height=6}",
    "if (!is.null(params$trace_data) && all(c('latitude', 'longitude') %in% names(params$trace_data))) {",
    "  library(leaflet)",
    "  ",
    "  # Фильтруем точки с координатами",
    "  route_points <- params$trace_data %>%",
    "    filter(!is.na(latitude), !is.na(longitude))",
    "  ",
    "  if (nrow(route_points) > 1) {",
    "    m <- leaflet(route_points) %>%",
    "      addTiles() %>%",
    "      addCircleMarkers(~longitude, ~latitude, popup = ~as.character(hop)) %>%",
    "      addPolylines(~longitude, ~latitude)",
    "    print(m)",
    "  }",
    "}",
    "```",
    "",
    "---",
    "*Сгенерировано автоматически с помощью NetWalker*"
  )
  
  writeLines(template_content, template_path)
  message("Шаблон отчета создан: ", normalizePath(template_path))
  
  return(normalizePath(template_path))
}

#' Экспорт графа автономных систем
#'
#' @param graph_data Данные графа (список с nodes и edges)
#' @param output_format Формат: "graphml", "gexf", "pajek", "html"
#' @param output_file Путь к выходному файлу
#'
#' @return Путь к экспортированному файлу
#' @export
export_asn_graph <- function(
    graph_data,
    output_format = "html",
    output_file = NULL
) {
  
  if (!requireNamespace("visNetwork", quietly = TRUE)) {
    stop("Для экспорта графа требуется пакет 'visNetwork'")
  }
  
  if (is.null(output_file)) {
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    output_file <- paste0("asn_graph_", timestamp, ".", output_format)
  }
  
  message("Экспорт графа автономных систем...")
  message("Формат: ", output_format)
  
  switch(output_format,
         "html" = {
           # Создаем интерактивный граф
           graph <- visNetwork::visNetwork(
             nodes = graph_data$nodes,
             edges = graph_data$edges
           ) %>%
             visNetwork::visOptions(
               highlightNearest = list(enabled = TRUE, degree = 1),
               nodesIdSelection = TRUE
             ) %>%
             visNetwork::visLayout(randomSeed = 123)
           
           htmlwidgets::saveWidget(graph, output_file)
         },
         
         "graphml" = {
           if (!requireNamespace("igraph", quietly = TRUE)) {
             stop("Для экспорта в GraphML требуется пакет 'igraph'")
           }
           
           # Создаем igraph объект
           g <- igraph::graph_from_data_frame(
             d = graph_data$edges,
             vertices = graph_data$nodes,
             directed = FALSE
           )
           
           igraph::write_graph(g, output_file, format = "graphml")
         },
         
         "gexf" = {
           if (!requireNamespace("rgexf", quietly = TRUE)) {
             stop("Для экспорта в GEXF требуется пакет 'rgexf'")
           }
           
           # Экспорт в GEXF
           gexf_data <- rgexf::write.gexf(
             nodes = graph_data$nodes,
             edges = graph_data$edges
           )
           
           writeLines(gexf_data$graph, output_file)
         },
         
         stop("Неподдерживаемый формат графа: ", output_format)
  )
  
  message("✓ Граф успешно экспортирован: ", normalizePath(output_file))
  return(normalizePath(output_file))
}