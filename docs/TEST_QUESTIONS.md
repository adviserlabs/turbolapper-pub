# Test Question Canon

Canonical questions for validating the turbolapper NL→SQL pipeline.
Each question is paired with a reference SQL query that should produce the correct answer.

Questions are drawn from journalism, relocation research, academic regional economics,
and economic development practice. Grouped by theme.

---

## How to use

Run any question through the CLI:
```sh
uv run turbolapper ask "Which counties had the fastest GDP growth in 2022?"
```

Or compare the LLM's SQL against the reference SQL below to validate correctness.

**Best year for multi-source questions:** 2022 (BEA GDP + BEA income + IRS taxes all available).
**For migration questions:** 2023 (most recent complete year).

---

## 1. Growth & Performance

**Q1.1** Which 10 counties had the fastest GDP growth in 2022?
```sql
SELECT county_name, state_fips, ROUND(yoy_gdp_growth_pct, 1) AS gdp_growth_pct
FROM semantic.county_unified
WHERE year = 2022 AND yoy_gdp_growth_pct IS NOT NULL
ORDER BY yoy_gdp_growth_pct DESC
LIMIT 10
```

**Q1.2** Which counties have had shrinking economies (negative GDP growth) for 3+ years in a row?
```sql
WITH annual AS (
    SELECT fips, county_name, year,
           (yoy_gdp_growth_pct < 0) AS contracting
    FROM semantic.county_unified
    WHERE year BETWEEN 2019 AND 2022
),
streaks AS (
    SELECT fips, county_name,
           SUM(contracting::INT) AS years_contracting
    FROM annual
    GROUP BY fips, county_name
)
SELECT fips, county_name, years_contracting
FROM streaks
WHERE years_contracting >= 3
ORDER BY years_contracting DESC, county_name
```

**Q1.3** How does Travis County (Austin) GDP growth compare to the national median in 2022?
```sql
SELECT
    (SELECT yoy_gdp_growth_pct FROM semantic.county_unified WHERE fips='48453' AND year=2022) AS travis_growth,
    MEDIAN(yoy_gdp_growth_pct) AS national_median_growth
FROM semantic.county_unified
WHERE year = 2022 AND yoy_gdp_growth_pct IS NOT NULL
```

**Q1.4** Which counties grew faster in GDP than in population in 2022 (productivity-driven growth)?
```sql
SELECT fips, county_name, state_fips,
       ROUND(yoy_gdp_growth_pct, 1) AS gdp_growth,
       ROUND(yoy_pop_growth_pct, 1) AS pop_growth,
       ROUND(yoy_gdp_growth_pct - yoy_pop_growth_pct, 1) AS gdp_lead
FROM semantic.county_unified
WHERE year = 2022
  AND yoy_gdp_growth_pct IS NOT NULL
  AND yoy_pop_growth_pct IS NOT NULL
  AND yoy_gdp_growth_pct > yoy_pop_growth_pct + 5
ORDER BY gdp_lead DESC
LIMIT 20
```

**Q1.5** What is the 10-year GDP growth trend for Harris County (Houston)?
```sql
SELECT year, gdp_dollars, ROUND(yoy_gdp_growth_pct, 1) AS yoy_growth_pct
FROM semantic.county_unified
WHERE fips = '48201' AND year BETWEEN 2013 AND 2023
ORDER BY year
```

---

## 2. Income & Wages

**Q2.1** Which 10 counties have the highest per-capita income in 2022?
```sql
SELECT county_name, state_fips, ROUND(per_capita_income) AS per_capita_income
FROM semantic.county_unified
WHERE year = 2022 AND per_capita_income IS NOT NULL
ORDER BY per_capita_income DESC
LIMIT 10
```

