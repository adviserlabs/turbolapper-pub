-- BEA CAINC1 curated: unpivot wide year columns.
-- LineCode 1 = personal income (thousands of dollars)
-- LineCode 2 = population (persons)
-- LineCode 3 = per capita personal income (dollars)

CREATE OR REPLACE TABLE curated.bea_county_income AS
WITH raw_trimmed AS (
    SELECT
        TRIM(REPLACE(GeoFIPS, '"', ''))   AS fips,
        TRIM(GeoName)                     AS geo_name,
        TRIM(LineCode)                    AS line_code,
        TRIM(Description)                 AS description,
        TRIM(Unit)                        AS unit,
        "1969","1970","1971","1972","1973","1974","1975","1976","1977","1978","1979",
        "1980","1981","1982","1983","1984","1985","1986","1987","1988","1989","1990",
        "1991","1992","1993","1994","1995","1996","1997","1998","1999","2000",
        "2001","2002","2003","2004","2005","2006","2007","2008","2009","2010",
        "2011","2012","2013","2014","2015","2016","2017","2018","2019","2020",
        "2021","2022","2023","2024"
    FROM raw.bea_cainc1
    WHERE LENGTH(TRIM(REPLACE(GeoFIPS, '"', ''))) = 5
      AND TRIM(REPLACE(GeoFIPS, '"', '')) NOT LIKE '%000'
      AND TRIM(LineCode) IN ('1', '2', '3')
),
unpivoted AS (
    UNPIVOT raw_trimmed
    ON "1969","1970","1971","1972","1973","1974","1975","1976","1977","1978","1979",
       "1980","1981","1982","1983","1984","1985","1986","1987","1988","1989","1990",
       "1991","1992","1993","1994","1995","1996","1997","1998","1999","2000",
       "2001","2002","2003","2004","2005","2006","2007","2008","2009","2010",
       "2011","2012","2013","2014","2015","2016","2017","2018","2019","2020",
       "2021","2022","2023","2024"
    INTO NAME year_str VALUE raw_value
)
SELECT
    fips,
    geo_name,
    TRY_CAST(line_code AS INT)                          AS line_code,
    CASE TRY_CAST(line_code AS INT)
        WHEN 1 THEN 'personal_income'
        WHEN 2 THEN 'population'
        WHEN 3 THEN 'per_capita_income'
    END                                                 AS metric,
    description,
    unit,
    TRY_CAST(year_str AS INT)                           AS year,
    CASE WHEN TRIM(raw_value) IN ('(D)', '(NA)', '')
         THEN NULL
         ELSE TRY_CAST(TRIM(raw_value) AS DOUBLE)
    END                                                 AS value
FROM unpivoted
WHERE TRY_CAST(year_str AS INT) IS NOT NULL;
