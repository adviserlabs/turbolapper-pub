# Turbolapper Schema Reference

The warehouse is a single DuckDB file at `data/turbolapper.duckdb`.
All queryable tables live in the `semantic` schema. Use `semantic.` prefix in every query.

---

## Quick orientation

| Table | What it answers | Years | Geo |
|---|---|---|---|
| `county_all_flags` | All flags + metrics in one row per county-year | 1969–2024 | 3,253 counties |
| `county_unified` | Raw cross-source numeric metrics per county-year | 1969–2024 | 3,253 counties |
| `county_hh` | Household-normalized income and productivity | 1969–2024 | 3,253 counties |
| `county_gdp` | GDP by industry (NAICS line codes) | 2001–2024 | 3,126 counties |
| `county_income` | BEA personal income, population, per-capita income | 1969–2024 | 3,148 counties |
| `county_taxes` | IRS AGI, wages, filings per county | 2015–2022 | 3,203 counties |
| `county_population` | Census population + YoY change | 2020–2024 | 3,143 counties |
| `county_migration` | Domestic + international migration flows | 2020–2024 | 3,143 counties |
| `county_flags` | Core boolean flags (size/income/structure/trend) | 1969–2024 | 3,253 counties |
| `county_industry_flags` | Industry-sector share + dominance flags | 2001–2024 | 3,126 counties |
| `cpi_monthly` | BLS Consumer Price Index by metro area + category | 1913–2026 | 57 metro/regional areas |
| `avg_price_monthly` | BLS average retail prices for specific goods | 1973–2026 | 57 metro/regional areas |

**Best table for most county questions:** `semantic.county_all_flags`
It joins all flag tables into one 96-column wide row per county-year. Use `county_unified` when you need the raw numeric values without flags.

**Join key:** All county tables join on `fips` (5-digit string, zero-padded, e.g. `'06037'`) and `year` (integer).

---

## Table: `semantic.county_all_flags`

One row per county per year. Contains every flag and metric from all sources.
**Use this for the vast majority of county questions.**

### Identity columns

| Column | Type | Description |
|---|---|---|
| `fips` | VARCHAR | 5-digit FIPS code (state 2 + county 3), zero-padded. E.g. `'06037'` = LA County. |
| `county_name` | VARCHAR | County name as reported by BEA. E.g. `'Los Angeles, CA'`. |
| `state_fips` | VARCHAR | 2-digit state FIPS. E.g. `'06'` = California. |
| `year` | INTEGER | Calendar year of observation. |

### Size flags

| Column | Definition | Threshold |
|---|---|---|
| `is_major_economic_hub` | Top 10% of counties by total GDP nationally | GDP ≥ 90th percentile within year |
| `is_large_economy` | Top 25% by total GDP | GDP ≥ 75th percentile |
| `is_small_economy` | Bottom 25% by total GDP | GDP < 25th percentile |
| `is_high_population` | Top 10% by population | pop ≥ 90th percentile |
| `is_low_population` | Bottom 25% by population | pop < 25th percentile |

### Income & wealth flags

| Column | Definition | Threshold |
|---|---|---|
| `is_above_median_income` | Per-capita income above national median | PCI ≥ 50th percentile |
| `is_high_income` | Top quartile per-capita income | PCI ≥ 75th percentile |
| `is_low_income` | Bottom quartile per-capita income | PCI < 25th percentile |
| `is_high_agi` | Top quartile average AGI per tax return | ≥ 75th percentile |
| `is_low_agi` | Bottom quartile average AGI per return | < 25th percentile |
| `is_affluent` | Both PCI and AGI in top quartile | dual confirmation of wealth |
| `is_economically_distressed_proxy` | Both PCI and GDP/capita in bottom quartile | proxy — no poverty data yet |
| `is_above_median_gdp_per_capita` | GDP/capita above national median | ≥ 50th percentile |

### Economic structure flags

