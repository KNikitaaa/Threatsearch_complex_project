#' Parse traceroute output to tidy format
#'
#' @param raw character vector (lines) или trace_raw
#' @param os linux|mac|windows; если raw=trace_raw, берётся из meta.
#' @param target optional target label
#'
#' @return data.frame with columns:
#'   target, hop, probe, ip, hostname, rtt_ms, status, raw_line
#' @export
trace_parse <- function(raw,
                        os = c("linux", "mac", "windows"),
                        target = NULL) {
  
  if (inherits(raw, "trace_raw")) {
    target <- raw$target
    os <- raw$meta$os
    lines <- raw$raw
  } else {
    os <- match.arg(os)
    lines <- raw
  }
  
  if (length(lines) == 0) {
    return(data.frame(
      target = character(),
      hop = integer(),
      probe = integer(),
      ip = character(),
      hostname = character(),
      rtt_ms = numeric(),
      status = character(),
      raw_line = character(),
      stringsAsFactors = FALSE
    ))
  }
  
  if (os %in% c("linux", "mac")) {
    df <- parse_traceroute_unix(lines, target = target)
  } else {
    df <- parse_tracert_windows(lines, target = target)
  }
  
  trace_normalize(df)
}

#' Parse many trace_raw objects
#'
#' @param trace_raw_list list of trace_raw
#' @return combined data.frame
#' @export
trace_parse_many <- function(trace_raw_list) {
  out <- lapply(trace_raw_list, trace_parse)
  do.call(rbind, out)
}

#' Normalize parsed trace data to a consistent schema
#'
#' @param df data.frame
#' @return data.frame
#' @export
trace_normalize <- function(df) {
  # гарантируем колонки
  needed <- c("target","hop","probe","ip","hostname","rtt_ms","status","raw_line")
  for (nm in needed) {
    if (!nm %in% names(df)) df[[nm]] <- NA
  }
  
  df$target <- as.character(df$target)
  df$hop <- as.integer(df$hop)
  df$probe <- as.integer(df$probe)
  df$ip <- normalize_ip(df$ip)
  df$hostname <- ifelse(is.na(df$hostname) | df$hostname == "", NA_character_, as.character(df$hostname))
  df$rtt_ms <- suppressWarnings(as.numeric(df$rtt_ms))
  df$status <- as.character(df$status)
  df$raw_line <- as.character(df$raw_line)
  
  df[needed]
}

# ---- internal parsers ----

parse_traceroute_unix <- function(lines, target = NULL) {
  # Пример:
  #  1  router (192.168.0.1)  1.123 ms  0.987 ms  1.001 ms
  #  2  * * *
  #  3  1.1.1.1  10.2 ms  10.4 ms  10.3 ms
  # Иногда hostname (ip), иногда просто ip.
  rows <- list()
  
  # пропускаем заголовок вида "traceroute to ..."
  for (ln in lines) {
    if (grepl("^traceroute\\s+to\\s+", ln, ignore.case = TRUE)) next
    if (!grepl("^\\s*\\d+\\s+", ln)) next
    
    hop <- as.integer(sub("^\\s*(\\d+).*$", "\\1", ln))
    rest <- sub("^\\s*\\d+\\s+", "", ln)
    
    # timeout line
    if (grepl("^\\*\\s*\\*\\s*\\*$", trimws(rest))) {
      # создадим 3 пробы как NA (probe = 1..3) — но не знаем q; оставим одну строку
      rows[[length(rows) + 1]] <- data.frame(
        target = target,
        hop = hop,
        probe = 1L,
        ip = NA_character_,
        hostname = NA_character_,
        rtt_ms = NA_real_,
        status = "timeout",
        raw_line = ln,
        stringsAsFactors = FALSE
      )
      next
    }
    
    # Вытащим ip/hostname:
    # Вариант A: "name (ip)  rtt ms ..."
    # Вариант B: "ip  rtt ms ..."
    host <- NA_character_
    ip <- NA_character_
    
    if (grepl("\\(([^\\)]+)\\)", rest)) {
      ip <- sub(".*\\(([^\\)]+)\\).*", "\\1", rest)
      host_part <- sub("\\s*\\(([^\\)]+)\\).*", "", rest)
      host <- trimws(host_part)
      after <- sub(".*\\)\\s*", "", rest)
    } else {
      # первый токен
      tok1 <- strsplit(trimws(rest), "\\s+")[[1]]
      ip <- tok1[1]
      host <- NA_character_
      after <- sub(paste0("^", gsub("\\.", "\\\\.", ip), "\\s+"), "", trimws(rest))
    }
    
    # RTT значения: ищем числа перед "ms"
    rtts <- regmatches(after, gregexpr("([0-9]+\\.?[0-9]*)\\s*ms", after, perl = TRUE))[[1]]
    if (length(rtts) == 0) {
      # иногда бывают "!" метки, или странный формат
      rows[[length(rows) + 1]] <- data.frame(
        target = target,
        hop = hop,
        probe = 1L,
        ip = ip,
        hostname = host,
        rtt_ms = NA_real_,
        status = "unresolved",
        raw_line = ln,
        stringsAsFactors = FALSE
      )
      next
    }
    
    rtt_vals <- as.numeric(sub("\\s*ms$", "", gsub("\\s+", "", rtts)))
    
    for (i in seq_along(rtt_vals)) {
      rows[[length(rows) + 1]] <- data.frame(
        target = target,
        hop = hop,
        probe = as.integer(i),
        ip = ip,
        hostname = host,
        rtt_ms = rtt_vals[i],
        status = "ok",
        raw_line = ln,
        stringsAsFactors = FALSE
      )
    }
  }
  
  if (length(rows) == 0) return(data.frame())
  do.call(rbind, rows)
}

