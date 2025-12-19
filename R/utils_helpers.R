is_valid_ip <- function(ip, version = "any") {
  if (!is.character(ip) || length(ip) != 1 || is.na(ip)) {
    return(FALSE)
  }
  
  ip <- trimws(ip)
  
  ipv4_pattern <- "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
  
  ipv6_pattern <- "^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|:((:[0-9a-fA-F]{1,4}){1,7}|:)|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,7}|:)|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$"
  
  if (version == 4) {
    return(grepl(ipv4_pattern, ip))
  } else if (version == 6) {
    return(grepl(ipv6_pattern, ip))
  } else {
    return(grepl(ipv4_pattern, ip) || grepl(ipv6_pattern, ip))
  }
}

is_valid_domain <- function(domain) {
  if (!is.character(domain) || length(domain) != 1) return(FALSE)
  
  domain_pattern <- "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"
  
  return(grepl(domain_pattern, domain) && nchar(domain) <= 253)
}

resolve_domain <- function(domain) {
  if (!is_valid_domain(domain)) {
    log_message("ERROR", paste("Невалидный домен:", domain))
    return(NULL)
  }
  
  tryCatch({
    ip <- nslookup::nsl(domain)
    if (is.null(ip)) {
      ip <- system(paste("dig +short", domain), intern = TRUE)[1]
    }
    return(ip)
  }, error = function(e) {
    tryCatch({
      ip <- system(paste("nslookup", domain, "| grep Address | tail -1 | awk '{print $2}'"), 
                   intern = TRUE, ignore.stderr = TRUE)
      if (length(ip) > 0 && ip != "") {
        return(ip)
      }
    }, error = function(e2) {})
    
    log_message("ERROR", paste("Ошибка разрешения:", domain))
    return(NULL)
  })
}

ip_to_numeric <- function(ip) {
  if (!is_valid_ip(ip, version = 4)) return(NA)
  
  parts <- as.numeric(strsplit(ip, "\\.")[[1]])
  sum(parts * 256^(3:0))
}

numeric_to_ip <- function(num) {
  if (is.na(num) || num < 0 || num > 4294967295) return(NA)
  
  parts <- c()
  for (i in 3:0) {
    part <- floor(num / (256^i))
    parts <- c(parts, part)
    num <- num - part * (256^i)
  }
  paste(parts, collapse = ".")
}

normalize_ip <- function(ip) {
  if (!is_valid_ip(ip)) return(NA)
  
  ip <- trimws(ip)
  
  if (grepl("\\.", ip)) {
    parts <- as.integer(strsplit(ip, "\\.")[[1]])
    return(paste(parts, collapse = "."))
  }
  
  return(ip)
}

extract_asn <- function(text) {
  if (is.na(text) || is.null(text) || text == "") return(NA)
  
  as_pattern <- "[Aa][Ss][\\s]?([0-9]+)"
  
  matches <- regmatches(text, regexpr(as_pattern, text, perl = TRUE))
  
  if (length(matches) > 0) {
    asn <- gsub("[^0-9]", "", matches[1])
    return(as.integer(asn))
  }
  
  return(NA)
}

format_file_size <- function(bytes) {
  units <- c("B", "KB", "MB", "GB", "TB")
  size <- bytes
  unit_index <- 1
  
  while (size >= 1024 && unit_index < length(units)) {
    size <- size / 1024
    unit_index <- unit_index + 1
  }
  
  sprintf("%.2f %s", size, units[unit_index])
}

get_timestamp <- function(format = "%Y%m%d_%H%M%S") {
  format(Sys.time(), format)
}

create_unique_id <- function(prefix = "id", length = 8) {
  timestamp <- get_timestamp("%Y%m%d%H%M%S")
  random <- paste(sample(c(letters, 0:9), length, replace = TRUE), collapse = "")
  paste(prefix, timestamp, random, sep = "_")
}

safe_execute <- function(func, default = NULL, ...) {
  tryCatch({
    func(...)
  }, error = function(e) {
    log_message("ERROR", paste("Ошибка:", e$message))
    return(default)
  })
}

is_port_available <- function(port, host = "127.0.0.1") {
  tryCatch({
    sock <- socketConnection(host = host, port = port, server = FALSE, timeout = 1)
    close(sock)
    return(FALSE)
  }, error = function(e) {
    return(TRUE)
  })
}

find_free_port <- function(start_port = 3000, max_attempts = 100) {
  for (port in start_port:(start_port + max_attempts)) {
    if (is_port_available(port)) {
      return(port)
    }
  }
  stop("Не найден свободный порт")
}