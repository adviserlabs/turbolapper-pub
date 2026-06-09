-- IRS SOI county semantic layer.
-- Aggregate totals only (agi_stub=0). Adds per-return AGI, YoY growth, rank.

CREATE OR REPLACE TABLE semantic.county_taxes AS
WITH totals AS (
    -- allagi files have no stub-0 total row, sum across all bracket stubs
    SELECT
        tax_year                                            AS year,
        fips,
        MAX(county_name)                                    AS county_name,
        LEFT(fips, 2)                                       AS state_fips,
        SUM(num_returns)                                    AS num_returns,
        SUM(agi_thousands)                                  AS agi_thousands,
        SUM(agi_thousands) * 1000.0                         AS agi_dollars,
        SUM(wages_thousands)                                AS wages_thousands,
        SUM(wages_thousands) * 1000.0                       AS wages_dollars,
        CASE WHEN SUM(num_returns) > 0
             THEN ROUND((SUM(agi_thousands) * 1000.0) / SUM(num_returns), 0)
             ELSE NULL
        END                                                 AS avg_agi_per_return
    FROM curated.irs_county_soi
    GROUP BY tax_year, fips, LEFT(fips, 2)
),
with_growth AS (
    SELECT
        *,
        LAG(agi_thousands) OVER (PARTITION BY fips ORDER BY year) AS prior_agi_thousands,
        CASE WHEN LAG(agi_thousands) OVER (PARTITION BY fips ORDER BY year) > 0
             THEN ROUND(
                (agi_thousands / LAG(agi_thousands) OVER (PARTITION BY fips ORDER BY year) - 1) * 100, 2
             )
             ELSE NULL
        END                                                 AS yoy_agi_growth_pct,
        LAG(avg_agi_per_return) OVER (PARTITION BY fips ORDER BY year) AS prior_avg_agi,
        CASE WHEN LAG(avg_agi_per_return) OVER (PARTITION BY fips ORDER BY year) > 0
             THEN ROUND(
                (avg_agi_per_return / LAG(avg_agi_per_return) OVER (PARTITION BY fips ORDER BY year) - 1) * 100, 2
             )
             ELSE NULL
        END                                                 AS yoy_avg_agi_growth_pct
    FROM totals
)
SELECT
    fips,
    county_name,
    state_fips,
    year,
    num_returns,
    agi_thousands,
    agi_dollars,
    wages_thousands,
    wages_dollars,
    avg_agi_per_return,
    yoy_agi_growth_pct,
    yoy_avg_agi_growth_pct,
    RANK() OVER (PARTITION BY year ORDER BY avg_agi_per_return DESC NULLS LAST) AS avg_agi_rank_in_year
FROM with_growth;
