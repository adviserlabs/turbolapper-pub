-- BEA CAGDP2 curated: unpivot wide year columns into tall (fips, year, value) rows.
-- Source: raw.bea_cagdp2 — one row per (GeoFIPS, LineCode/industry), years as columns.
-- We keep LineCode=1 (All industry total) plus the major NAICS sectors.
-- GeoFIPS format: "01001" (quoted, 5-digit). State-level rows have FIPS ending in "000".

CREATE OR REPLACE TABLE curated.bea_county_gdp AS
WITH raw_trimmed AS (
    SELECT
        TRIM(REPLACE(GeoFIPS, '"', ''))   AS fips,
        TRIM(GeoName)                     AS geo_name,
        TRIM(Region)                      AS region,
        TRIM(LineCode)                    AS line_code,
        TRIM(IndustryClassification)      AS naics_code,
        TRIM(Description)                 AS industry_name,
        TRIM(Unit)                        AS unit,
        -- year value columns (all VARCHAR in raw)
        "2001","2002","2003","2004","2005","2006","2007","2008","2009","2010",
        "2011","2012","2013","2014","2015","2016","2017","2018","2019","2020",
        "2021","2022","2023","2024"
    FROM raw.bea_cagdp2
    -- skip US total, state totals, and suppressed/footnote rows
    WHERE LENGTH(TRIM(REPLACE(GeoFIPS, '"', ''))) = 5
      AND TRIM(REPLACE(GeoFIPS, '"', '')) NOT LIKE '%000'
      AND TRIM(LineCode) IS NOT NULL
      AND TRIM(LineCode) != ''
),
unpivoted AS (
    UNPIVOT raw_trimmed
    ON "2001","2002","2003","2004","2005","2006","2007","2008","2009","2010",
       "2011","2012","2013","2014","2015","2016","2017","2018","2019","2020",
       "2021","2022","2023","2024"
    INTO NAME year_str VALUE gdp_raw
)
SELECT
    fips,
    geo_name,
    region,
    TRY_CAST(line_code AS INT)                AS line_code,
    NULLIF(TRIM(naics_code), '...')           AS naics_code,
    TRIM(industry_name)                       AS industry_name,
    unit,
    TRY_CAST(year_str AS INT)                 AS year,
    -- BEA uses (D) for suppressed cells
    CASE WHEN TRIM(gdp_raw) IN ('(D)', '(NA)', '') THEN NULL
         ELSE TRY_CAST(TRIM(gdp_raw) AS DOUBLE)
    END                                       AS gdp_thousands
FROM unpivoted
WHERE TRY_CAST(year_str AS INT) IS NOT NULL;

-- FIPS dimension: distinct counties with state/county FIPS split
CREATE OR REPLACE TABLE curated.dim_counties AS
SELECT DISTINCT
    fips,
    geo_name                                  AS county_name,
    LEFT(fips, 2)                             AS state_fips,
    RIGHT(fips, 3)                            AS county_fips
FROM curated.bea_county_gdp
WHERE fips NOT LIKE '%000'
  AND LENGTH(fips) = 5
ORDER BY fips;
