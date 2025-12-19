.onLoad <- function(libname, pkgname) {
  options(
    "netwalker.settings" = list(
      max_hops = 30,
      timeout = 2,
      queries_per_hop = 1,
      use_ipv6 = FALSE,
      cache_days = 7,
      shiny_port = 3838,
      shiny_host = "127.0.0.1"
    )
  )
  
  cache_dir <- tools::R_user_dir("netwalker", "cache")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  
  data_dir <- file.path(cache_dir, "data")
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  
  db_file <- file.path(data_dir, "dbip_data.rds")
  if (!file.exists(db_file)) {
    packageStartupMessage("База данных не найдена. Используйте update_dbip_data()")
  }
  
  packageStartupMessage(
    "netwalker v0.1.0 загружен\n",
    "Используйте init_package_dirs() и update_dbip_data()"
  )
}

.onAttach <- function(libname, pkgname) {
  check_result <- try(check_package_readiness(), silent = TRUE)
  
  if (inherits(check_result, "try-error")) {
    packageStartupMessage("Внимание: возможны проблемы с зависимостями")
  }
}

.onUnload <- function(libpath) {
  temp_dir <- file.path(tools::R_user_dir("netwalker", "cache"), "temp")
  if (dir.exists(temp_dir)) {
    unlink(temp_dir, recursive = TRUE)
  }
}

.onDetach <- function(libpath) {
  options("netwalker.settings" = NULL)
}