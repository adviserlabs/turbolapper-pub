-- Census PEP semantic layer. Adds YoY change and rank.

CREATE OR REPLACE TABLE semantic.county_population AS
WITH with_growth AS (
    SELECT
        fips,
        state_fips,
        state_name,
        county_name,
        year,
        population,
        LAG(population) OVER (PARTITION BY fips ORDER BY year)  AS prior_year_pop,
        population - LAG(population) OVER (PARTITION BY fips ORDER BY year)
                                                                AS pop_change,
        CASE WHEN LAG(population) OVER (PARTITION BY fips ORDER BY year) > 0
             THEN ROUND(
                (population::DOUBLE / LAG(population) OVER (PARTITION BY fips ORDER BY year) - 1) * 100, 2
             )
             ELSE NULL
        END                                                     AS yoy_pop_growth_pct
    FROM curated.census_county_pop
)
SELECT
    fips,
    state_fips,
    state_name,
    county_name,
    year,
    population,
    pop_change,
    yoy_pop_growth_pct,
    RANK() OVER (PARTITION BY year ORDER BY population DESC NULLS LAST) AS pop_rank_in_year
FROM with_growth;
