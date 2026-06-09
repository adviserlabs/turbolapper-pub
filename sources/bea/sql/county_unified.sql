-- Unified county view: joins GDP, income, taxes, and population into one
-- wide row per (fips, year). The LLM queries this for cross-source questions.
-- Full outer join means a row appears if any source has data for that fips+year.

CREATE OR REPLACE VIEW semantic.county_unified AS
WITH gdp AS (
    SELECT fips, county_name, state_fips, year,
           gdp_thousands, gdp_dollars, gdp_per_capita,
           yoy_gdp_growth_pct, gdp_rank_in_year
    FROM semantic.county_gdp
    WHERE is_all_industry
),
personal_income AS (
    SELECT fips, year, value AS personal_income_thousands,
           yoy_growth_pct AS yoy_personal_income_growth_pct
    FROM semantic.county_income WHERE metric = 'personal_income'
),
per_capita AS (
    SELECT fips, year, value AS per_capita_income,
           yoy_growth_pct AS yoy_per_capita_income_growth_pct
    FROM semantic.county_income WHERE metric = 'per_capita_income'
),
bea_pop AS (
    SELECT fips, year, value AS bea_population
    FROM semantic.county_income WHERE metric = 'population'
),
all_fips_years AS (
    SELECT fips, year FROM gdp
    UNION SELECT fips, year FROM personal_income
    UNION SELECT fips, year FROM semantic.county_taxes
    UNION SELECT fips, year FROM semantic.county_population
)
SELECT
    f.fips,
    COALESCE(d.county_name, t.county_name, p.county_name)  AS county_name,
    COALESCE(d.state_fips,  t.state_fips,  p.state_fips)   AS state_fips,
    f.year,

    -- GDP (BEA CAGDP2)
    d.gdp_thousands,
    d.gdp_dollars,
    d.gdp_per_capita,
    d.yoy_gdp_growth_pct,
    d.gdp_rank_in_year,

    -- Personal income (BEA CAINC1)
    pi.personal_income_thousands,
    pi.yoy_personal_income_growth_pct,
    pc.per_capita_income,
    pc.yoy_per_capita_income_growth_pct,

    -- IRS AGI & wages (tax-year basis)
    t.agi_thousands,
    t.agi_dollars,
    t.avg_agi_per_return,
    t.yoy_agi_growth_pct,
    t.num_returns,
    t.wages_dollars,

    -- Population (Census PEP 2020-2024, BEA estimate before that)
    COALESCE(p.population, bp.bea_population)               AS population,
    p.yoy_pop_growth_pct,
    p.pop_rank_in_year

FROM all_fips_years f
LEFT JOIN gdp              d  ON d.fips  = f.fips AND d.year  = f.year
LEFT JOIN personal_income  pi ON pi.fips = f.fips AND pi.year = f.year
LEFT JOIN per_capita       pc ON pc.fips = f.fips AND pc.year = f.year
LEFT JOIN semantic.county_taxes      t  ON t.fips  = f.fips AND t.year  = f.year
LEFT JOIN semantic.county_population p  ON p.fips  = f.fips AND p.year  = f.year
LEFT JOIN bea_pop          bp ON bp.fips = f.fips AND bp.year = f.year;
