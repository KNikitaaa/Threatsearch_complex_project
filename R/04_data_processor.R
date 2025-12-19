#' Resolve ASN for IP addresses
#'
#' Maps IP addresses to ASN numbers and organization names.
#'
#' @param ip character vector of IP addresses
#' @param asn_data data.table with ASN ranges (optional)
#' @return data.table with columns: ip, asn, asn_name
#' @export
resolve_asn <- function(ip, asn_data = NULL) {
  
  # Load ASN data if not provided
  if (is.null(asn_data)) {
    asn_data <- load_dbip_asn()
  }
  
  # Convert IPs to integer (IPv4 + IPv6 safe)
  ip_int <- ip_to_int(ip)
  
  # Prepare IP table
  dt_ip <- data.table::data.table(
    ip = ip,
    ip_int = ip_int
  )
  
  # Non-equi join: ip ∈ [ip_start_int, ip_end_int]
  result <- asn_data[
    dt_ip,
    on = .(
      ip_start_int <= ip_int,
      ip_end_int   >= ip_int
    ),
    nomatch = NA,
    .(ip = i.ip, asn, asn_name)
  ]
  
  result
}
