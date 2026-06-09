-- BEA CAINC1 semantic layer.
-- Pivots the three metrics back into wide columns for easy querying,
-- then adds YoY growth and rank.

CREATE OR REPLACE TABLE semantic.county_income AS
WITH pivoted AS (
    SELECT
        fips,
        geo_name                                            AS county_name,
        LEFT(fips, 2)                                       AS state_fips,
        year,
        metric,
        value
    FROM curated.bea_county_income
),
-- keep tall format — consumers filter by metric
with_growth AS (
    SELECT
        fips,
        county_name,
        state_fips,
        year,
        metric,
        value,
        LAG(value) OVER (PARTITION BY fips, metric ORDER BY year) AS prior_year_value,
        CASE WHEN LAG(value) OVER (PARTITION BY fips, metric ORDER BY year) > 0
             THEN ROUND(
                (value / LAG(value) OVER (PARTITION BY fips, metric ORDER BY year) - 1) * 100, 2
             )
             ELSE NULL
        END                                                 AS yoy_growth_pct
    FROM pivoted
)
SELECT
    fips,
    county_name,
    state_fips,
    year,
    metric,
    value,
    yoy_growth_pct,
    -- convenience: rank within year+metric (only meaningful for income/per_capita)
    RANK() OVER (
        PARTITION BY year, metric
        ORDER BY value DESC NULLS LAST
    )                                                       AS rank_in_year,
    -- population convenience alias
    CASE WHEN metric = 'population' THEN value ELSE NULL END AS population,
    -- income convenience alias
    CASE WHEN metric = 'personal_income' THEN value * 1000 ELSE NULL END AS personal_income_dollars,
    CASE WHEN metric = 'per_capita_income' THEN value ELSE NULL END AS per_capita_income
FROM with_growth;
