#' Initialize package directories
#' @export
init_package_dirs <- function() {
  log_message("INFO", "Initializing directories...")

  dirs <- list(
    "Cache" = get_cache_dir(),
    "Data" = get_data_dir(),
    "Logs" = get_logs_dir(),
    "Temp files" = get_temp_dir()
  )
  
  success <- TRUE
  
  for (dir_name in names(dirs)) {
    dir_path <- dirs[[dir_name]]
    
    if (!dir.exists(dir_path)) {
      created <- dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
      
      if (created) {
        log_message("INFO", paste("✓", dir_name, ":", dir_path))
      } else {
        log_message("ERROR", paste("✗ Error:", dir_name))
        success <- FALSE
      }
    } else {
      log_message("DEBUG", paste("✓", dir_name, "уже есть:", dir_path))
    }
  }
  
  if (success) {
    log_message("INFO", "Директории созданы")
  } else {
    log_message("ERROR", "Ошибки при создании директорий")
  }
  
  return(success)
}

#' Install system dependencies
#' @export
install_system_deps <- function(os = "auto", silent = FALSE) {
  if (os == "auto") {
    sys_info <- Sys.info()
    os <- tolower(sys_info["sysname"])
  }
  
  if (!silent) {
    log_message("INFO", paste("ОС:", os))
  }
  
  commands <- list()
  
  if (os == "linux") {
    if (file.exists("/etc/debian_version")) {
      commands <- list(
        update = "sudo apt-get update -qq",
        install = "sudo apt-get install -y traceroute whois curl"
      )
    } else if (file.exists("/etc/redhat-release")) {
      commands <- list(
        install = "sudo yum install -y traceroute whois curl"
      )
    } else if (file.exists("/etc/arch-release")) {
      commands <- list(
        install = "sudo pacman -S --noconfirm traceroute whois curl"
      )
    } else {
      if (!silent) {
        log_message("WARN", "Дистрибутив не распознан")
      }
      return(FALSE)
    }
  } else if (os == "darwin") {
    commands <- list(
      install = "brew install traceroute whois curl"
    )
  } else if (os == "windows") {
    if (!silent) {
      log_message("INFO", "Для Windows установите вручную:")
      log_message("INFO", "1. WinMTR: https://sourceforge.net/projects/winmtr/")
      log_message("INFO", "2. Sysinternals Whois")
      log_message("INFO", "3. Добавьте в PATH")
    }
    return(FALSE)
  } else {
    if (!silent) {
      log_message("ERROR", paste("ОС не поддерживается:", os))
    }
    return(FALSE)
  }
  
  success <- TRUE
  
  for (cmd_name in names(commands)) {
    cmd <- commands[[cmd_name]]
    
    if (!silent) {
      log_message("INFO", paste("Выполнение:", cmd))
    }
    
    result <- tryCatch({
      system(cmd, ignore.stderr = silent, ignore.stdout = silent)
    }, error = function(e) {
      if (!silent) {
        log_message("ERROR", paste("Ошибка:", e$message))
      }
      return(-1)
    })
    
    if (result != 0) {
      success <- FALSE
      if (!silent) {
        log_message("WARN", paste("Ошибка команды:", cmd))
      }
    }
  }
  
  if (success) {
    if (!silent) {
      log_message("INFO", "Зависимости установлены")
    }
  } else {
    if (!silent) {
      log_message("WARN", "Проблемы с установкой")
    }
  }
  
  return(success)
}

