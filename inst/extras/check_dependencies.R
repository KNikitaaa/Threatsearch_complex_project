#!/usr/bin/env Rscript
#
# Скрипт проверки зависимостей для NetWalker
#

# ====================================================
# КОНФИГУРАЦИЯ ЗАВИСИМОСТЕЙ
# ====================================================

DEPENDENCIES <- list(
  
  # Основные пакеты для работы пакета
  core = c(
    "dplyr",      # Манипуляция данными
    "tidyr",      # Преобразование данных
    "purrr",      # Функциональное программирование
    "stringr",    # Работа со строками
    "httr",       # HTTP запросы
    "jsonlite",   # Работа с JSON
    "data.table"  # Быстрая обработка данных
  ),
  
  # Пакеты для визуализации
  visualization = c(
    "shiny",          # Веб-фреймворк
    "shinydashboard", # Dashboard для Shiny
    "shinyWidgets",   # Виджеты для Shiny
    "leaflet",        # Интерактивные карты
    "visNetwork",     # Визуализация графов
    "DT",             # Интерактивные таблицы
    "ggplot2",        # Графики
    "plotly"         # Интерактивные графики
  ),
  
  # Пакеты для сетевого анализа
  network = c(
    "processx",       # Запуск внешних процессов
    "logger",         # Логирование
    "config",         # Конфигурация
    "yaml",           # Чтение YAML файлов
    "DBI",            # Интерфейс к базам данных
    "duckdb"         # Встроенная БД
  ),
  
  # Пакеты для отчетов и документации
  reporting = c(
    "rmarkdown",      # Создание отчетов
    "knitr",          # Включение кода в отчеты
    "pkgdown",        # Документация пакета
    "roxygen2"        # Документирование функций
  ),
  
  # Системные зависимости (для проверки)
  system = c(
    "traceroute",     # Для трассировки маршрута
    "curl",           # Для HTTP запросов из командной строки
    "whois"          # Для получения информации о доменах
  )
)

# ====================================================
# ФУНКЦИИ ПРОВЕРКИ
# ====================================================

#' Проверка установки R пакетов
check_r_packages <- function() {
  cat("\n")
  cat("=" * 60, "\n")
  cat("ПРОВЕРКА R ПАКЕТОВ\n")
  cat("=" * 60, "\n\n")
  
  all_packages <- unlist(DEPENDENCIES[1:4])  # Только R пакеты
  installed <- installed.packages()[, "Package"]
  
  results <- data.frame(
    Пакет = all_packages,
    Статус = ifelse(all_packages %in% installed, "✓ Установлен", "✗ Отсутствует"),
    Версия = sapply(all_packages, function(pkg) {
      if (pkg %in% installed) {
        as.character(packageVersion(pkg))
      } else {
        "—"
      }
    }),
    stringsAsFactors = FALSE
  )
  
  # Группируем по категориям
  for (category in names(DEPENDENCIES)[1:4]) {
    cat("\n", toupper(category), ":\n", sep = "")
    cat(rep("-", nchar(category) + 1), "\n", sep = "")
    
    category_packages <- DEPENDENCIES[[category]]
    category_results <- results[results$Пакет %in% category_packages, ]
    
    # Выводим таблицу
    for (i in seq_len(nrow(category_results))) {
      row <- category_results[i, ]
      cat(sprintf("  %-15s %-20s %s\n", 
                  row$Пакет, row$Статус, row$Версия))
    }
  }
  
  # Сводка
  missing <- results[!results$Пакет %in% installed, ]
  
  cat("\n", "=" * 60, "\n", sep = "")
  cat("СВОДКА:\n")
  cat(sprintf("Всего пакетов: %d\n", length(all_packages)))
  cat(sprintf("Установлено: %d\n", sum(all_packages %in% installed)))
  cat(sprintf("Отсутствует: %d\n", nrow(missing)))
  
  if (nrow(missing) > 0) {
    cat("\nОтсутствующие пакеты:\n")
    cat(paste("  -", missing$Пакет), sep = "\n")
    
    # Предлагаем установить
    cat("\nУстановить все недостающие пакеты? (y/n): ")
    answer <- readLines("stdin", n = 1)
    
    if (tolower(answer) == "y") {
      install_missing_packages(missing$Пакет)
    }
  }
  
  cat("\n", "=" * 60, "\n", sep = "")
  
  return(invisible(results))
}

#' Установка отсутствующих пакетов
install_missing_packages <- function(packages) {
  cat("\nНачинаю установку пакетов...\n")
  
  for (pkg in packages) {
    cat(sprintf("Установка %s... ", pkg))
    
    tryCatch({
      install.packages(pkg, repos = "https://cloud.r-project.org/", quiet = TRUE)
      cat("✓\n")
    }, error = function(e) {
      cat(sprintf("✗ (Ошибка: %s)\n", e$message))
    })
  }
  
  cat("\nУстановка завершена!\n")
}