| Column | Definition | Threshold |
|---|---|---|
| `is_wage_economy` | Wages are >67% of total AGI | working-class income base |
| `is_investment_economy` | Wages are <55% of AGI | significant capital/business income |
| `is_high_filer_density` | >48% of population files taxes | engaged workforce |
| `is_low_filer_density` | <41% of population files taxes | may indicate elderly/dependent pop |
| `is_high_productivity` | GDP per tax filer > $112,000 | economic output per worker |
| `is_commuter_county` | PCI/GDP-per-capita > 1.3 | residents earn more than local economy produces |
| `is_economic_hub_county` | GDP-per-capita/PCI > 1.5 | local economy outsizes residential income |

### Growth & trend flags

| Column | Definition | Threshold |
|---|---|---|
| `is_fast_gdp_growth` | Top quartile YoY GDP growth | ≥ 75th percentile |
| `is_slow_gdp_growth` | Bottom quartile YoY GDP growth | < 25th percentile |
| `is_gdp_contracting` | Absolute negative YoY GDP | growth < 0% |
| `is_income_growing` | Positive YoY per-capita income growth | growth > 0% |
| `is_income_declining` | Negative YoY per-capita income growth | growth < 0% |
| `is_fast_income_growth` | Top quartile YoY income growth | ≥ 75th percentile |
| `is_population_growing` | Positive YoY population change | change > 0 |
| `is_population_declining` | Negative YoY population change | change < 0 |
| `is_fast_population_growth` | Top quartile YoY population growth | ≥ 75th percentile |
| `is_rapid_population_loss` | Bottom decile YoY population growth | < 10th percentile |
| `is_agi_growing` | Positive YoY AGI growth | growth > 0% |

### Composite situation flags

| Column | Meaning |
|---|---|
| `is_boomtown` | Top quartile BOTH GDP growth AND population growth — expanding economy with in-migration |
| `is_left_behind` | Bottom quartile BOTH GDP growth AND population growth — stagnating and losing people |
| `is_shrinking_and_declining` | Both population AND per-capita income declining YoY |
| `is_growing_and_prospering` | Top quartile both population AND income growth |
| `is_wealthy_and_stagnant` | High income (top quartile) but below-median income growth — mature/saturated economy |
| `is_low_income_high_growth` | Bottom quartile income but top quartile growth — catching up |

### Industry sector flags

| Column | Definition | Threshold |
|---|---|---|
| `dominant_sector` | VARCHAR name of the largest GDP sector | one of: agriculture, mining_energy, manufacturing, retail, finance_realestate, professional_services, education_healthcare, hospitality, government |
| `pct_agriculture` | Agriculture share of total county GDP | 0–100 |
| `pct_mining_energy` | Mining/oil/gas share of GDP | 0–100 |
| `pct_manufacturing` | Manufacturing share of GDP | 0–100 |
| `pct_retail` | Retail trade share of GDP | 0–100 |
| `pct_finance_realestate` | Finance + real estate share of GDP | 0–100 |
| `pct_professional_services` | Professional/business services share | 0–100 |
| `pct_education_healthcare` | Education + healthcare share | 0–100 |
| `pct_hospitality` | Arts/entertainment/food services share | 0–100 |
| `pct_government` | Government + government enterprises share | 0–100 |
| `is_agriculture_dominant` | Agriculture > 25% of GDP | |
| `is_energy_dominant` | Mining/energy > 25% of GDP | |
| `is_manufacturing_dominant` | Manufacturing > 25% of GDP | |
| `is_government_dominant` | Government > 25% of GDP | |
| `is_finance_dominant` | Finance/real estate > 25% of GDP | |
| `is_knowledge_economy` | Professional services > 20% of GDP | |
| `is_tourism_economy` | Hospitality > 20% of GDP | |
| `is_eds_meds_economy` | Education/healthcare > 25% of GDP | "eds and meds" economy |
| `is_natural_resource_economy` | Agriculture OR energy each > 15% of GDP | |
| `is_goods_producing_economy` | Manufacturing, agriculture, or energy each > 15% | |
| `is_service_economy` | Professional services > 15% OR finance > 20% | |

### Migration flags (2020–2024 only)