#' Check package readiness
#' @export
check_package_readiness <- function(verbose = TRUE) {
  results <- list(
    timestamp = Sys.time(),
    system = get_system_info(),
    checks = list(),
    summary = list()
  )
  
  if (verbose) cat("\n📁 Проверка директорий:\n")
  
  dirs_to_check <- list(
    "Кэш" = get_cache_dir(),
    "Данные" = get_data_dir(),
    "Логи" = get_logs_dir(),
    "Временные файлы" = get_temp_dir()
  )
  
  dirs_ok <- TRUE
  for (dir_name in names(dirs_to_check)) {
    dir_path <- dirs_to_check[[dir_name]]
    exists <- dir.exists(dir_path)
    writable <- if (exists) file.access(dir_path, 2) == 0 else FALSE
    
    results$checks[[paste0("dir_", tolower(dir_name))]] <- list(
      exists = exists,
      writable = writable,
      path = dir_path
    )
    
    if (verbose) {
      status <- if (exists && writable) "✓" else if (exists) "⚠" else "✗"
      cat(sprintf("  %s %s: %s\n", status, dir_name, dir_path))
      if (exists && !writable) cat("     (нет прав на запись)\n")
    }
    
    if (!exists || !writable) dirs_ok <- FALSE
  }
  
  results$summary$dirs_ok <- dirs_ok
  
  if (verbose) cat("\n🔧 Системные зависимости:\n")
  
  sys_deps <- check_system_dependencies(silent = TRUE)
  results$checks$system_deps <- list(
    traceroute = Sys.which("traceroute") != "",
    whois = Sys.which("whois") != "",
    curl = Sys.which("curl") != "",
    all_ok = sys_deps
  )
  
  results$summary$sys_deps_ok <- sys_deps
  
  if (verbose) {
    deps <- c("traceroute", "whois", "curl")
    for (dep in deps) {
      status <- if (Sys.which(dep) != "") "✓" else "✗"
      cat(sprintf("  %s %s\n", status, dep))
    }
  }
  
  if (verbose) cat("\n📦 R пакеты:\n")
  
  required_packages <- c(
    "dplyr", "tidyr", "purrr", "stringr",
    "httr", "jsonlite", "data.table",
    "shiny", "leaflet", "visNetwork",
    "processx", "duckdb", "yaml"
  )
  
  installed <- sapply(required_packages, requireNamespace, quietly = TRUE)
  missing_packages <- required_packages[!installed]
  
  results$checks$r_packages <- list(
    required = required_packages,
    installed = installed,
    missing = missing_packages,
    all_ok = length(missing_packages) == 0
  )
  
  results$summary$r_deps_ok <- length(missing_packages) == 0
  
  if (verbose) {
    for (pkg in required_packages) {
      status <- if (installed[pkg]) "✓" else "✗"
      cat(sprintf("  %s %s\n", status, pkg))
    }
    
    if (length(missing_packages) > 0) {
      cat("  Установите: install.packages(c('", 
          paste(missing_packages, collapse = "', '"), "'))\n", sep = "")
    }
  }
  
  if (verbose) cat("\n🌐 Интернет:\n")
  
  internet_ok <- check_internet(timeout = 2)
  results$checks$internet <- list(
    available = internet_ok,
    test_url = "https://www.google.com"
  )
  
  results$summary$internet_ok <- internet_ok
  
  if (verbose) {
    status <- if (internet_ok) "✓" else "✗"
    cat(sprintf("  %s Доступ к интернету\n", status))
  }
  
  if (verbose) cat("\n🗄️ База данных:\n")
  
  db_file <- file.path(get_data_dir(), "dbip_data.rds")
  db_exists <- file.exists(db_file)
  
  if (db_exists) {
    file_info <- file.info(db_file)
    days_old <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))
    db_fresh <- days_old < get_package_settings()$cache_days
    db_size <- file_info$size
  } else {
    days_old <- NA
    db_fresh <- FALSE
    db_size <- 0
  }
  
  results$checks$database <- list(
    exists = db_exists,
    path = db_file,
    size = db_size,
    days_old = days_old,
    is_fresh = db_fresh
  )
  
  results$summary$db_ok <- db_exists
  results$summary$db_fresh <- db_fresh
  
  if (verbose) {
    if (db_exists) {
      status <- if (db_fresh) "✓" else "⚠"
      size_mb <- round(db_size / 1024 / 1024, 2)
      cat(sprintf("  %s База: %.2f MB (возраст: %.1f дней)\n", 
                  status, size_mb, days_old))
    } else {
      cat("  ✗ База данных отсутствует\n")
      cat("    Используйте update_dbip_data()\n")
    }
  }
  
  results$summary$all_ok <- all(c(
    dirs_ok, 
    sys_deps, 
    length(missing_packages) == 0,
    internet_ok,
    db_exists
  ))
  
  if (verbose) {
    cat("\n" + rep("=", 50) + "\n")
    cat("📊 ИТОГ:\n\n")
    
    checks <- list(
      "Директории" = dirs_ok,
      "Системные зависимости" = sys_deps,
      "R пакеты" = length(missing_packages) == 0,
      "Интернет" = internet_ok,
      "База данных" = db_exists
    )
    
    all_passed <- TRUE
    for (check_name in names(checks)) {
      status <- checks[[check_name]]
      symbol <- if (status) "✅" else "❌"
      cat(sprintf("%s %s\n", symbol, check_name))
      if (!status) all_passed <- FALSE
    }
    
    cat("\n" + rep("-", 50) + "\n")
    
    if (all_passed) {
      cat("🎉 Пакет готов!\n")
    } else {
      cat("⚠️  Есть проблемы\n")
    }
  }
  
  invisible(results)
}