**Q2.2** Which counties have below-national-median per-capita income AND positive GDP growth in 2022?
```sql
WITH medians AS (
    SELECT MEDIAN(per_capita_income) AS median_pci
    FROM semantic.county_unified WHERE year = 2022
)
SELECT u.county_name, u.state_fips,
       ROUND(u.per_capita_income) AS per_capita_income,
       ROUND(u.yoy_gdp_growth_pct, 1) AS gdp_growth_pct
FROM semantic.county_unified u, medians
WHERE u.year = 2022
  AND u.per_capita_income < medians.median_pci
  AND u.yoy_gdp_growth_pct > 5
ORDER BY u.yoy_gdp_growth_pct DESC
LIMIT 20
```

**Q2.3** How does average household income compare between Miami-Dade, FL and Travis County (Austin), TX?
```sql
SELECT fips, county_name,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       ROUND(agi_per_hh) AS agi_per_hh,
       ROUND(wages_per_hh) AS wages_per_hh,
       ROUND(wage_pct_of_agi, 1) AS wage_pct_of_agi
FROM semantic.county_hh
WHERE fips IN ('12086', '48453') AND year = 2022
ORDER BY personal_income_per_hh DESC
```

**Q2.4** Where did per-capita income decline in 2022?
```sql
SELECT county_name, state_fips,
       ROUND(per_capita_income) AS per_capita_income,
       ROUND(yoy_per_capita_income_growth_pct, 1) AS yoy_growth_pct
FROM semantic.county_unified
WHERE year = 2022 AND yoy_per_capita_income_growth_pct < 0
ORDER BY yoy_per_capita_income_growth_pct
LIMIT 20
```

**Q2.5** Which counties have the highest share of non-wage income (investment/business income)?
```sql
SELECT county_name, state_fips,
       ROUND(wage_pct_of_agi, 1) AS wage_pct_of_agi,
       ROUND(100 - wage_pct_of_agi, 1) AS non_wage_pct,
       ROUND(agi_per_hh) AS agi_per_hh
FROM semantic.county_hh
WHERE year = 2022 AND wage_pct_of_agi IS NOT NULL
ORDER BY wage_pct_of_agi ASC
LIMIT 15
```

**Q2.6** What is the per-household income for all counties in Colorado in 2022?
```sql
SELECT county_name,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       ROUND(agi_per_hh) AS agi_per_hh,
       ROUND(wages_per_hh) AS wages_per_hh,
       ROUND(hh_size_proxy, 2) AS avg_hh_size
FROM semantic.county_hh
WHERE state_fips = '08' AND year = 2022
ORDER BY personal_income_per_hh DESC
```

---

## 3. Migration & Population

**Q3.1** Which 10 counties had the highest net domestic in-migration in 2023?
```sql
SELECT county_name, state_fips, domestic_migration, net_migration
FROM semantic.county_migration
WHERE year = 2023
ORDER BY domestic_migration DESC
LIMIT 10
```

**Q3.2** Which counties are losing the most residents (domestic out-migration)?
```sql
SELECT county_name, state_fips, domestic_migration, net_migration
FROM semantic.county_migration
WHERE year = 2023
ORDER BY domestic_migration ASC
LIMIT 10
```

**Q3.3** Which high-income counties are also domestic migration magnets in 2022?
```sql
SELECT county_name, state_fips,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       domestic_migration
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_high_hh_income IS TRUE
  AND is_domestic_migration_magnet IS TRUE
ORDER BY domestic_migration DESC
LIMIT 15
```

**Q3.4** Which Sun Belt states are gaining the most domestic in-migration?
```sql
SELECT state_fips,
       SUM(domestic_migration) AS total_domestic_migration,
       SUM(net_migration) AS total_net_migration
FROM semantic.county_migration
WHERE year = 2023
  AND state_fips IN ('04','12','13','22','37','45','47','48','49','51')
GROUP BY state_fips
ORDER BY total_domestic_migration DESC
```

**Q3.5** Where is immigration (international) the primary driver of population growth?
```sql
SELECT county_name, state_fips, domestic_migration, international_migration, net_migration
FROM semantic.county_migration
WHERE year = 2023 AND is_immigration_driven_growth IS TRUE
ORDER BY international_migration DESC
LIMIT 20
```