#' Проверка системных зависимостей
check_system_dependencies <- function() {
  cat("\n")
  cat("=" * 60, "\n")
  cat("ПРОВЕРКА СИСТЕМНЫХ ЗАВИСИМОСТЕЙ\n")
  cat("=" * 60, "\n\n")
  
  system_tools <- DEPENDENCIES$system
  
  results <- data.frame(
    Инструмент = character(),
    Статус = character(),
    Версия = character(),
    stringsAsFactors = FALSE
  )
  
  for (tool in system_tools) {
    # Пытаемся получить версию инструмента
    status <- tryCatch({
      if (tool == "traceroute") {
        # Проверка traceroute
        output <- system2("traceroute", "--version", stdout = TRUE, stderr = TRUE)
        if (length(output) == 0) {
          output <- system2("traceroute", "-V", stdout = TRUE, stderr = TRUE)
        }
        list(installed = TRUE, version = paste(output[1:2], collapse = " "))
      } else if (tool == "curl") {
        output <- system2("curl", "--version", stdout = TRUE, stderr = TRUE)
        list(installed = TRUE, version = output[1])
      } else if (tool == "whois") {
        output <- system2("whois", "--version", stdout = TRUE, stderr = TRUE)
        list(installed = TRUE, version = output[1])
      } else {
        list(installed = FALSE, version = NA)
      }
    }, error = function(e) {
      list(installed = FALSE, version = NA)
    })
    
    results <- rbind(results, data.frame(
      Инструмент = tool,
      Статус = ifelse(status$installed, "✓ Установлен", "✗ Отсутствует"),
      Версия = ifelse(is.na(status$version), "—", status$version),
      stringsAsFactors = FALSE
    ))
  }
  
  # Выводим таблицу
  for (i in seq_len(nrow(results))) {
    row <- results[i, ]
    cat(sprintf("  %-12s %-20s %s\n", 
                row$Инструмент, row$Статус, row$Версия))
  }
  
  # Проверка Docker
  cat("\nDocker:\n")
  docker_check <- tryCatch({
    output <- system2("docker", "--version", stdout = TRUE)
    cat(sprintf("  %-12s %-20s %s\n", "docker", "✓ Установлен", output[1]))
    TRUE
  }, error = function(e) {
    cat(sprintf("  %-12s %-20s %s\n", "docker", "✗ Отсутствует", "—"))
    FALSE
  })
  
  cat("\n", "=" * 60, "\n", sep = "")
  
  return(invisible(results))
}

#' Проверка версии R
check_r_version <- function() {
  cat("\n")
  cat("=" * 60, "\n")
  cat("ИНФОРМАЦИЯ О СИСТЕМЕ\n")
  cat("=" * 60, "\n\n")
  
  # Информация о R
  cat("R:\n")
  cat(sprintf("  Версия:      %s\n", R.version.string))
  cat(sprintf("  Платформа:   %s\n", R.version$platform))
  cat(sprintf("  Язык:        %s\n", Sys.getlocale("LC_CTYPE")))
  
  # Информация о системе
  cat("\nСистема:\n")
  sys_info <- Sys.info()
  cat(sprintf("  ОС:          %s\n", sys_info["sysname"]))
  cat(sprintf("  Релиз:       %s\n", sys_info["release"]))
  cat(sprintf("  Версия:      %s\n", sys_info["version"]))
  cat(sprintf("  Пользователь: %s\n", sys_info["user"]))
  
  # Информация о директориях
  cat("\nДиректории:\n")
  cat(sprintf("  Рабочая:     %s\n", getwd()))
  cat(sprintf("  Библиотеки R: %s\n", .libPaths()[1]))
  
  cat("\n", "=" * 60, "\n", sep = "")
}

#' Проверка работоспособности пакета NetWalker
check_netwalker_functionality <- function() {
  cat("\n")
  cat("=" * 60, "\n")
  cat("ПРОВЕРКА NETWALKER\n")
  cat("=" * 60, "\n\n")
  
  # Проверяем, установлен ли пакет
  if (!requireNamespace("netwalker", quietly = TRUE)) {
    cat("✗ Пакет NetWalker не установлен\n")
    return(FALSE)
  }
  
  cat(sprintf("Версия NetWalker: %s\n", utils::packageVersion("netwalker")))
  
  # Проверяем основные функции
  functions_to_check <- c(
    "run_netwalker_app",
    "check_docker_environment",
    "export_route_data"
  )
  
  cat("\nПроверка функций:\n")
  for (func in functions_to_check) {
    exists <- exists(func, where = asNamespace("netwalker"), mode = "function")
    cat(sprintf("  %-25s %s\n", func, ifelse(exists, "✓", "✗")))
  }
  
  # Проверяем наличие Shiny приложения
  shiny_app_path <- system.file("shinyapp", package = "netwalker")
  if (shiny_app_path != "") {
    cat(sprintf("\nShiny приложение: ✓ (найдено в %s)\n", shiny_app_path))
    
    # Проверяем файлы приложения
    app_files <- list.files(shiny_app_path, pattern = "\\.(R|css|js)$")
    cat(sprintf("  Файлов приложения: %d\n", length(app_files)))
  } else {
    cat("\nShiny приложение: ✗ (не найдено)\n")
  }
  
  # Проверяем данные
  data_files <- list.files(system.file("data", package = "netwalker"), 
                           pattern = "\\.(rda|rds)$")
  if (length(data_files) > 0) {
    cat(sprintf("\nДанные: ✓ (файлов: %d)\n", length(data_files)))
  } else {
    cat("\nДанные: ✗ (нет данных)\n")
  }
  
  cat("\n", "=" * 60, "\n", sep = "")
  
  return(TRUE)
}

