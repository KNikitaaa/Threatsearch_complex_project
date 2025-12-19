#' Detect OS in simplified form
#'
#' @return "windows"|"mac"|"linux"
#' @export
detect_os <- function() {
  si <- Sys.info()[["sysname"]]
  if (is.na(si)) si <- .Platform$OS.type
  si <- tolower(si)
  
  if (grepl("windows", si)) return("windows")
  if (grepl("darwin", si) || grepl("mac", si)) return("mac")
  "linux"
}

#' Safe system2 wrapper
#'
#' @param command command name
#' @param args character args
#' @param timeout not used directly; placeholder for future.
#'
#' @return character lines (stdout+stderr)
#' @export
safe_system2 <- function(command, args = character(), timeout = NULL) {
  # В base R нет кроссплатформенного timeout для system2 без доп.пакетов.
  # Поэтому просто захватываем stdout/stderr.
  out <- tryCatch({
    stdout <- tempfile()
    stderr <- tempfile()
    on.exit({
      if (file.exists(stdout)) unlink(stdout)
      if (file.exists(stderr)) unlink(stderr)
    }, add = TRUE)
    
    status <- suppressWarnings(system2(command, args = args, stdout = stdout, stderr = stderr))
    txt <- c(readLines(stdout, warn = FALSE), readLines(stderr, warn = FALSE))
    
    if (!is.null(status) && status != 0) {
      # не валим, а возвращаем как есть, но добавим предупреждение
      warning(sprintf("Команда завершилась с кодом %s: %s %s", status, command, paste(args, collapse = " ")))
    }
    txt
  }, error = function(e) {
    stop(sprintf("Не удалось выполнить команду %s: %s", command, e$message))
  })
  out
}

#' Check if string is IPv4
#' @param x character
#' @export
is_ipv4 <- function(x) {
  if (length(x) == 0) return(logical(0))
  ok <- grepl("^\\d{1,3}(\\.\\d{1,3}){3}$", x)
  ok & vapply(strsplit(x, "\\."), function(p) all(as.integer(p) >= 0 & as.integer(p) <= 255), logical(1))
}

#' Check if string is IPv6 (simple)
#' @param x character
#' @export
is_ipv6 <- function(x) {
  if (length(x) == 0) return(logical(0))
  grepl(":", x, fixed = TRUE)
}

#' Normalize IP strings
#' @param x character
#' @export
normalize_ip <- function(x) {
  if (is.null(x)) return(NA_character_)
  x <- as.character(x)
  x <- trimws(x)
  x[x == ""] <- NA_character_
  x
}

#' Convert IPv4 to integer (double-safe)
#' @param ip IPv4 string
#' @export
ipv4_to_int <- function(ip) {
  ip <- normalize_ip(ip)
  if (is.na(ip) || !is_ipv4(ip)) return(NA_real_)
  parts <- as.numeric(strsplit(ip, "\\.")[[1]])
  # 256^3*a + 256^2*b + 256*c + d
  parts[1] * 256^3 + parts[2] * 256^2 + parts[3] * 256 + parts[4]
}

#' Simple ping check (optional utility)
#'
#' @param host host/ip
#' @param count number of pings
#' @param timeout seconds
#'
#' @return TRUE/FALSE
#' @export
ping_check <- function(host, count = 1, timeout = 1) {
  os <- detect_os()
  if (os == "windows") {
    cmd <- "ping"
    args <- c("-n", as.character(count), "-w", as.character(as.integer(timeout * 1000)), host)
  } else {
    cmd <- "ping"
    args <- c("-c", as.character(count), "-W", as.character(as.integer(timeout)), host)
  }
  out <- tryCatch(safe_system2(cmd, args), error = function(e) character())
  any(grepl("ttl=", out, ignore.case = TRUE)) || any(grepl("bytes from", out, ignore.case = TRUE))
}
