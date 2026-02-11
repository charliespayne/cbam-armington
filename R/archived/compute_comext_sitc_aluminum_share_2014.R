# ============================================================
# COMEXT 2014 (SITC Rev.3)
# Compute aluminum share within non-ferrous metals (SITC 68)
# ============================================================

library(dplyr)
library(stringr)
library(readr)

# ------------------------------------------------------------
# 1) Set directories
# ------------------------------------------------------------
RAW_DIR  <- "data_raw/COMEXT"
PROC_DIR <- "data_processed"

dir.create(PROC_DIR, showWarnings = FALSE)

# ------------------------------------------------------------
# 2) Read COMEXT file
# ------------------------------------------------------------
comext <- read_csv(
  file.path(RAW_DIR, "COMEXT_SITC_2014.csv"),
  show_col_types = FALSE
)

# ------------------------------------------------------------
# 3) Clean and filter to 2014 EU imports in euros
# ------------------------------------------------------------
comext_clean <- comext %>%
  mutate(
    product     = str_squish(product),
    flow        = str_to_upper(str_squish(flow)),
    indicators  = str_to_upper(str_squish(indicators)),
    TIME_PERIOD = as.integer(TIME_PERIOD)
  ) %>%
  filter(
    TIME_PERIOD == 2014,
    flow == "IMPORT",
    indicators == "VALUE_EUR"
  )

# Sanity check (should be 95 rows)
cat("Filtered rows:", nrow(comext_clean), "\n\n")

# ------------------------------------------------------------
# 4) Aggregate by product label
# ------------------------------------------------------------
comext_2014 <- comext_clean %>%
  group_by(product) %>%
  summarise(
    value_eur = sum(OBS_VALUE, na.rm = TRUE),
    .groups = "drop"
  )

# ------------------------------------------------------------
# 5) Extract roll-up values
# ------------------------------------------------------------

# SITC 68 (Non-ferrous metals total)
nonferrous_total <- comext_2014 %>%
  filter(product == "Non-ferrous metals") %>%
  pull(value_eur)

# SITC 684 (Aluminium total)
aluminum_total <- comext_2014 %>%
  filter(product == "Aluminium") %>%
  pull(value_eur)

# ------------------------------------------------------------
# 6) Compute aluminum share
# ------------------------------------------------------------
aluminum_share <- aluminum_total / nonferrous_total

result <- tibble(
  year = 2014,
  nonferrous_value_eur = nonferrous_total,
  aluminum_value_eur = aluminum_total,
  aluminum_share_within_nonferrous = aluminum_share
)

print(result)

# ------------------------------------------------------------
# 7) Save clean parameter file
# ------------------------------------------------------------
write_csv(
  result,
  file.path(PROC_DIR, "comext_al_share_within_nonferrous_2014_sitc.csv")
)

cat("\nSaved file to data_processed/comext_al_share_within_nonferrous_2014_sitc.csv\n")

# ------------------------------------------------------------
# 8) Optional sanity print
# ------------------------------------------------------------
cat("\nSanity check:\n")
cat("Non-ferrous total (EUR):", format(nonferrous_total, big.mark=","), "\n")
cat("Aluminum total (EUR):   ", format(aluminum_total, big.mark=","), "\n")
cat("Aluminum share:         ", round(aluminum_share, 4), "\n")