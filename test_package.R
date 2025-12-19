#!/usr/bin/env Rscript

# Test if the package loads without layout errors
tryCatch({
  library(netwalker)

  # Test one of the functions that had layout issues
  message("Testing create_rtt_plot with empty data...")
  result <- create_rtt_plot(NULL)
  message("✓ create_rtt_plot works with NULL data")

  message("Testing create_rtt_plot with empty data frame...")
  result <- create_rtt_plot(data.frame())
  message("✓ create_rtt_plot works with empty data frame")

  message("All tests passed! Package loads successfully.")

}, error = function(e) {
  message("Error loading package: ", e$message)
  quit(status = 1)
})
