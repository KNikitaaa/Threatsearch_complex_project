
#Спойлер: я все равно загрузил вручную

dbip_url <- "https://download.db-ip.com/free/dbip-asn-lite.csv.gz"
dest_dir <- "data-raw/raw"
dest_file <- file.path(dest_dir, "dbip-asn.csv.gz")

if (!dir.exists(dest_dir)) {
  dir.create(dest_dir, recursive = TRUE)
}

message("Downloading DBIP ASN data...")
download.file(
  url = dbip_url,
  destfile = dest_file,
  mode = "wb",
  quiet = FALSE
)

message("Download completed: ", dest_file)
