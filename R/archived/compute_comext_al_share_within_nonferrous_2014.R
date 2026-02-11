library(tidyverse)

in_path  <- "data_raw/COMTEXTnon-ferrous2014.csv"
out_path <- "data_processed/comext_al_share_within_nonferrous_2014.csv"

comext <- read_csv(in_path, show_col_types = FALSE)

# Aggregate by product; exclude COMEXT "Total" row
by_prod <- comext %>%
  filter(product != "Total") %>%
  group_by(product) %>%
  summarise(value_eur = sum(OBS_VALUE, na.rm = TRUE), .groups = "drop")

al_val <- by_prod %>%
  filter(str_detect(product, "ALUMIN")) %>%
  pull(value_eur)

total_nf <- by_prod %>%
  summarise(v = sum(value_eur)) %>%
  pull(v)

shares_nf <- tibble(
  year = 2014,
  reporter = "EU27_2020",
  partner = "Extra-EU27",
  aluminum_value_eur = al_val,
  nonferrous_value_eur = total_nf,
  aluminum_share_within_nonferrous = al_val / total_nf
)

write_csv(shares_nf, out_path)

print(by_prod %>% arrange(desc(value_eur)))
print(shares_nf)