**Q3.6** Which counties have declining population despite growing incomes?
```sql
SELECT county_name, state_fips,
       ROUND(yoy_per_capita_income_growth_pct, 1) AS income_growth_pct,
       ROUND(yoy_pop_growth_pct, 2) AS pop_growth_pct
FROM semantic.county_unified
WHERE year = 2022
  AND yoy_pop_growth_pct < 0
  AND yoy_per_capita_income_growth_pct > 3
ORDER BY income_growth_pct DESC
LIMIT 20
```

---

## 4. Relocation & Where-to-Live

**Q4.1** Which counties offer high incomes AND are gaining residents (desirable + in-demand)?
```sql
SELECT county_name, state_fips,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       domestic_migration
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_above_median_hh_income IS TRUE
  AND is_domestic_migration_positive IS TRUE
ORDER BY personal_income_per_hh DESC
LIMIT 20
```

**Q4.2** Which growing counties (boomtowns) have below-national-average household income (still affordable)?
```sql
SELECT county_name, state_fips,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       ROUND(yoy_gdp_growth_pct, 1) AS gdp_growth_pct
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_boomtown IS TRUE
  AND is_above_median_hh_income IS FALSE
ORDER BY yoy_gdp_growth_pct DESC
```

**Q4.3** Compare cost-of-living adjusted income: which region has the highest real purchasing power?
```sql
-- Note: BEA Regional Price Parities (RPP) not yet in warehouse — this is a known unknown.
-- Proxy: compare personal_income_per_hh across geographic regions.
SELECT state_fips,
       ROUND(AVG(personal_income_per_hh)) AS avg_hh_income,
       ROUND(AVG(gdp_per_hh)) AS avg_gdp_per_hh,
       COUNT(*) AS county_count
FROM semantic.county_hh
WHERE year = 2022 AND personal_income_per_hh IS NOT NULL
GROUP BY state_fips
ORDER BY avg_hh_income DESC
LIMIT 15
```

**Q4.4** Which counties in Texas are boomtowns?
```sql
SELECT county_name,
       ROUND(yoy_gdp_growth_pct, 1) AS gdp_growth_pct,
       ROUND(yoy_pop_growth_pct, 2) AS pop_growth_pct,
       ROUND(personal_income_per_hh) AS personal_income_per_hh
FROM semantic.county_all_flags
WHERE state_fips = '48' AND year = 2022 AND is_boomtown IS TRUE
ORDER BY gdp_growth_pct DESC
```

**Q4.5** Which counties have both high income AND strong in-migration (best of both)?
```sql
SELECT county_name, state_fips,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       domestic_migration,
       dominant_sector
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_high_hh_income IS TRUE
  AND is_domestic_migration_magnet IS TRUE
ORDER BY domestic_migration DESC
```

---

## 5. Industry & Sector

**Q5.1** Which counties are most dependent on a single industry (most concentrated)?
```sql
SELECT fips, county_name, state_fips, dominant_sector,
       GREATEST(
           COALESCE(pct_agriculture,0), COALESCE(pct_mining_energy,0),
           COALESCE(pct_manufacturing,0), COALESCE(pct_retail,0),
           COALESCE(pct_finance_realestate,0), COALESCE(pct_professional_services,0),
           COALESCE(pct_education_healthcare,0), COALESCE(pct_hospitality,0),
           COALESCE(pct_government,0)
       ) AS top_sector_pct
FROM semantic.county_all_flags
WHERE year = 2022 AND dominant_sector IS NOT NULL
ORDER BY top_sector_pct DESC
LIMIT 15
```

**Q5.2** Which counties are energy (oil/gas/mining) dominant?
```sql
SELECT county_name, state_fips, pct_mining_energy, dominant_sector,
       ROUND(gdp_per_hh) AS gdp_per_hh
FROM semantic.county_all_flags
WHERE year = 2022 AND is_energy_dominant IS TRUE
ORDER BY pct_mining_energy DESC
LIMIT 20
```

