# ============================================================
# Build COMEXT aluminum split parameter for 2014
# - Computes aluminum share within non-ferrous metals
# - Primary source: SITC Rev.3 aggregate file
# - Fallback source: legacy non-ferrous extract
# ============================================================

library(dplyr)
library(readr)
library(stringr)

RAW_DIR <- "data_raw/COMEXT"
PROC_DIR <- "data_processed"
out_path <- file.path(PROC_DIR, "comext_al_share_within_nonferrous_2014_sitc.csv")

dir.create(PROC_DIR, showWarnings = FALSE, recursive = TRUE)

compute_from_sitc <- function(path) {
  comext <- read_csv(path, show_col_types = FALSE)

  comext_2014 <- comext %>%
    mutate(
      product = str_squish(product),
      flow = str_to_upper(str_squish(flow)),
      indicators = str_to_upper(str_squish(indicators)),
      TIME_PERIOD = as.integer(TIME_PERIOD)
    ) %>%
    filter(
      TIME_PERIOD == 2014,
      flow == "IMPORT",
      indicators == "VALUE_EUR"
    ) %>%
    group_by(product) %>%
    summarise(value_eur = sum(OBS_VALUE, na.rm = TRUE), .groups = "drop")

  nonferrous_total <- comext_2014 %>%
    filter(product == "Non-ferrous metals") %>%
    pull(value_eur)

  aluminum_total <- comext_2014 %>%
    filter(product == "Aluminium") %>%
    pull(value_eur)

  tibble(
    year = 2014,
    source = "COMEXT_SITC_2014.csv",
    nonferrous_value_eur = nonferrous_total,
    aluminum_value_eur = aluminum_total,
    aluminum_share_within_nonferrous = aluminum_total / nonferrous_total
  )
}

compute_from_legacy <- function(path) {
  comext <- read_csv(path, show_col_types = FALSE)

  by_prod <- comext %>%
    filter(product != "Total") %>%
    group_by(product) %>%
    summarise(value_eur = sum(OBS_VALUE, na.rm = TRUE), .groups = "drop")

  aluminum_total <- by_prod %>%
    filter(str_detect(product, "ALUMIN")) %>%
    pull(value_eur)

  nonferrous_total <- by_prod %>%
    summarise(v = sum(value_eur, na.rm = TRUE)) %>%
    pull(v)

  tibble(
    year = 2014,
    source = "COMTEXTnon-ferrous2014.csv",
    nonferrous_value_eur = nonferrous_total,
    aluminum_value_eur = aluminum_total,
    aluminum_share_within_nonferrous = aluminum_total / nonferrous_total
  )
}

sitc_path <- file.path(RAW_DIR, "COMEXT_SITC_2014.csv")
legacy_path <- file.path(RAW_DIR, "COMTEXTnon-ferrous2014.csv")

if (file.exists(sitc_path)) {
  result <- compute_from_sitc(sitc_path)
} else if (file.exists(legacy_path)) {
  result <- compute_from_legacy(legacy_path)
} else {
  stop("No supported COMEXT 2014 input found in data_raw/COMEXT/.")
}

write_csv(result, out_path)

print(result)
cat("\nSaved file to ", out_path, "\n", sep = "")
