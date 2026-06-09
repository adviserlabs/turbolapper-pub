-- BEA county GDP semantic layer.
-- One row per (fips, year, industry). Headline metric: line_code=1 (all-industry total).
-- Adds per-capita GDP (joining BEA population from CAINC1 if available),
-- YoY growth, and rank within year.

CREATE OR REPLACE TABLE semantic.county_gdp AS
WITH base AS (
    SELECT
        g.fips,
        g.geo_name                                          AS county_name,
        g.region,
        g.line_code,
        COALESCE(g.naics_code, 'ALL')                       AS naics_code,
        TRIM(g.industry_name)                               AS industry_name,
        g.year,
        g.gdp_thousands,
        g.gdp_thousands * 1000.0                            AS gdp_dollars
    FROM curated.bea_county_gdp g
),
with_growth AS (
    SELECT
        *,
        LAG(gdp_thousands) OVER (
            PARTITION BY fips, line_code ORDER BY year
        )                                                   AS gdp_thousands_prior_year,
        CASE WHEN LAG(gdp_thousands) OVER (
                    PARTITION BY fips, line_code ORDER BY year
                  ) > 0
             THEN ROUND(
                (gdp_thousands / LAG(gdp_thousands) OVER (
                    PARTITION BY fips, line_code ORDER BY year) - 1) * 100, 2
             )
             ELSE NULL
        END                                                 AS yoy_gdp_growth_pct
    FROM base
),
with_rank AS (
    SELECT
        *,
        -- rank counties by nominal GDP, all-industry total only
        CASE WHEN line_code = 1
             THEN RANK() OVER (PARTITION BY year, line_code ORDER BY gdp_thousands DESC NULLS LAST)
             ELSE NULL
        END                                                 AS gdp_rank_in_year,
        COUNT(*) FILTER (WHERE line_code = 1) OVER (PARTITION BY year, line_code)
                                                            AS county_count_in_year
    FROM with_growth
)
SELECT
    r.fips,
    r.county_name,
    LEFT(r.fips, 2)                                         AS state_fips,
    r.region,
    r.line_code,
    r.naics_code,
    r.industry_name,
    r.year,
    r.gdp_thousands,
    r.gdp_dollars,
    r.yoy_gdp_growth_pct,
    r.gdp_rank_in_year,
    r.county_count_in_year,
    -- is_all_industry flag for easy filtering
    (r.line_code = 1)                                       AS is_all_industry,
    -- per-capita GDP if BEA population is available
    CASE WHEN p.population > 0
         THEN ROUND(r.gdp_dollars / p.population, 0)
         ELSE NULL
    END                                                     AS gdp_per_capita
FROM with_rank r
LEFT JOIN semantic.county_income p
       ON p.fips = r.fips AND p.year = r.year AND p.metric = 'population';
