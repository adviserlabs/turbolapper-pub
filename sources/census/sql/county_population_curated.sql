-- Census PEP curated: filter to county rows, build FIPS, unpivot years.
-- SUMLEV=050 = county. STATE and COUNTY are zero-padded in source.

CREATE OR REPLACE TABLE curated.census_county_pop AS
WITH counties AS (
    SELECT
        LPAD(TRIM(STATE),  2, '0')                      AS state_fips,
        LPAD(TRIM(COUNTY), 3, '0')                      AS county_fips,
        TRIM(STNAME)                                    AS state_name,
        TRIM(CTYNAME)                                   AS county_name,
        TRIM(POPESTIMATE2020)                           AS "2020",
        TRIM(POPESTIMATE2021)                           AS "2021",
        TRIM(POPESTIMATE2022)                           AS "2022",
        TRIM(POPESTIMATE2023)                           AS "2023",
        TRIM(POPESTIMATE2024)                           AS "2024"
    FROM raw.census_pep
    WHERE TRIM(SUMLEV) = '050'           -- county rows only
      AND TRIM(COUNTY) != '000'          -- exclude state-level aggregate rows
),
unpivoted AS (
    UNPIVOT counties
    ON "2020","2021","2022","2023","2024"
    INTO NAME year_str VALUE pop_raw
)
SELECT
    state_fips || county_fips               AS fips,
    state_fips,
    county_fips,
    state_name,
    county_name,
    TRY_CAST(year_str AS INT)               AS year,
    TRY_CAST(pop_raw AS BIGINT)             AS population
FROM unpivoted
WHERE TRY_CAST(year_str AS INT) IS NOT NULL;