**Q5.3** How has manufacturing's share of GDP changed in the Rust Belt from 2005 to 2022?
```sql
SELECT year,
       ROUND(AVG(pct_manufacturing), 1) AS avg_manufacturing_pct,
       COUNT(*) AS county_count
FROM semantic.county_industry_flags
WHERE state_fips IN ('17','18','26','39','42','55')  -- IL, IN, MI, OH, PA, WI
  AND year IN (2005, 2010, 2015, 2019, 2022)
GROUP BY year
ORDER BY year
```

**Q5.4** Which counties are transitioning away from goods-producing industries (manufacturing + agriculture + energy declining)?
```sql
WITH sector_change AS (
    SELECT fips, county_name, state_fips,
           MAX(pct_manufacturing + pct_agriculture + pct_mining_energy)
               FILTER (WHERE year = 2012) AS goods_pct_2012,
           MAX(pct_manufacturing + pct_agriculture + pct_mining_energy)
               FILTER (WHERE year = 2022) AS goods_pct_2022
    FROM semantic.county_industry_flags
    WHERE year IN (2012, 2022)
    GROUP BY fips, county_name, state_fips
)
SELECT fips, county_name, state_fips,
       ROUND(goods_pct_2012, 1) AS goods_pct_2012,
       ROUND(goods_pct_2022, 1) AS goods_pct_2022,
       ROUND(goods_pct_2022 - goods_pct_2012, 1) AS change
FROM sector_change
WHERE goods_pct_2012 > 25 AND goods_pct_2022 IS NOT NULL
ORDER BY change ASC
LIMIT 20
```

**Q5.5** Which counties have "eds and meds" (education + healthcare) as dominant sector?
```sql
SELECT county_name, state_fips, pct_education_healthcare,
       ROUND(gdp_per_hh) AS gdp_per_hh,
       ROUND(per_capita_income) AS per_capita_income
FROM semantic.county_all_flags
WHERE year = 2022 AND is_eds_meds_economy IS TRUE
ORDER BY pct_education_healthcare DESC
LIMIT 20
```

**Q5.6** Which government-dominant counties have low per-capita income?
```sql
SELECT county_name, state_fips, pct_government,
       ROUND(per_capita_income) AS per_capita_income
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_government_dominant IS TRUE
  AND is_low_income IS TRUE
ORDER BY pct_government DESC
```

---

## 6. Economic Distress & Left-Behind Counties

**Q6.1** Which counties are "left behind" — declining GDP growth AND losing population?
```sql
SELECT f.county_name, f.state_fips,
       ROUND(u.yoy_gdp_growth_pct, 1) AS gdp_growth_pct,
       ROUND(u.yoy_pop_growth_pct, 2) AS pop_growth_pct,
       f.dominant_sector
FROM semantic.county_all_flags f
JOIN semantic.county_unified u ON u.fips = f.fips AND u.year = f.year
WHERE f.year = 2022 AND f.is_left_behind IS TRUE
ORDER BY u.yoy_gdp_growth_pct ASC
LIMIT 20
```

**Q6.2** Which left-behind counties were also boomtowns 10 years ago?
```sql
SELECT b.county_name, b.state_fips
FROM semantic.county_all_flags b
JOIN semantic.county_all_flags l ON l.fips = b.fips
WHERE b.year = 2012 AND b.is_boomtown IS TRUE
  AND l.year = 2022 AND l.is_left_behind IS TRUE
ORDER BY b.county_name
```

**Q6.3** Which states have the most economically distressed counties?
```sql
SELECT state_fips, COUNT(*) AS distressed_county_count
FROM semantic.county_all_flags
WHERE year = 2022 AND is_economically_distressed_proxy IS TRUE
GROUP BY state_fips
ORDER BY distressed_county_count DESC
LIMIT 15
```

