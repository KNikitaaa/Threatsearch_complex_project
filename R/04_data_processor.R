#' Resolve ASN for IP addresses (IPv4)
#'
#' Fast ASN lookup for IPv4 using interval search.
#'
#' @param ip character vector of IP addresses
#' @param asn_data data.table with ASN ranges
#' @return data.table with columns: ip, asn, asn_name
#' @export
resolve_asn <- function(ip, asn_data) {
  
  if (missing(asn_data)) {
    stop("asn_data must be provided in dev mode")
  }
  
  if (!data.table::is.data.table(asn_data)) {
    data.table::setDT(asn_data)
  }
  
  ipv4_to_num <- function(ip) {
    parts <- strsplit(ip, ".", fixed = TRUE)
    vapply(parts, function(x) {
      as.numeric(x[1]) * 256^3 +
        as.numeric(x[2]) * 256^2 +
        as.numeric(x[3]) * 256 +
        as.numeric(x[4])
    }, numeric(1))
  }
  
  asn_ipv4 <- asn_data[!grepl(":", ip_start)]
  
  asn_ipv4[, ip_start_num := ipv4_to_num(ip_start)]
  asn_ipv4[, ip_end_num   := ipv4_to_num(ip_end)]
  
  data.table::setorder(asn_ipv4, ip_start_num)
  
  is_v4 <- !grepl(":", ip)
  ip_v4 <- ip[is_v4]
  ip_num <- ipv4_to_num(ip_v4)
  
  idx <- findInterval(ip_num, asn_ipv4$ip_start_num)
  
  result <- data.table::data.table(
    ip = ip,
    asn = NA_integer_,
    asn_name = NA_character_
  )
  
  res_rows <- which(is_v4)
  
  valid <- idx > 0 & ip_num <= asn_ipv4$ip_end_num[idx]
  
  result[res_rows[valid], `:=`(
    asn = asn_ipv4$asn[idx[valid]],
    asn_name = asn_ipv4$asn_name[idx[valid]]
  )]
  
  result
}