| Column | Type | Definition |
|---|---|---|
| `net_migration` | BIGINT | Total net migration (domestic + international) |
| `domestic_migration` | BIGINT | Net domestic in-migration (negative = out-migration) |
| `international_migration` | BIGINT | Net international in-migration |
| `is_net_migration_positive` | BOOLEAN | More people arriving than leaving overall |
| `is_net_migration_negative` | BOOLEAN | Net population loss from migration |
| `is_domestic_migration_positive` | BOOLEAN | Net in-migration from within US |
| `is_domestic_out_migration` | BOOLEAN | Net out-migration to other US counties |
| `is_immigration_significant` | BOOLEAN | International migration > 100 persons/year |
| `is_immigration_driven_growth` | BOOLEAN | International migration exceeds domestic (immigration is primary growth driver) |
| `is_domestic_migration_magnet` | BOOLEAN | Top quartile domestic in-migration nationally |
| `is_domestic_exodus` | BOOLEAN | Bottom quartile domestic migration (strong out-migration) |

### Household-normalized metrics

All "per_hh" metrics use IRS `num_returns` as a household proxy (1 return ≈ 1 tax unit ≈ 1 household). This normalizes for population density — allows apples-to-apples comparison of rural vs urban counties for household-level decisions.

| Column | Type | Definition |
|---|---|---|
| `hh_size_proxy` | DOUBLE | Average persons per tax-filing unit (population / num_returns) |
| `num_hh_proxy` | DOUBLE | Estimated number of households (IRS filing units) |
| `personal_income_per_hh` | DOUBLE | BEA total personal income ÷ filing units (includes wages, investment, transfers) |
| `agi_per_hh` | DOUBLE | IRS AGI ÷ filing units (taxable income only, excludes transfers) |
| `wages_per_hh` | DOUBLE | Wage income ÷ filing units (labor income only) |
| `non_wage_income_per_hh` | DOUBLE | (AGI - wages) ÷ filing units (investment + business income) |
| `gdp_per_hh` | DOUBLE | Total county GDP ÷ filing units (local economic output per household) |
| `wage_pct_of_agi` | DOUBLE | Wages as % of AGI (0–100). High = wage-dependent. Low = investment/business income. |
| `per_capita_income` | DOUBLE | BEA per-capita income (for reference alongside HH metrics) |
| `personal_income_per_hh_rank` | DOUBLE | National percentile rank within year (0=lowest, 1=highest) |
| `agi_per_hh_rank` | DOUBLE | National percentile rank within year |
| `wages_per_hh_rank` | DOUBLE | National percentile rank within year |
| `gdp_per_hh_rank` | DOUBLE | National percentile rank within year |
| `is_high_hh_income` | BOOLEAN | Top quartile personal income per HH nationally |
| `is_low_hh_income` | BOOLEAN | Bottom quartile personal income per HH |
| `is_above_median_hh_income` | BOOLEAN | Above-median HH income nationally |
| `is_high_capital_gdp_ratio` | BOOLEAN | GDP/HH is > 2.5× wages/HH (high capital or business income relative to labor) |
| `is_large_hh_county` | BOOLEAN | Above-median household size (larger families) |
| `is_small_hh_county` | BOOLEAN | Bottom quartile household size (retirees, singles, urban) |
| `is_wage_dependent_hh` | BOOLEAN | Wages > 80% of AGI (income is almost entirely labor) |
| `is_investment_hh_county` | BOOLEAN | Wages < 55% of AGI (significant investment/business/retirement income) |

### Data availability flags

| Column | Meaning |
|---|---|
| `has_gdp_data` | BEA CAGDP2 GDP data available for this county-year |
| `has_income_data` | BEA CAINC1 income data available |
| `has_tax_data` | IRS SOI data available (2015–2022 only) |
| `has_population_data` | Census PEP population data available (2020–2024 only) |

---

## Table: `semantic.county_unified`

Cross-source numeric metrics per county-year. No flags — just the raw numbers.
Useful when you want to write your own thresholds or aggregations.