**Q6.4** How many counties are shrinking (population declining AND income declining)?
```sql
SELECT year, COUNT(*) AS shrinking_county_count
FROM semantic.county_all_flags
WHERE year BETWEEN 2015 AND 2022 AND is_shrinking_and_declining IS TRUE
GROUP BY year
ORDER BY year
```

**Q6.5** Which energy-dominant counties face economic risk from transition away from fossil fuels?
```sql
SELECT county_name, state_fips, pct_mining_energy,
       ROUND(gdp_per_hh) AS gdp_per_hh,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       is_wage_economy
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_energy_dominant IS TRUE
ORDER BY pct_mining_energy DESC
LIMIT 20
```

---

## 7. Inequality & Economic Structure

**Q7.1** Which counties have the largest gap between GDP/HH and wages/HH (high capital income)?
```sql
SELECT county_name, state_fips,
       ROUND(gdp_per_hh) AS gdp_per_hh,
       ROUND(wages_per_hh) AS wages_per_hh,
       ROUND(gdp_per_hh - wages_per_hh) AS gap,
       dominant_sector
FROM semantic.county_all_flags
WHERE year = 2022 AND gdp_per_hh IS NOT NULL AND wages_per_hh IS NOT NULL
ORDER BY gap DESC
LIMIT 15
```

**Q7.2** Which counties have the highest AGI per household (reported taxable income)?
```sql
SELECT county_name, state_fips,
       ROUND(agi_per_hh) AS agi_per_hh,
       ROUND(wages_per_hh) AS wages_per_hh,
       ROUND(non_wage_income_per_hh) AS non_wage_income_per_hh
FROM semantic.county_hh
WHERE year = 2022 AND agi_per_hh IS NOT NULL
ORDER BY agi_per_hh DESC
LIMIT 10
```

**Q7.3** In commuter counties, how does per-capita income compare to GDP per capita?
```sql
SELECT county_name, state_fips,
       ROUND(per_capita_income) AS per_capita_income,
       ROUND(gdp_per_capita) AS gdp_per_capita,
       ROUND(per_capita_income / NULLIF(gdp_per_capita,0), 2) AS income_to_gdp_ratio
FROM semantic.county_unified
WHERE year = 2022
  AND fips IN (
      SELECT fips FROM semantic.county_all_flags WHERE year = 2022 AND is_commuter_county IS TRUE
  )
ORDER BY income_to_gdp_ratio DESC
LIMIT 20
```

**Q7.4** Which investment-economy counties (low wage share) have high per-household income?
```sql
SELECT county_name, state_fips,
       ROUND(wage_pct_of_agi, 1) AS wage_pct_of_agi,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       ROUND(agi_per_hh) AS agi_per_hh
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_investment_hh_county IS TRUE
  AND is_high_hh_income IS TRUE
ORDER BY personal_income_per_hh DESC
LIMIT 15
```

---

## 8. Tax Base & Fiscal

**Q8.1** Which counties had the fastest AGI growth in 2022 (strongest tax base expansion)?
```sql
SELECT county_name, state_fips,
       ROUND(yoy_agi_growth_pct, 1) AS agi_growth_pct,
       ROUND(avg_agi_per_return) AS avg_agi_per_return
FROM semantic.county_taxes
WHERE year = 2022 AND yoy_agi_growth_pct IS NOT NULL
ORDER BY yoy_agi_growth_pct DESC
LIMIT 10
```

**Q8.2** Where is personal income significantly higher than AGI (large transfer payment base)?
```sql
SELECT county_name, state_fips,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       ROUND(agi_per_hh) AS agi_per_hh,
       ROUND(personal_income_per_hh - agi_per_hh) AS transfer_gap_per_hh
FROM semantic.county_hh
WHERE year = 2022
  AND personal_income_per_hh IS NOT NULL
  AND agi_per_hh IS NOT NULL
  AND (personal_income_per_hh - agi_per_hh) > 20000
ORDER BY transfer_gap_per_hh DESC
LIMIT 20
```

