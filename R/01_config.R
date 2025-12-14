pkg_name <- function() {
  "netwalker"
}

pkg_version <- function() {
  "0.1.0"
}

get_cache_dir <- function() {
  cache_dir <- tools::R_user_dir("netwalker", "cache")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }
  return(cache_dir)
}

get_data_dir <- function() {
  data_dir <- file.path(get_cache_dir(), "data")
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  return(data_dir)
}

get_logs_dir <- function() {
  logs_dir <- file.path(get_cache_dir(), "logs")
  if (!dir.exists(logs_dir)) {
    dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)
  }
  return(logs_dir)
}

get_temp_dir <- function() {
  temp_dir <- file.path(get_cache_dir(), "temp")
  if (!dir.exists(temp_dir)) {
    dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
  }
  return(temp_dir)
}

get_dbip_url <- function(date = NULL) {
  if (is.null(date)) {
    date <- format(Sys.Date(), "%Y-%m")
  }
  base_url <- "https://download.db-ip.com/free/dbip-country-lite"
  paste0(base_url, "-", date, ".csv.gz")
}

get_maxmind_url <- function() {
  message("MaxMind GeoLite2: https://dev.maxmind.com/geoip/geolite2-free-geolocation-data")
  return(NULL)
}

check_system_dependencies <- function(silent = FALSE) {
  dependencies <- c("traceroute", "whois")
  missing <- c()
  
  for (dep in dependencies) {
    if (Sys.which(dep) == "") {
      missing <- c(missing, dep)
    }
  }
  
  if (length(missing) > 0) {
    if (!silent) {
      message("Отсутствуют: ", paste(missing, collapse = ", "))
      message("Ubuntu/Debian: sudo apt-get install traceroute whois")
      message("macOS: brew install traceroute whois")
    }
    return(FALSE)
  }
  
  if (!silent) {
    message("✅ Все системные зависимости установлены")
  }
  return(TRUE)
}

get_default_settings <- function() {
  list(
    max_hops = 30,
    timeout = 2,
    queries_per_hop = 1,
    use_ipv6 = FALSE,
    cache_days = 7,
    cache_enabled = TRUE,
    shiny_port = 3838,
    shiny_host = "127.0.0.1",
    shiny_theme = "flatly",
    map_zoom = 2,
    map_center = c(20, 0),
    node_size = 20,
    edge_width = 2,
    db_provider = "dbip",
    auto_update = TRUE,
    log_level = "INFO",
    log_to_file = FALSE
  )
}

set_package_settings <- function(...) {
  settings <- list(...)
  current <- get_package_settings()
  
  for (name in names(settings)) {
    current[[name]] <- settings[[name]]
  }
  
  options("netwalker.settings" = current)
  
  if (length(settings) > 0) {
    log_message("INFO", paste("Обновлены:", paste(names(settings), collapse = ", ")))
  }
  
  invisible(TRUE)
}

get_package_settings <- function(name = NULL) {
  default <- get_default_settings()
  current <- getOption("netwalker.settings", list())
  
  merged <- utils::modifyList(default, current)
  
  if (!is.null(name)) {
    if (name %in% names(merged)) {
      return(merged[[name]])
    } else {
      warning("Настройка '", name, "' не найдена")
      return(NULL)
    }
  }
  
  return(merged)
}

log_message <- function(level = "INFO", message, ...) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_message <- sprintf("[%s] [%s] %s", timestamp, level, message)
  
  cat(full_message, "\n")
  
  settings <- get_package_settings()
  if (settings$log_to_file && level %in% c("WARN", "ERROR", "INFO")) {
    log_file <- file.path(get_logs_dir(), paste0("netwalker_", format(Sys.Date(), "%Y%m%d"), ".log"))
    write(paste(full_message, ...), file = log_file, append = TRUE)
  }
}

check_internet <- function(timeout = 3, test_url = "https://www.google.com") {
  tryCatch({
    response <- httr::GET(test_url, httr::timeout(timeout))
    status <- httr::status_code(response)
    
    if (status == 200) {
      log_message("DEBUG", "Интернет доступен")
      return(TRUE)
    } else {
      log_message("WARN", paste("Интернет недоступен, статус:", status))
      return(FALSE)
    }
  }, error = function(e) {
    log_message("WARN", paste("Интернет недоступен:", e$message))
    return(FALSE)
  })
}

get_system_info <- function() {
  sys_info <- Sys.info()
  
  info <- list(
    os = sys_info["sysname"],
    release = sys_info["release"],
    version = sys_info["version"],
    machine = sys_info["machine"],
    user = sys_info["user"],
    r_version = R.version.string,
    r_platform = R.version$platform,
    locale = Sys.getlocale()
  )
  
  if (info$os == "Linux") {
    tryCatch({
      info$distro <- system("lsb_release -d", intern = TRUE)[1]
    }, error = function(e) {
      info$distro <- "Unknown Linux"
    })
  } else if (info$os == "Darwin") {
    info$distro <- paste("macOS", system("sw_vers -productVersion", intern = TRUE))
  } else if (info$os == "Windows") {
    info$distro <- "Windows"
  }
  
  return(info)
}

clean_temp_files <- function(older_than = 24) {
  temp_dir <- get_temp_dir()
  
  if (!dir.exists(temp_dir)) {
    return(0)
  }
  
  files <- list.files(temp_dir, full.names = TRUE, recursive = TRUE)
  deleted <- 0
  
  for (file in files) {
    file_info <- file.info(file)
    age_hours <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "hours"))
    
    if (age_hours > older_than) {
      unlink(file, recursive = TRUE)
      deleted <- deleted + 1
    }
  }
  
  if (deleted > 0) {
    log_message("INFO", paste("Удалено файлов:", deleted))
  }
  
  return(deleted)
}

get_config_path <- function() {
  file.path(get_cache_dir(), "config.yaml")
}

save_config <- function(filepath = NULL) {
  if (is.null(filepath)) {
    filepath <- get_config_path()
  }
  
  config <- get_package_settings()
  
  tryCatch({
    yaml::write_yaml(config, filepath)
    log_message("INFO", paste("Конфигурация сохранена:", filepath))
    return(TRUE)
  }, error = function(e) {
    log_message("ERROR", paste("Ошибка:", e$message))
    return(FALSE)
  })
}

load_config <- function(filepath = NULL) {
  if (is.null(filepath)) {
    filepath <- get_config_path()
  }
  
  if (!file.exists(filepath)) {
    log_message("INFO", "Файл конфигурации не найден")
    return(FALSE)
  }
  
  tryCatch({
    config <- yaml::read_yaml(filepath)
    options("netwalker.settings" = config)
    log_message("INFO", paste("Конфигурация загружена:", filepath))
    return(TRUE)
  }, error = function(e) {
    log_message("ERROR", paste("Ошибка:", e$message))
    return(FALSE)
  })
}

reset_settings <- function(save = FALSE) {
  options("netwalker.settings" = get_default_settings())
  log_message("INFO", "Настройки сброшены")
  
  if (save) {
    save_config()
  }
  
  invisible(TRUE)
}