| Column | Type | Definition |
|---|---|---|
| `fips` | VARCHAR | 5-digit county FIPS |
| `county_name` | VARCHAR | County name |
| `state_fips` | VARCHAR | 2-digit state FIPS |
| `year` | INTEGER | Calendar year |
| `gdp_thousands` | DOUBLE | Total GDP in thousands of dollars |
| `gdp_dollars` | DOUBLE | Total GDP in dollars |
| `gdp_per_capita` | DOUBLE | GDP ÷ BEA population |
| `yoy_gdp_growth_pct` | DOUBLE | YoY % change in total GDP |
| `gdp_rank_in_year` | BIGINT | National rank by GDP within year (1 = largest) |
| `personal_income_thousands` | DOUBLE | BEA personal income in thousands |
| `yoy_personal_income_growth_pct` | DOUBLE | YoY % change in total personal income |
| `per_capita_income` | DOUBLE | BEA per-capita personal income |
| `yoy_per_capita_income_growth_pct` | DOUBLE | YoY % change in per-capita income |
| `agi_thousands` | DOUBLE | IRS total AGI in thousands |
| `agi_dollars` | DOUBLE | IRS total AGI in dollars |
| `avg_agi_per_return` | DOUBLE | Average AGI per tax return |
| `yoy_agi_growth_pct` | DOUBLE | YoY % change in total AGI |
| `num_returns` | DOUBLE | Number of IRS tax returns filed (household proxy) |
| `wages_dollars` | DOUBLE | Total wage income reported on returns |
| `population` | DOUBLE | BEA-derived population estimate |
| `yoy_pop_growth_pct` | DOUBLE | YoY % population change |
| `pop_rank_in_year` | BIGINT | National rank by population within year |

---

## Table: `semantic.county_gdp`

GDP by NAICS industry line code per county per year (BEA CAGDP2).
Use this when you need sector-level GDP (e.g., "what share of Midland TX GDP is oil?").

| Column | Type | Definition |
|---|---|---|
| `fips` | VARCHAR | 5-digit county FIPS |
| `county_name` | VARCHAR | County name |
| `state_fips` | VARCHAR | 2-digit state FIPS |
| `region` | VARCHAR | BEA region name |
| `line_code` | INTEGER | BEA industry line code (see line codes below) |
| `naics_code` | VARCHAR | NAICS code string |
| `industry_name` | VARCHAR | Industry name |
| `year` | INTEGER | Calendar year (2001–2024) |
| `gdp_thousands` | DOUBLE | GDP in thousands of dollars |
| `gdp_dollars` | DOUBLE | GDP in dollars |
| `yoy_gdp_growth_pct` | DOUBLE | YoY % change |
| `gdp_rank_in_year` | BIGINT | National rank for this industry within year |
| `county_count_in_year` | BIGINT | Total counties with data this year |
| `is_all_industry` | BOOLEAN | True when line_code = 1 (total GDP row) |
| `gdp_per_capita` | DOUBLE | GDP ÷ BEA population (only set when is_all_industry) |

**Industry line codes (major groupings):**

| line_code | Industry |
|---|---|
| 1 | All industry total |
| 2 | Private industries total |
| 3 | Agriculture, forestry, fishing and hunting |
| 6 | Mining, quarrying, and oil and gas extraction |
| 10 | Utilities |
| 11 | Construction |
| 12 | Manufacturing |
| 13 | Durable goods manufacturing |
| 25 | Nondurable goods manufacturing |
| 34 | Wholesale trade |
| 35 | Retail trade |
| 36 | Transportation and warehousing |
| 45 | Information |
| 50 | Finance, insurance, real estate, rental, and leasing |
| 59 | Professional and business services |
| 68 | Educational services, health care, and social assistance |
| 75 | Arts, entertainment, recreation, accommodation, and food services |
| 82 | Other services (except government) |
| 83 | Government and government enterprises |

---

## Table: `semantic.county_income`

BEA CAINC1 personal income, population, and per-capita income in tall format.
Each county-year has 3 rows, one per metric.

| Column | Type | Definition |
|---|---|---|
| `fips` | VARCHAR | 5-digit county FIPS |
| `county_name` | VARCHAR | County name |
| `state_fips` | VARCHAR | 2-digit state FIPS |
| `year` | INTEGER | Calendar year (1969–2024) |
| `metric` | VARCHAR | One of: `personal_income`, `population`, `per_capita_income` |
| `value` | DOUBLE | Value in native units (dollars, persons, or dollars/person) |
| `yoy_growth_pct` | DOUBLE | YoY % change |
| `rank_in_year` | BIGINT | National rank within metric+year |
| `population` | DOUBLE | Convenience copy of population value (all rows) |
| `personal_income_dollars` | DOUBLE | Convenience copy of personal income (all rows) |
| `per_capita_income` | DOUBLE | Convenience copy of per-capita income (all rows) |

