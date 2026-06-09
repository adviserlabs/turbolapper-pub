# Known Unknowns — County Dataset

Flags and questions we can't answer yet, and what data would unlock them.
Organized by theme. Each entry notes: the flag or question, the source needed,
and the estimated difficulty to add.

---

## 1. Poverty & Hardship

**What we want to answer:**
- Is this county below the poverty line?
- What share of residents receive food stamps / SNAP?
- What fraction of children are in poverty?
- Is this a persistently poor county (20%+ poverty for 30+ years)?

**Flags needed:**
- `is_below_poverty_line` — % population below federal poverty level
- `is_persistent_poverty` — USDA ERS definition: 20%+ poverty rate in 1980, 1990, 2000, and 2010 Census
- `is_high_child_poverty`
- `is_snap_dependent` — SNAP participation rate

**Data source:** Census Bureau SAIPE (Small Area Income and Poverty Estimates)
- URL: `https://www.census.gov/programs-surveys/saipe/data/datasets.html`
- Annual county-level poverty rates, 1989–present
- Format: CSV by year, ~3,200 rows
- **Difficulty: Low** — same flat-file pattern as Census PEP

**Data source:** USDA ERS Persistent Poverty Counties list
- URL: `https://www.ers.usda.gov/data-products/county-level-data-sets/`
- A static reference table (one row per persistent-poverty county)
- **Difficulty: Very Low** — single reference CSV

---

## 2. Rural / Urban Classification

**What we want to answer:**
- Is this a rural county?
- Is this metro, micropolitan, or noncore?
- Is this a frontier county (very low population density)?

**Flags needed:**
- `is_rural` — USDA Rural-Urban Continuum Code (Beale Code) 4–9
- `is_metro` — RUCC 1–3
- `is_frontier` — fewer than 6 people per square mile
- `is_noncore_rural` — RUCC 7–9 (most rural)

**Data source:** USDA ERS Rural-Urban Continuum Codes (2023)
- URL: `https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/`
- One row per county, updated after each Census
- **Difficulty: Very Low** — single reference CSV

**Data source:** Land area (sq miles) for density calculation
- From Census TIGER/Line or the PEP file (already downloaded, has AREALAND)
- **Difficulty: Very Low** — column already in raw Census data

---

## 3. Unemployment & Labor Market

**What we want to answer:**
- What is the unemployment rate in this county?
- Is unemployment above the national average?
- Has unemployment been persistently high?

**Flags needed:**
- `is_high_unemployment` — above national average
- `is_low_unemployment` — below national average
- `unemployment_rate` — raw value

**Data source:** BLS Local Area Unemployment Statistics (LAUS)
- URL: `https://download.bls.gov/pub/time.series/la/`
- Already in the BLS time.series format — **fits the existing BLSTimeSeries connector with zero code changes**
- Survey code: `la`
- **Difficulty: Very Low** — just add to surveys.py + two SQL files

---

## 4. Opportunity Zones & Federal Designations

**What we want to answer:**
- Is this county in a federal Opportunity Zone?
- Is it a HUD-designated Qualified Census Tract?
- Is it an EDA-designated distressed community?

**Flags needed:**
- `is_opportunity_zone` — Treasury/IRS designation
- `is_eda_distressed` — Economic Development Administration formal definition
- `is_medically_underserved` — HRSA designation
- `is_promise_zone` — HUD/USDA

**Data source:** IRS Opportunity Zone list
- URL: `https://www.cdfifund.gov/sites/cdfi/files/2018-06/OZ_Eligible_Census_Tracts_20180614.xlsx`
- Census-tract level; needs crosswalk to county FIPS
- **Difficulty: Medium** — tract → county aggregation

**Data source:** EDA Distressed Communities Index
- URL: `https://eig.org/distressed-communities/` (Economic Innovation Group, not EDA itself)
- County-level composite score
- **Difficulty: Low** — CSV download

---

## 5. Education

**What we want to answer:**
- What share of adults have a college degree?
- Is this a low-education county?
- Is educational attainment improving?

**Flags needed:**
- `is_low_education` — below national median bachelor's degree attainment
- `is_high_education` — top quartile bachelor's degree attainment
- `pct_bachelors_or_higher`

**Data source:** Census ACS 5-Year, Table B15003
- Already partially planned (we have ACS in the Census connector plan)
- **Difficulty: Low** — extend existing census source

---

## 6. Housing

**What we want to answer:**
- Is housing affordable in this county?
- Is this a housing-cost-burdened county?
- What is the homeownership rate?
- Is this a high-rent county?

**Flags needed:**
- `is_housing_cost_burdened` — >30% of residents spending >30% income on housing
- `is_high_homeownership`
- `median_home_value`
- `median_gross_rent`

**Data source:** Census ACS 5-Year, Tables B25070, B25003, B25077
- **Difficulty: Low** — same ACS connector

**Data source:** Zillow ZHVI (Home Value Index) — county level
- URL: `https://www.zillow.com/research/data/`
- Monthly county-level median home values, 1996–present
- **Difficulty: Low** — CSV download, same Source pattern

---

## 7. Healthcare & Demographics

**What we want to answer:**
- What is the median age in this county?
- Is this an aging county (high elderly share)?
- What is the uninsured rate?
- Is this a health-outcome distressed county?

**Flags needed:**
- `is_aging_county` — above national median share of 65+ population
- `is_high_uninsured`
- `median_age`