#' Генерация отчета о зависимостях
generate_dependency_report <- function(output_file = "netwalker_dependencies.md") {
  cat("\nГенерация отчета о зависимостях...\n")
  
  report <- c(
    "# Отчет о зависимостях NetWalker",
    paste("Дата проверки:", Sys.time()),
    paste("Версия R:", R.version.string),
    "",
    "## R пакеты",
    "",
    "| Категория | Пакет | Статус | Версия |",
    "|-----------|-------|--------|--------|"
  )
  
  # Добавляем информацию о R пакетах
  for (category in names(DEPENDENCIES)[1:4]) {
    for (pkg in DEPENDENCIES[[category]]) {
      if (requireNamespace(pkg, quietly = TRUE)) {
        status <- "✓"
        version <- as.character(packageVersion(pkg))
      } else {
        status <- "✗"
        version <- "—"
      }
      report <- c(report, 
                  sprintf("| %s | `%s` | %s | %s |", category, pkg, status, version))
    }
  }
  
  # Добавляем системные зависимости
  report <- c(report,
              "",
              "## Системные зависимости",
              "",
              "| Инструмент | Статус |",
              "|------------|--------|"
  )
  
  for (tool in DEPENDENCIES$system) {
    exists <- nchar(Sys.which(tool)) > 0
    status <- ifelse(exists, "✓", "✗")
    report <- c(report, sprintf("| `%s` | %s |", tool, status))
  }
  
  # Записываем отчет в файл
  writeLines(report, output_file)
  
  cat(sprintf("✓ Отчет сохранен: %s\n", normalizePath(output_file)))
  
  return(invisible(report))
}

# ====================================================
# ОСНОВНАЯ ФУНКЦИЯ
# ====================================================

main <- function() {
  cat("\n")
  cat("╔══════════════════════════════════════════════╗\n")
  cat("║      ПРОВЕРКА ЗАВИСИМОСТЕЙ NETWALKER        ║\n")
  cat("╚══════════════════════════════════════════════╝\n")
  
  # Проверяем аргументы командной строки
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) > 0 && args[1] == "--report") {
    # Генерация отчета
    generate_dependency_report()
    return(invisible())
  }
  
  # Выполняем все проверки
  check_r_version()
  check_r_packages()
  check_system_dependencies()
  check_netwalker_functionality()
  
  # Финальное сообщение
  cat("\n")
  cat("╔══════════════════════════════════════════════╗\n")
  cat("║        ПРОВЕРКА ЗАВЕРШЕНА УСПЕШНО!          ║\n")
  cat("╚══════════════════════════════════════════════╝\n")
  cat("\nРекомендации:\n")
  cat("1. Установите все отсутствующие R пакеты\n")
  cat("2. Убедитесь, что системные утилиты установлены\n")
  cat("3. Для Docker развертывания проверьте Docker окружение\n")
  cat("4. Запустите тестовый traceroute: traceroute 8.8.8.8\n")
  
  # Предлагаем запустить тестовый скрипт
  cat("\nЗапустить тестовый скрипт NetWalker? (y/n): ")
  answer <- readLines("stdin", n = 1)
  
  if (tolower(answer) == "y") {
    cat("\nЗапуск тестового traceroute...\n")
    
    # Пытаемся запустить тестовую функцию
    if (requireNamespace("netwalker", quietly = TRUE)) {
      tryCatch({
        # Это пример, нужно адаптировать под реальные функции пакета
        result <- netwalker::run_traceroute("8.8.8.8")
        if (!is.null(result)) {
          cat("✓ Traceroute выполнен успешно!\n")
          print(head(result))
        }
      }, error = function(e) {
        cat(sprintf("✗ Ошибка: %s\n", e$message))
      })
    }
  }
}

# Запуск проверки
if (!interactive()) {
  main()
} else {
  cat("Запустите скрипт из командной строки: Rscript check_dependencies.R\n")
}