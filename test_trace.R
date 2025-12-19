#!/usr/bin/env Rscript

# Тест исправленной трассировки
library(netwalker)

cat("=== ТЕСТИРОВАНИЕ trace_run() ===\n")

# Выполняем трассировку
trace_result <- trace_run(
  target = "google.com",
  max_hops = 5,  # Меньше для быстрого теста
  timeout = 2,
  queries = 3,
  method = "system"
)

cat("Сырой результат:\n")
print(str(trace_result))

cat("\nСодержимое raw:\n")
for (i in seq_along(trace_result$raw)) {
  cat(sprintf("[%d] %s\n", i, trace_result$raw[i]))
}

cat("\n=== ТЕСТИРОВАНИЕ trace_parse() ===\n")

# Пробуем разобрать
parsed_data <- tryCatch({
  trace_parse(trace_result)
}, error = function(e) {
  cat("ОШИБКА в trace_parse():", e$message, "\n")
  return(NULL)
})

if (!is.null(parsed_data)) {
  cat("Разобранные данные:\n")
  print(head(parsed_data, 10))

  cat("\n=== ТЕСТИРОВАНИЕ route_enrich() ===\n")

  # Пробуем обогатить
  enriched_data <- tryCatch({
    route_enrich(parsed_data)
  }, error = function(e) {
    cat("ОШИБКА в route_enrich():", e$message, "\n")
    return(NULL)
  })

  if (!is.null(enriched_data)) {
    cat("Обогащенные данные:\n")
    print(head(enriched_data, 5))

    cat("\n=== ТЕСТИРОВАНИЕ ВИЗУАЛИЗАЦИИ ===\n")

    # Тест графиков
    tryCatch({
      rtt_plot <- create_rtt_plot(enriched_data, "Тест RTT")
      cat("✓ График RTT создан\n")
    }, error = function(e) {
      cat("ОШИБКА в create_rtt_plot():", e$message, "\n")
    })

    tryCatch({
      geo_map <- create_geo_map(enriched_data, "Тест карты")
      cat("✓ Географическая карта создана\n")
    }, error = function(e) {
      cat("ОШИБКА в create_geo_map():", e$message, "\n")
    })
  }
}

cat("\n=== ГОТОВО ===\n")
