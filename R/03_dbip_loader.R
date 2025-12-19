#' Load DBIP ASN dataset
#'
#' Loads processed DBIP ASN data shipped with the package.
#'
#' @param sample logical. If TRUE, loads sample dataset.
#' @return data.table with ASN ranges
#' @export
load_dbip_asn <- function(sample = FALSE) {

  file <- if (sample) {
    system.file("data", "sample_asn.rds", package = "threatsearch")
  } else {
    system.file("data", "dbip_asn.rds", package = "threatsearch")
  }

  if (file == "") {
    stop("DBIP ASN dataset not found in package")
  }

  readRDS(file)
}
