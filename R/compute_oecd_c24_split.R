library(tidyverse)

# OECD ICIO 2014: split basic metals into
#   C24A = basic iron & steel
#   C24B = basic precious & other non-ferrous metals
#
# Source file: data_raw/2014_OECDIO.csv  (not tracked in git)
# Output file: data_processed/oecd_c24A_c24B_output_shares_2014.csv (tracked)

in_path  <- "data_raw/2014_OECDIO.csv"
out_path <- "data_processed/oecd_c24A_c24B_output_shares_2014.csv"

oecd <- read_csv(in_path, show_col_types = FALSE)

# Extract gross output row (OECD provides it explicitly as "OUT")
out_row <- oecd %>%
  filter(V1 == "OUT")

# Pivot to long, keep only standard country_industry columns like "USA_C24A"
out_long <- out_row %>%
  pivot_longer(
    cols = -V1,
    names_to = "country_industry",
    values_to = "gross_output"
  ) %>%
  filter(str_detect(country_industry, "^[A-Z]{3}_"))

# Split into country and industry (industry codes may contain underscores)
out_long2 <- out_long %>%
  separate(
    country_industry,
    into = c("country", "industry"),
    sep = "_",
    extra = "merge"
  )

# Compute C24A/C24B shares by country
c24_shares <- out_long2 %>%
  filter(industry %in% c("C24A", "C24B")) %>%
  group_by(country) %>%
  summarise(
    out_c24a = sum(gross_output[industry == "C24A"], na.rm = TRUE),
    out_c24b = sum(gross_output[industry == "C24B"], na.rm = TRUE),
    out_c24  = out_c24a + out_c24b,
    share_steel = out_c24a / out_c24,
    share_nonferrous = out_c24b / out_c24,
    .groups = "drop"
  ) %>%
  mutate(year = 2014) %>%
  select(year, country, out_c24a, out_c24b, out_c24, share_steel, share_nonferrous)

write_csv(c24_shares, out_path)

# Sanity check print
print(c24_shares %>% filter(country %in% c("USA","CHN","TUR","IND","DEU","ROW")))
