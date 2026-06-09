-- IRS SOI county curated: type, clean FIPS, standardise column names.
-- agi_stub=0 is the all-returns total. Stubs 1-6 are income brackets (preserved).
-- FIPS = LPAD(STATEFIPS,2,'0') || LPAD(COUNTYFIPS,3,'0')

CREATE OR REPLACE TABLE curated.irs_county_soi AS
SELECT
    tax_year,
    LPAD(TRIM(STATEFIPS), 2, '0') || LPAD(TRIM(COUNTYFIPS), 3, '0') AS fips,
    TRIM(STATE)                                     AS state_abbr,
    TRIM(COUNTYNAME)                                AS county_name,
    TRY_CAST(TRIM(agi_stub) AS INT)                 AS agi_stub,
    -- return counts
    TRY_CAST(TRIM(N1) AS DOUBLE)                    AS num_returns,
    TRY_CAST(TRIM(N2) AS DOUBLE)                    AS num_exemptions,
    -- AGI ($thousands in source)
    TRY_CAST(TRIM(A00100) AS DOUBLE)                AS agi_thousands,
    -- wages ($thousands)
    TRY_CAST(TRIM(N00200) AS DOUBLE)                AS num_returns_wages,
    TRY_CAST(TRIM(A00200) AS DOUBLE)                AS wages_thousands
FROM raw.irs_soi
WHERE TRIM(STATEFIPS) NOT IN ('', '00')
  AND TRIM(COUNTYFIPS) NOT IN ('', '000')
  AND TRY_CAST(TRIM(agi_stub) AS INT) IS NOT NULL;