---

## Table: `semantic.county_taxes`

IRS Statistics of Income county-level AGI and wage data (2015–2022).

| Column | Type | Definition |
|---|---|---|
| `fips` | VARCHAR | 5-digit county FIPS |
| `county_name` | VARCHAR | County name |
| `state_fips` | VARCHAR | 2-digit state FIPS |
| `year` | INTEGER | Tax year (2015–2022) |
| `num_returns` | DOUBLE | Number of individual tax returns filed |
| `agi_thousands` | DOUBLE | Total adjusted gross income in thousands |
| `agi_dollars` | DOUBLE | Total AGI in dollars |
| `wages_thousands` | DOUBLE | Total wage/salary income in thousands |
| `wages_dollars` | DOUBLE | Total wages in dollars |
| `avg_agi_per_return` | DOUBLE | Average AGI per filing unit |
| `yoy_agi_growth_pct` | DOUBLE | YoY % change in total AGI |
| `yoy_avg_agi_growth_pct` | DOUBLE | YoY % change in average AGI per return |
| `avg_agi_rank_in_year` | BIGINT | National rank by avg AGI within year |

---

## Table: `semantic.county_population`

Census Population Estimates Program (PEP) county population (2020–2024).

| Column | Type | Definition |
|---|---|---|
| `fips` | VARCHAR | 5-digit county FIPS |
| `state_fips` | VARCHAR | 2-digit state FIPS |
| `state_name` | VARCHAR | Full state name |
| `county_name` | VARCHAR | County name |
| `year` | INTEGER | Calendar year (2020–2024) |
| `population` | BIGINT | Total population estimate |
| `pop_change` | BIGINT | Absolute population change from prior year |
| `yoy_pop_growth_pct` | DOUBLE | YoY % population change |
| `pop_rank_in_year` | BIGINT | National rank by population within year |

---

## Table: `semantic.county_migration`

Net domestic and international migration by county (Census PEP, 2020–2024).

| Column | Type | Definition |
|---|---|---|
| `fips` | VARCHAR | 5-digit county FIPS |
| `state_fips` | VARCHAR | 2-digit state FIPS |
| `state_name` | VARCHAR | Full state name |
| `county_name` | VARCHAR | County name |
| `year` | INTEGER | Calendar year (2020–2024) |
| `domestic_migration` | BIGINT | Net domestic migration (positive = in-migration from other US counties) |
| `international_migration` | BIGINT | Net international migration (positive = arrivals from abroad) |
| `net_migration` | BIGINT | domestic + international total |
| `is_net_migration_positive` | BOOLEAN | Net arrivals > 0 |
| `is_net_migration_negative` | BOOLEAN | Net departures > 0 |
| `is_domestic_migration_positive` | BOOLEAN | More domestic arrivals than departures |
| `is_domestic_out_migration` | BOOLEAN | Net domestic out-migration |
| `is_immigration_significant` | BOOLEAN | International arrivals > 100 per year |
| `is_immigration_driven_growth` | BOOLEAN | International > domestic contribution to net migration |
| `is_domestic_migration_magnet` | BOOLEAN | Top quartile domestic in-migration nationally |
| `is_domestic_exodus` | BOOLEAN | Bottom quartile domestic migration |

---

## Table: `semantic.county_hh`

Household-normalized metrics. Divides income/GDP by IRS filing units as a household proxy.
Use this when comparing counties of different sizes or densities for HH-level decisions.

(Full column list: see the `county_all_flags` household section above.)

---

## Table: `semantic.county_industry_flags`

Industry sector shares + dominance flags (BEA CAGDP2, 2001–2024).
Derives from `county_gdp` using line codes 3, 6, 12, 35, 50, 59, 68, 75, 83.

(Full column list: see the `county_all_flags` industry section above.)

---

## Table: `semantic.cpi_monthly`

BLS Consumer Price Index monthly observations.

