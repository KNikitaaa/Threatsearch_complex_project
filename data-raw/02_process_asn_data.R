# data-raw/02_process_asn_data.R

library(data.table)
library(ipaddress)

raw_file <- "data-raw/raw/dbip-asn.csv.gz"
out_dir <- "data"
out_file <- file.path(out_dir, "dbip_asn.rds")

if (!file.exists(raw_file)) {
  stop("Raw DBIP ASN file not found: ", raw_file)
}

if (!dir.exists(out_dir)) {
  dir.create(out_dir)
}

message("Reading DBIP ASN data...")

# 🔹 IMPORTANT: fread can read .csv.gz directly on Windows
dt <- fread(
  raw_file,
  col.names = c("ip_start", "ip_end", "asn", "asn_name")
)

message("Processing IP ranges...")

dt[, ip_start_int := ip_to_integer(ip_address(ip_start))]
dt[, ip_end_int   := ip_to_integer(ip_address(ip_end))]

dt <- dt[!is.na(asn)]
setkey(dt, ip_start_int, ip_end_int)

message("Saving processed ASN data...")
saveRDS(dt, out_file)

message("Done. Saved to: ", out_file)
