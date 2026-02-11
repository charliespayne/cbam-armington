library(tidyverse)

# ---- Inputs/Outputs (relative to repo root) ----
raw_path <- "data_raw/EUAlStImports_2019_EU27_ExtraEU_HS72_HS76.csv"
out_path <- "data_processed/comext_hs72_hs76_shares_2019.csv"

# ---- Read Eurostat COMEXT extract ----
comext <- read_csv(raw_path, show_col_types = FALSE)

# ---- Filter to EU27 aggregate + Extra-EU imports in 2019 ----
comext_eu27 <- comext %>%
  filter(
    str_detect(reporter, "European Union - 27"),
    str_detect(partner, regex("Extra-EU", ignore_case = TRUE)),
    flow == "IMPORT",
    TIME_PERIOD == 2019
  )

# ---- Aggregate values by product ----
by_prod <- comext_eu27 %>%
  group_by(product) %>%
  summarise(value_eur = sum(OBS_VALUE, na.rm = TRUE), .groups = "drop")

# ---- Compute shares ----
steel_val <- by_prod %>% filter(product == "IRON AND STEEL") %>% pull(value_eur)
al_val    <- by_prod %>% filter(product == "ALUMINIUM AND ARTICLES THEREOF") %>% pull(value_eur)
total     <- steel_val + al_val

shares <- tibble(
  year = 2019,
  reporter = "EU27_2020",
  partner = "Extra-EU27",
  steel_value_eur = steel_val,
  aluminum_value_eur = al_val,
  steel_share = steel_val / total,
  aluminum_share = al_val / total
)

# ---- Write output ----
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
write_csv(shares, out_path)

# ---- Print for sanity check ----
print(by_prod)
print(shares)