**Data source:** Census ACS 5-Year, Table B01002 (median age), B27001 (insurance)
- **Difficulty: Low**

**Data source:** CDC Places / County Health Rankings
- URL: `https://www.countyhealthrankings.org/`
- Annual county health outcome composite scores
- **Difficulty: Low** — CSV by year

---

## 8. Industry Concentration

**What we want to answer:**
- What is the dominant industry in this county?
- Is this an agricultural, manufacturing, energy, or service economy?
- Is this a government-dependent economy?

**Flags needed:**
- `is_agriculture_dominant`
- `is_manufacturing_dominant`
- `is_energy_dominant` (mining/oil/gas)
- `is_government_dominant`
- `is_service_dominant`
- `dominant_naics_sector`

**Data source:** Already in warehouse — BEA CAGDP2 has GDP by NAICS industry.
We have the data; we need the flag SQL.
- **Difficulty: Very Low** — compute from `semantic.county_gdp` where `line_code IN (3,6,23,61,...)` 
- This is **the highest-priority addition** since the data exists today.

---

## 9. Tax Base & Fiscal Health

**What we want to answer:**
- Is this county's tax base growing or shrinking?
- What share of income comes from capital gains vs. wages?
- Is this a retiree-income county (high transfer payments)?

**Flags needed:**
- `is_tax_base_growing`
- `is_capital_gains_economy` — high non-wage, non-transfer income (inferred from low wage share + high AGI)
- `is_transfer_dependent` — high income but low AGI relative to BEA personal income (transfer payments not in AGI)

**Data source:** IRS SOI already has AGI and wages.
BEA CAINC4 (personal income by source, including transfers) would complete the picture.
- **Difficulty: Low** for transfer flag — add CAINC4 download to BEA income source

---

## 10. Market Basket & Cost of Living

**What we want to answer:**
- Is this county affordable to live in?
- What does a market basket of goods cost here?
- Is cost of living above or below the national average?

**Flags needed:**
- `is_above_national_cost_of_living`
- `is_below_national_cost_of_living`
- `cost_of_living_index`

**Data source:** BEA Regional Price Parities (RPP)
- URL: `https://apps.bea.gov/regional/zip/RPP.zip`
- Annual county-level price parity indices, 2008–present
- **Difficulty: Low** — same BEA bulk ZIP pattern

**Note:** This would also power `is_part_of_market_basket`, connecting to
the BLS Average Prices data already in the warehouse.

---

## 11. Migration & Demographics

**What we want to answer:**
- Is this county gaining or losing residents to other states?
- What is the net domestic migration?
- Is immigration a driver of population growth?

**Flags needed:**
- `is_net_domestic_migration_positive`
- `is_immigration_driven_growth`
- `net_domestic_migration`

**Data source:** Census PEP — already downloaded, has DOMESTICMIG and INTERNATIONALMIG columns.
- **Difficulty: Very Low** — already in `raw.census_pep`, just not in curated/semantic yet.

---

## Priority Queue (next to build)

| Priority | Flag / Feature | Source | Difficulty | Unlocks |
|---|---|---|---|---|
| 1 | Industry dominance flags | BEA CAGDP2 (already have) | Very Low | "is this an ag/energy/mfg county?" |
| 2 | Migration flags | Census PEP (already have) | Very Low | "is this county gaining residents?" |
| 3 | Poverty rate | Census SAIPE | Low | `is_below_poverty_line` |
| 4 | Rural/urban code | USDA RUCC | Very Low | `is_rural`, `is_metro` |
| 5 | BLS LAUS unemployment | BLS (fits existing connector) | Very Low | `is_high_unemployment` |
| 6 | Education attainment | Census ACS | Low | `is_low_education` |
| 7 | Cost of living index | BEA RPP | Low | `is_above_national_cost_of_living` |
| 8 | Housing affordability | Census ACS / Zillow | Low | `is_housing_cost_burdened` |
| 9 | Persistent poverty | USDA ERS reference | Very Low | `is_persistent_poverty` |
| 10 | Health outcomes | CDC / County Health Rankings | Low | `is_health_distressed` |

---

## Common Questions from News Coverage (research backlog)

Questions frequently asked in economic journalism that our flags should eventually answer:

**Economic mobility & inequality**
- Which counties have the highest income mobility? (Needs Opportunity Atlas / Chetty data)
- Where is the middle class shrinking fastest?
- Which counties have the widest rich-poor gap?

**Geographic divergence**
- Which counties are being "left behind" by the knowledge economy?
- Where is the rural-urban income gap widening?
- Which small towns are bucking the trend and growing?

**Energy & commodity cycles**
- Which counties boom and bust with oil prices?
- Where is the coal economy still dominant?
- Which counties benefit from the clean energy transition?

**Migration & demographics**
- Which Sun Belt counties are growing fastest?
- Which Rust Belt counties are losing population?
- Where are retirees moving?
- Which counties have the highest foreign-born population share?

**Housing & affordability**
- Which counties are unaffordable even for high earners?
- Where is the housing shortage worst?
- Which counties have seen the fastest rent increases?

**Government dependency**
- Which counties rely most on federal transfer payments?
- Where would a Social Security cut hurt most?
- Which counties have the highest share of government employment?

**Innovation & productivity**
- Which counties have the highest GDP per worker?
- Where are high-tech industries concentrating?
- Which mid-size metros are emerging as tech hubs?

---

*Last updated: 2026-06-09. Add new questions as they come from news analysis.*