#' Update package database
#' @export
update_package_database <- function(force = FALSE, verbose = TRUE) {
  if (verbose) {
    log_message("INFO", "Обновление базы данных...")
  }
  
  db_file <- file.path(get_data_dir(), "dbip_data.rds")
  
  if (file.exists(db_file) && !force) {
    file_info <- file.info(db_file)
    days_old <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))
    cache_days <- get_package_settings()$cache_days
    
    if (days_old < cache_days) {
      if (verbose) {
        log_message("INFO", paste("База актуальна (возраст:", 
                                  round(days_old, 1), "дней)"))
      }
      return(TRUE)
    }
  }
  
  if (!check_internet()) {
    log_message("ERROR", "Нет интернета")
    return(FALSE)
  }
  
  if (exists("download_dbip_data")) {
    tryCatch({
      if (verbose) log_message("INFO", "Загрузка DBIP...")
      
      db_data <- download_dbip_data()
      
      if (verbose) {
        log_message("INFO", paste("Строк:", nrow(db_data)))
      }
      
      saveRDS(db_data, db_file)
      
      if (verbose) {
        size_mb <- round(file.info(db_file)$size / 1024 / 1024, 2)
        log_message("INFO", paste("Сохранено:", size_mb, "MB"))
      }
      
      return(TRUE)
      
    }, error = function(e) {
      log_message("ERROR", paste("Ошибка:", e$message))
      return(FALSE)
    })
  } else {
    log_message("ERROR", "Функция download_dbip_data не найдена")
    return(FALSE)
  }
}

#' Get package information
#' @export
get_package_info <- function(detailed = FALSE) {
  info <- list(
    package = list(
      name = pkg_name(),
      version = pkg_version(),
      description = "Анализ автономных систем и маршрутизации",
      authors = "Команда NetWalker",
      license = "MIT",
      repository = "https://github.com/your-team/netwalker"
    ),
    paths = list(
      cache_dir = get_cache_dir(),
      data_dir = get_data_dir(),
      logs_dir = get_logs_dir(),
      temp_dir = get_temp_dir()
    ),
    settings = get_package_settings(),
    system = get_system_info()
  )
  
  if (detailed) {
    info$readiness <- check_package_readiness(verbose = FALSE)
  } else {
    info$readiness <- list(
      all_ok = check_package_readiness(verbose = FALSE)$summary$all_ok
    )
  }
  
  db_file <- file.path(get_data_dir(), "dbip_data.rds")
  if (file.exists(db_file)) {
    file_info <- file.info(db_file)
    info$database <- list(
      exists = TRUE,
      size = file_info$size,
      modified = file_info$mtime,
      age_days = as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))
    )
  } else {
    info$database <- list(exists = FALSE)
  }
  
  return(info)
}

#' Clear package cache
#' @export
clear_package_cache <- function(what = "all", confirm = TRUE) {
  if (confirm) {
    if (what == "all") {
      message <- "Очистить ВЕСЬ кэш? (y/n): "
    } else {
      message <- paste("Очистить", what, "? (y/n): ")
    }
    
    response <- readline(prompt = message)
    if (!tolower(response) %in% c("y", "yes", "да")) {
      log_message("INFO", "Отменено")
      return(FALSE)
    }
  }
  
  dirs_to_clear <- list()
  
  if (what == "all") {
    dirs_to_clear <- list(
      data = get_data_dir(),
      logs = get_logs_dir(),
      temp = get_temp_dir()
    )
  } else if (what == "data") {
    dirs_to_clear <- list(data = get_data_dir())
  } else if (what == "logs") {
    dirs_to_clear <- list(logs = get_logs_dir())
  } else if (what == "temp") {
    dirs_to_clear <- list(temp = get_temp_dir())
  } else if (what == "cache") {
    cache_dir <- get_cache_dir()
    if (dir.exists(cache_dir)) {
      unlink(cache_dir, recursive = TRUE)
      log_message("INFO", paste("Очищен кэш:", cache_dir))
      return(TRUE)
    }
    return(FALSE)
  } else {
    log_message("ERROR", paste("Неизвестно:", what))
    return(FALSE)
  }
  
  cleared <- 0
  for (dir_name in names(dirs_to_clear)) {
    dir_path <- dirs_to_clear[[dir_name]]
    if (dir.exists(dir_path)) {
      unlink(dir_path, recursive = TRUE)
      log_message("INFO", paste("Очищено", dir_name, ":", dir_path))
      cleared <- cleared + 1
    }
  }
  
  init_package_dirs()
  
  if (cleared > 0) {
    log_message("INFO", paste("Очищено:", cleared))
    return(TRUE)
  } else {
    log_message("INFO", "Нет для очистки")
    return(FALSE)
  }
}

#' Export package information
#' @export
export_package_info <- function(filepath = NULL, format = "json") {
  info <- get_package_info(detailed = TRUE)
  
  if (is.null(filepath)) {
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    filename <- paste0("netwalker_info_", timestamp, ".", format)
    filepath <- file.path(get_logs_dir(), filename)
  }
  
  tryCatch({
    if (format == "json") {
      jsonlite::write_json(info, filepath, pretty = TRUE, auto_unbox = TRUE)
    } else if (format == "yaml") {
      yaml::write_yaml(info, filepath)
    } else if (format == "rds") {
      saveRDS(info, filepath)
    } else {
      stop("Неподдерживаемый формат: ", format)
    }
    
    log_message("INFO", paste("Экспорт:", filepath))
    return(filepath)
    
  }, error = function(e) {
    log_message("ERROR", paste("Ошибка экспорта:", e$message))
    return(NULL)
  })
}