| Column | Type | Definition |
|---|---|---|
| `observation_month` | DATE | First day of the month |
| `year` | INTEGER | Calendar year (1913–2026) |
| `month_name` | VARCHAR | Full month name |
| `series_id` | VARCHAR | BLS series identifier |
| `item_name` | VARCHAR | CPI category name (e.g., "All items") |
| `item_code` | VARCHAR | BLS item code |
| `item_category` | VARCHAR | Broad category: All items / aggregate, Food & beverages, Housing, Apparel, Transportation, Medical care, Recreation, Education & communication, Energy, Other goods & services |
| `area_name` | VARCHAR | Geography name (see geo catalog) |
| `area_code` | VARCHAR | BLS area code |
| `is_us_city_average` | BOOLEAN | True when area is the national U.S. city average |
| `seasonally_adjusted` | BOOLEAN | Whether series is seasonally adjusted |
| `index_value` | DOUBLE | CPI index value (base period varies by series) |
| `index_base_period` | VARCHAR | The base period for the index (e.g., "1982-84=100") |
| `mom_change_pct` | DOUBLE | Month-over-month % change |
| `yoy_inflation_pct` | DOUBLE | Year-over-year % change (inflation rate) |
| `change_vs_12mo_ago_index_pts` | DOUBLE | Absolute index point change vs 12 months prior |
| `is_headline_all_items` | BOOLEAN | True for the main all-items CPI series |
| `is_food` | BOOLEAN | True for food-related categories |
| `is_energy` | BOOLEAN | True for energy-related categories |
| `footnote_codes` | VARCHAR | BLS footnote code(s) |
| `footnote_text` | VARCHAR | Footnote description |

---

## Table: `semantic.avg_price_monthly`

BLS average retail prices for specific consumer goods (gasoline, milk, eggs, bread, meats, etc.).

| Column | Type | Definition |
|---|---|---|
| `observation_month` | DATE | First day of the month |
| `year` | INTEGER | Calendar year (1973–2026) |
| `month_name` | VARCHAR | Full month name |
| `series_id` | VARCHAR | BLS series identifier |
| `item_name` | VARCHAR | Product name and unit (e.g., "Eggs, grade A, large, per doz.") |
| `item_code` | VARCHAR | BLS item code |
| `unit` | VARCHAR | Unit of measure |
| `area_name` | VARCHAR | Geography name |
| `area_code` | VARCHAR | BLS area code |
| `is_us_city_average` | BOOLEAN | True when national average |
| `price_usd` | DOUBLE | Average retail price in USD |
| `mom_change_pct` | DOUBLE | Month-over-month % price change |
| `yoy_price_change_pct` | DOUBLE | Year-over-year % price change |
| `footnote_codes` | VARCHAR | BLS footnote codes |
| `footnote_text` | VARCHAR | Footnote description |

---

## Flag logic reference

### NULL convention
All boolean flags are `NULL` (not false) when the underlying data is unavailable.
Always use `IS TRUE` or `IS NOT FALSE` rather than `= TRUE` when filtering flags.

```sql
-- Correct: excludes rows with NULL flags
WHERE is_boomtown IS TRUE

-- Incorrect: misses NULL rows
WHERE is_boomtown = TRUE
```

### Percentile rank flags
Relative flags (top/bottom quartile, etc.) use `PERCENT_RANK() OVER (PARTITION BY year)`.
This means thresholds shift each year — a county in the "top quartile" for 2010 is top quartile *relative to all 2010 counties*, not a fixed dollar threshold. This makes cross-year comparisons meaningful.

### "Per HH" vs "per capita"
- `per_capita_income` — BEA personal income ÷ BEA population (everyone, including children)
- `personal_income_per_hh` — BEA personal income ÷ IRS filing units (adult tax units)
- Use per-HH metrics for household budget decisions; per-capita for aggregate comparisons.

---

## Data sources

| Source | Dataset | Coverage |
|---|---|---|
| BEA | CAGDP2 — GDP by county and industry | 2001–2024, 3,126 counties |
| BEA | CAINC1 — Personal income, population, per-capita income | 1969–2024, 3,148 counties |
| IRS | Statistics of Income — county AGI and wages | 2015–2022, 3,203 counties |
| Census | Population Estimates Program (PEP) — population + migration | 2020–2024, 3,143 counties |
| BLS | Consumer Price Index (CPI) | 1913–2026, 57 metro/regional areas |
| BLS | Average Retail Prices | 1973–2026, 57 metro/regional areas |