**Q8.3** Which counties have very low tax-filer density (potential informal economy or retirees)?
```sql
SELECT county_name, state_fips,
       ROUND(num_returns / NULLIF(population, 0) * 100, 1) AS filer_pct_of_pop,
       ROUND(per_capita_income) AS per_capita_income
FROM semantic.county_unified
WHERE year = 2022 AND num_returns IS NOT NULL AND population IS NOT NULL
  AND is_low_filer_density IN (SELECT is_low_filer_density FROM semantic.county_all_flags WHERE year=2022 AND is_low_filer_density IS TRUE LIMIT 1)
ORDER BY num_returns / NULLIF(population, 0)
LIMIT 20
```

---

## 9. CPI & Prices

**Q9.1** What was the national inflation rate in 2023?
```sql
SELECT ROUND(AVG(yoy_inflation_pct), 2) AS avg_yoy_inflation_2023
FROM semantic.cpi_monthly
WHERE year = 2023 AND is_us_city_average AND is_headline_all_items
```

**Q9.2** Which metro areas had the highest food inflation in 2022?
```sql
SELECT area_name,
       ROUND(AVG(yoy_inflation_pct), 2) AS avg_food_inflation_2022
FROM semantic.cpi_monthly
WHERE year = 2022 AND is_food AND NOT is_us_city_average
GROUP BY area_name
ORDER BY avg_food_inflation_2022 DESC
LIMIT 10
```

**Q9.3** How has egg price inflation changed month-over-month in 2022-2023?
```sql
SELECT observation_month, area_name, price_usd,
       ROUND(yoy_price_change_pct, 1) AS yoy_change_pct
FROM semantic.avg_price_monthly
WHERE item_name ILIKE '%egg%' AND is_us_city_average
  AND year BETWEEN 2022 AND 2023
ORDER BY observation_month
```

**Q9.4** Compare energy inflation between major metros in 2022:
```sql
SELECT area_name,
       ROUND(AVG(yoy_inflation_pct), 2) AS avg_energy_inflation_2022
FROM semantic.cpi_monthly
WHERE year = 2022 AND is_energy
  AND area_name IN (
      'U.S. city average',
      'Los Angeles-Long Beach-Anaheim, CA',
      'New York-Newark-Jersey City, NY-NJ-PA',
      'Houston-The Woodlands-Sugar Land, TX',
      'Chicago-Naperville-Elgin, IL-IN-WI'
  )
GROUP BY area_name
ORDER BY avg_energy_inflation_2022 DESC
```

**Q9.5** What is the current price of regular gasoline nationally?
```sql
SELECT observation_month, price_usd
FROM semantic.avg_price_monthly
WHERE item_name ILIKE '%gasoline%' AND item_name ILIKE '%unleaded%' AND is_us_city_average
ORDER BY observation_month DESC
LIMIT 6
```

---

## 10. Composite / Multi-source

**Q10.1** Which counties are boomtowns with knowledge-economy industries?
```sql
SELECT county_name, state_fips, dominant_sector,
       ROUND(yoy_gdp_growth_pct, 1) AS gdp_growth,
       ROUND(personal_income_per_hh) AS personal_income_per_hh
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_boomtown IS TRUE
  AND (is_knowledge_economy IS TRUE OR dominant_sector = 'professional_services')
ORDER BY yoy_gdp_growth_pct DESC
```

**Q10.2** Which affluent counties are also domestic out-migration magnets — wealthy but people are leaving?
```sql
SELECT county_name, state_fips,
       ROUND(personal_income_per_hh) AS personal_income_per_hh,
       domestic_migration
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_affluent IS TRUE
  AND is_domestic_out_migration IS TRUE
ORDER BY domestic_migration ASC
```

