#' Resolve ASN for a single IPv4 address
#'
#' @param ip IPv4 string.
#' @param asn_ranges data.frame с диапазонами:
#'   ip_from (int/dbl), ip_to (int/dbl), asn (int), as_name (chr, optional), prefix (chr, optional)
#' @param resolver optional function(ip_vec) -> data.frame(ip, asn, as_name, prefix)
#'
#' @return data.frame one row: ip, asn, as_name, prefix
#' @export
asn_resolve_ip <- function(ip, asn_ranges = NULL, resolver = NULL) {
  ip <- normalize_ip(ip)
  if (is.na(ip) || !is_ipv4(ip)) {
    return(data.frame(ip = ip, asn = NA_integer_, as_name = NA_character_, prefix = NA_character_,
                      stringsAsFactors = FALSE))
  }
  
  if (!is.null(resolver) && is.function(resolver)) {
    out <- resolver(ip)
    return(asn_result_normalize(out, ip_col = "ip"))
  }
  
  if (is.null(asn_ranges)) {
    stop("Нужно передать либо asn_ranges, либо resolver-функцию.")
  }
  
  ip_int <- ipv4_to_int(ip)
  hit <- which(ip_int >= asn_ranges$ip_from & ip_int <= asn_ranges$ip_to)
  if (length(hit) == 0) {
    return(data.frame(ip = ip, asn = NA_integer_, as_name = NA_character_, prefix = NA_character_,
                      stringsAsFactors = FALSE))
  }
  
  # если несколько — берём первый (или самый узкий диапазон)
  if (length(hit) > 1) {
    widths <- asn_ranges$ip_to[hit] - asn_ranges$ip_from[hit]
    hit <- hit[which.min(widths)]
  } else {
    hit <- hit[1]
  }
  
  row <- asn_ranges[hit, , drop = FALSE]
  data.frame(
    ip = ip,
    asn = as.integer(row$asn),
    as_name = if ("as_name" %in% names(row)) as.character(row$as_name) else NA_character_,
    prefix = if ("prefix" %in% names(row)) as.character(row$prefix) else NA_character_,
    stringsAsFactors = FALSE
  )
}

#' Resolve ASN for a data.frame with IP column
#'
#' @param df input data.frame
#' @param ip_col column name with IP strings
#' @param asn_ranges see asn_resolve_ip
#' @param resolver optional function
#'
#' @return df with appended columns: asn, as_name, prefix
#' @export
asn_resolve_df <- function(df, ip_col = "ip", asn_ranges = NULL, resolver = NULL) {
  if (!ip_col %in% names(df)) stop("ip_col не найден в df")
  
  ips <- normalize_ip(df[[ip_col]])
  
  if (!is.null(resolver) && is.function(resolver)) {
    looked <- resolver(ips)
    looked <- asn_result_normalize(looked, ip_col = "ip")
    # merge by ip
    out <- merge(df, looked, by.x = ip_col, by.y = "ip", all.x = TRUE, sort = FALSE)
    return(out)
  }
  
  if (is.null(asn_ranges)) stop("Нужно передать либо asn_ranges, либо resolver-функцию.")
  
  # векторизованный lookup (простая реализация через apply — для больших данных лучше data.table/interval join)
  looked <- do.call(rbind, lapply(ips, function(x) asn_resolve_ip(x, asn_ranges = asn_ranges)))
  out <- cbind(df, looked[, c("asn","as_name","prefix"), drop = FALSE])
  out
}

asn_result_normalize <- function(x, ip_col = "ip") {
  if (!is.data.frame(x)) stop("resolver должен вернуть data.frame")
  if (!ip_col %in% names(x)) stop("В результате resolver нет колонки ip")
  
  if (!"asn" %in% names(x)) x$asn <- NA_integer_
  if (!"as_name" %in% names(x)) x$as_name <- NA_character_
  if (!"prefix" %in% names(x)) x$prefix <- NA_character_
  
  x[[ip_col]] <- normalize_ip(x[[ip_col]])
  x$asn <- suppressWarnings(as.integer(x$asn))
  x$as_name <- as.character(x$as_name)
  x$prefix <- as.character(x$prefix)
  
  x[, c(ip_col, "asn", "as_name", "prefix"), drop = FALSE]
}