parse_tracert_windows <- function(lines, target = NULL) {
  # Пример:
  #  1    <1 ms    <1 ms    <1 ms  192.168.0.1
  #  2     *        *        *     Request timed out.
  #  3    10 ms    11 ms    10 ms  dns.google [8.8.8.8]
  rows <- list()
  
  for (ln in lines) {
    # пропускаем заголовки
    if (grepl("^Tracing\\s+route\\s+to", ln, ignore.case = TRUE)) next
    if (grepl("^over\\s+a\\s+maximum", ln, ignore.case = TRUE)) next
    if (grepl("^Trace\\s+complete", ln, ignore.case = TRUE)) next
    
    if (!grepl("^\\s*\\d+\\s+", ln)) next
    
    hop <- as.integer(sub("^\\s*(\\d+).*$", "\\1", ln))
    rest <- sub("^\\s*\\d+\\s+", "", ln)
    
    # Таймаут
    if (grepl("Request\\s+timed\\s+out", rest, ignore.case = TRUE) || grepl("^\\*\\s+\\*\\s+\\*", rest)) {
      rows[[length(rows) + 1]] <- data.frame(
        target = target,
        hop = hop,
        probe = 1L,
        ip = NA_character_,
        hostname = NA_character_,
        rtt_ms = NA_real_,
        status = "timeout",
        raw_line = ln,
        stringsAsFactors = FALSE
      )
      next
    }
    
    # RTT: могут быть "10 ms" или "<1 ms"
    rtts <- regmatches(rest, gregexpr("(<\\s*\\d+|\\d+)\\s*ms", rest, ignore.case = TRUE, perl = TRUE))[[1]]
    rtt_vals <- if (length(rtts) > 0) {
      v <- tolower(rtts)
      v <- gsub("\\s*ms", "", v)
      v <- gsub("\\s+", "", v)
      v <- ifelse(grepl("^<", v), sub("^<", "", v), v)
      as.numeric(v)
    } else numeric(0)
    
    # ip/hostname: "name [ip]" или просто ip в конце
    ip <- NA_character_
    host <- NA_character_
    
    if (grepl("\\[([^\\]]+)\\]", rest)) {
      ip <- sub(".*\\[([^\\]]+)\\].*$", "\\1", rest)
      host <- trimws(sub("\\s*\\[[^\\]]+\\].*$", "", rest))
      # host может включать RTT — поэтому лучше вычистить: берем часть после RTT блоков
      # но оставим как есть, т.к. нормализация hostname необязательна
    } else {
      # последний токен как IP
      toks <- strsplit(trimws(rest), "\\s+")[[1]]
      ip <- toks[length(toks)]
      host <- NA_character_
    }
    
    if (length(rtt_vals) == 0) {
      rows[[length(rows) + 1]] <- data.frame(
        target = target,
        hop = hop,
        probe = 1L,
        ip = ip,
        hostname = host,
        rtt_ms = NA_real_,
        status = "unresolved",
        raw_line = ln,
        stringsAsFactors = FALSE
      )
      next
    }
    
    for (i in seq_along(rtt_vals)) {
      rows[[length(rows) + 1]] <- data.frame(
        target = target,
        hop = hop,
        probe = as.integer(i),
        ip = ip,
        hostname = host,
        rtt_ms = rtt_vals[i],
        status = "ok",
        raw_line = ln,
        stringsAsFactors = FALSE
      )
    }
  }
  
  if (length(rows) == 0) return(data.frame())
  do.call(rbind, rows)
}