**Q10.3** Where are "gateway" counties — attracting immigrants AND growing economically?
```sql
SELECT county_name, state_fips,
       international_migration,
       ROUND(yoy_gdp_growth_pct, 1) AS gdp_growth,
       ROUND(per_capita_income) AS per_capita_income
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_immigration_significant IS TRUE
  AND is_fast_gdp_growth IS TRUE
ORDER BY international_migration DESC
LIMIT 20
```

**Q10.4** Which low-income counties are catching up (high growth trajectory)?
```sql
SELECT county_name, state_fips,
       ROUND(per_capita_income) AS per_capita_income,
       ROUND(yoy_per_capita_income_growth_pct, 1) AS income_growth,
       ROUND(yoy_gdp_growth_pct, 1) AS gdp_growth,
       dominant_sector
FROM semantic.county_all_flags
WHERE year = 2022 AND is_low_income_high_growth IS TRUE
ORDER BY yoy_gdp_growth_pct DESC
LIMIT 20
```

**Q10.5** How many counties in each state are "left behind"?
```sql
SELECT state_fips,
       COUNT(*) FILTER (WHERE is_left_behind IS TRUE) AS left_behind_count,
       COUNT(*) FILTER (WHERE is_boomtown IS TRUE) AS boomtown_count,
       COUNT(*) AS total_counties
FROM semantic.county_all_flags
WHERE year = 2022
GROUP BY state_fips
HAVING COUNT(*) FILTER (WHERE is_left_behind IS TRUE) > 0
ORDER BY left_behind_count DESC
```

**Q10.6** Which counties have high GDP per household but low wages per household (capital-intensive economies)?
```sql
SELECT county_name, state_fips,
       ROUND(gdp_per_hh) AS gdp_per_hh,
       ROUND(wages_per_hh) AS wages_per_hh,
       ROUND(gdp_per_hh / NULLIF(wages_per_hh,0), 1) AS gdp_to_wage_ratio,
       dominant_sector
FROM semantic.county_all_flags
WHERE year = 2022
  AND is_high_capital_gdp_ratio IS TRUE
ORDER BY gdp_per_hh DESC
LIMIT 15
```

---

## 11. Historical trends

**Q11.1** Which counties were boomtowns in 2005 but are now left behind?
```sql
SELECT b.county_name, b.state_fips
FROM semantic.county_all_flags b
JOIN semantic.county_all_flags n ON n.fips = b.fips
WHERE b.year = 2005 AND b.is_boomtown IS TRUE
  AND n.year = 2022 AND n.is_left_behind IS TRUE
```

**Q11.2** How has the wage share of income changed in manufacturing counties since 2015?
```sql
SELECT year,
       ROUND(AVG(wage_pct_of_agi), 1) AS avg_wage_pct_of_agi
FROM semantic.county_all_flags
WHERE is_manufacturing_dominant IS TRUE
  AND year BETWEEN 2015 AND 2022
  AND wage_pct_of_agi IS NOT NULL
GROUP BY year
ORDER BY year
```

**Q11.3** How has the number of boomtown counties changed over time?
```sql
SELECT year,
       COUNT(*) FILTER (WHERE is_boomtown IS TRUE) AS boomtowns,
       COUNT(*) FILTER (WHERE is_left_behind IS TRUE) AS left_behind,
       COUNT(*) AS total_with_data
FROM semantic.county_all_flags
WHERE year BETWEEN 2005 AND 2022 AND has_gdp_data AND has_income_data
GROUP BY year
ORDER BY year
```

---

## Known limitations

These questions cannot be fully answered from current data (see `KNOWN_UNKNOWNS.md`):

- **Poverty rates** — needs Census SAIPE
- **Unemployment** — needs BLS LAUS
- **Rural/urban classification** — needs USDA RUCC
- **Cost of living** — needs BEA RPP (Regional Price Parities)
- **Housing affordability** — needs Census ACS or Zillow ZHVI
- **Education attainment** — needs Census ACS
- **Real income** (inflation-adjusted) — needs RPP to deflate county-specific prices
