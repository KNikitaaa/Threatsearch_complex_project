#' Convert IP address to integer
#'
#' Safely converts IPv4 and IPv6 addresses to integer64.
#'
#' @param ip character vector of IP addresses
#' @return integer64 vector
#' @export
ip_to_int <- function(ip) {
  ipaddress::ip_to_integer(
    ipaddress::ip_address(ip)
  )
}

#' Convert integer to IP address
#'
#' Converts integer64 back to IPv4 or IPv6 string representation.
#'
#' @param x integer64 vector
#' @return character vector of IP addresses
#' @export
int_to_ip <- function(x) {
  as.character(
    ipaddress::ip_address(x)
  )
}
