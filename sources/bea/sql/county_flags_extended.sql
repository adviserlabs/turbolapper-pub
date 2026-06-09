-- Extended county flags: industry dominance + migration.
-- Runs after county_flags.sql. Adds two new tables and a combined view.

-- ── 1. INDUSTRY DOMINANCE ─────────────────────────────────────────────────────
-- For each county-year, find which sector contributes the largest share of GDP
-- and derive dominance flags. Uses CAGDP2 line codes for the 7 major sectors.

CREATE OR REPLACE TABLE semantic.county_industry_flags AS
WITH sector_gdp AS (
    SELECT
        fips,
        county_name,
        LEFT(fips, 2)                   AS state_fips,
        year,
        -- total (line_code=1) for share calculation
        MAX(gdp_dollars) FILTER (WHERE line_code = 1)  AS gdp_total,
        -- major sectors
        MAX(gdp_dollars) FILTER (WHERE line_code = 3)  AS gdp_agriculture,
        MAX(gdp_dollars) FILTER (WHERE line_code = 6)  AS gdp_mining_energy,
        MAX(gdp_dollars) FILTER (WHERE line_code = 12) AS gdp_manufacturing,
        MAX(gdp_dollars) FILTER (WHERE line_code = 35) AS gdp_retail,
        MAX(gdp_dollars) FILTER (WHERE line_code = 50) AS gdp_finance_realestate,
        MAX(gdp_dollars) FILTER (WHERE line_code = 59) AS gdp_professional_services,
        MAX(gdp_dollars) FILTER (WHERE line_code = 68) AS gdp_education_healthcare,
        MAX(gdp_dollars) FILTER (WHERE line_code = 75) AS gdp_hospitality,
        MAX(gdp_dollars) FILTER (WHERE line_code = 83) AS gdp_government
    FROM semantic.county_gdp
    GROUP BY fips, county_name, year
),
with_shares AS (
    SELECT
        fips, county_name, state_fips, year, gdp_total,
        gdp_agriculture,
        gdp_mining_energy,
        gdp_manufacturing,
        gdp_retail,
        gdp_finance_realestate,
        gdp_professional_services,
        gdp_education_healthcare,
        gdp_hospitality,
        gdp_government,
        -- shares (null-safe)
        ROUND(gdp_agriculture            / NULLIF(gdp_total,0) * 100, 1) AS pct_agriculture,
        ROUND(gdp_mining_energy          / NULLIF(gdp_total,0) * 100, 1) AS pct_mining_energy,
        ROUND(gdp_manufacturing          / NULLIF(gdp_total,0) * 100, 1) AS pct_manufacturing,
        ROUND(gdp_retail                 / NULLIF(gdp_total,0) * 100, 1) AS pct_retail,
        ROUND(gdp_finance_realestate     / NULLIF(gdp_total,0) * 100, 1) AS pct_finance_realestate,
        ROUND(gdp_professional_services  / NULLIF(gdp_total,0) * 100, 1) AS pct_professional_services,
        ROUND(gdp_education_healthcare   / NULLIF(gdp_total,0) * 100, 1) AS pct_education_healthcare,
        ROUND(gdp_hospitality            / NULLIF(gdp_total,0) * 100, 1) AS pct_hospitality,
        ROUND(gdp_government             / NULLIF(gdp_total,0) * 100, 1) AS pct_government
    FROM sector_gdp
)
SELECT
    fips, county_name, state_fips, year,
    pct_agriculture, pct_mining_energy, pct_manufacturing, pct_retail,
    pct_finance_realestate, pct_professional_services,
    pct_education_healthcare, pct_hospitality, pct_government,

    -- dominant sector: which single sector is largest share
    CASE
        WHEN gdp_agriculture IS NULL THEN NULL
        ELSE (
            SELECT sector FROM (VALUES
                ('agriculture',          gdp_agriculture),
                ('mining_energy',        gdp_mining_energy),
                ('manufacturing',        gdp_manufacturing),
                ('retail',               gdp_retail),
                ('finance_realestate',   gdp_finance_realestate),
                ('professional_services',gdp_professional_services),
                ('education_healthcare', gdp_education_healthcare),
                ('hospitality',          gdp_hospitality),
                ('government',           gdp_government)
            ) AS t(sector, val)
            ORDER BY val DESC NULLS LAST LIMIT 1
        )
    END                                             AS dominant_sector,

    -- sector dominance flags (>25% of county GDP = dominant, >15% = significant)
    (pct_agriculture > 25)                          AS is_agriculture_dominant,
    (pct_agriculture > 15)                          AS is_agriculture_significant,
    (pct_mining_energy > 25)                        AS is_energy_dominant,
    (pct_mining_energy > 15)                        AS is_energy_significant,
    (pct_manufacturing > 25)                        AS is_manufacturing_dominant,
    (pct_manufacturing > 15)                        AS is_manufacturing_significant,
    (pct_government > 25)                           AS is_government_dominant,
    (pct_government > 15)                           AS is_government_significant,
    (pct_finance_realestate > 25)                   AS is_finance_dominant,
    (pct_professional_services > 20)                AS is_knowledge_economy,
    (pct_hospitality > 20)                          AS is_tourism_economy,
    (pct_education_healthcare > 25)                 AS is_eds_meds_economy,

    -- multi-sector flags
    (pct_agriculture > 15 OR pct_mining_energy > 15)  AS is_natural_resource_economy,
    (pct_manufacturing > 15 OR pct_agriculture > 15
     OR pct_mining_energy > 15)                       AS is_goods_producing_economy,
    (pct_professional_services > 15
     OR pct_finance_realestate > 20)                  AS is_service_economy

FROM with_shares;


-- ── 2. MIGRATION FLAGS ────────────────────────────────────────────────────────
-- Unpivot Census PEP migration columns into the same year-tall format.

CREATE OR REPLACE TABLE semantic.county_migration AS
WITH county_rows AS (
    SELECT
        LPAD(TRIM(STATE), 2, '0') || LPAD(TRIM(COUNTY), 3, '0') AS fips,
        TRIM(STNAME)    AS state_name,
        TRIM(CTYNAME)   AS county_name,
        -- domestic migration
        TRY_CAST(TRIM(DOMESTICMIG2020)      AS BIGINT) AS dom_2020,
        TRY_CAST(TRIM(DOMESTICMIG2021)      AS BIGINT) AS dom_2021,
        TRY_CAST(TRIM(DOMESTICMIG2022)      AS BIGINT) AS dom_2022,
        TRY_CAST(TRIM(DOMESTICMIG2023)      AS BIGINT) AS dom_2023,
        TRY_CAST(TRIM(DOMESTICMIG2024)      AS BIGINT) AS dom_2024,
        -- international migration
        TRY_CAST(TRIM(INTERNATIONALMIG2020) AS BIGINT) AS intl_2020,
        TRY_CAST(TRIM(INTERNATIONALMIG2021) AS BIGINT) AS intl_2021,
        TRY_CAST(TRIM(INTERNATIONALMIG2022) AS BIGINT) AS intl_2022,
        TRY_CAST(TRIM(INTERNATIONALMIG2023) AS BIGINT) AS intl_2023,
        TRY_CAST(TRIM(INTERNATIONALMIG2024) AS BIGINT) AS intl_2024,
        -- net migration
        TRY_CAST(TRIM(NETMIG2020)           AS BIGINT) AS net_2020,
        TRY_CAST(TRIM(NETMIG2021)           AS BIGINT) AS net_2021,
        TRY_CAST(TRIM(NETMIG2022)           AS BIGINT) AS net_2022,
        TRY_CAST(TRIM(NETMIG2023)           AS BIGINT) AS net_2023,
        TRY_CAST(TRIM(NETMIG2024)           AS BIGINT) AS net_2024
    FROM raw.census_pep
    WHERE TRIM(SUMLEV) = '050' AND TRIM(COUNTY) != '000'
),
unpivoted AS (
    -- domestic
    SELECT fips, state_name, county_name, 2020 AS year, dom_2020 AS domestic_migration, intl_2020 AS international_migration, net_2020 AS net_migration FROM county_rows UNION ALL
    SELECT fips, state_name, county_name, 2021, dom_2021, intl_2021, net_2021 FROM county_rows UNION ALL
    SELECT fips, state_name, county_name, 2022, dom_2022, intl_2022, net_2022 FROM county_rows UNION ALL
    SELECT fips, state_name, county_name, 2023, dom_2023, intl_2023, net_2023 FROM county_rows UNION ALL
    SELECT fips, state_name, county_name, 2024, dom_2024, intl_2024, net_2024 FROM county_rows
)
SELECT
    fips,
    LEFT(fips, 2)                           AS state_fips,
    state_name,
    county_name,
    year,
    domestic_migration,
    international_migration,
    net_migration,
    -- flags
    (net_migration > 0)                     AS is_net_migration_positive,
    (net_migration < 0)                     AS is_net_migration_negative,
    (domestic_migration > 0)                AS is_domestic_migration_positive,
    (domestic_migration < 0)                AS is_domestic_out_migration,
    (international_migration > 100)         AS is_immigration_significant,
    -- immigration-driven: international > domestic contribution
    (international_migration > 0 AND international_migration > domestic_migration)
                                            AS is_immigration_driven_growth,
    -- domestic magnet: strong positive domestic in-migration (top indicator of desirability)
    PERCENT_RANK() OVER (PARTITION BY year ORDER BY domestic_migration NULLS LAST) >= 0.75
                                            AS is_domestic_migration_magnet,
    -- domestic exodus: strong net out-migration
    PERCENT_RANK() OVER (PARTITION BY year ORDER BY domestic_migration NULLS LAST) < 0.25
                                            AS is_domestic_exodus
FROM unpivoted
WHERE net_migration IS NOT NULL;


-- ── 3. MASTER FLAG VIEW ───────────────────────────────────────────────────────
-- Combines all flag tables into one wide view per county-year.
-- This is the primary surface for LLM queries and the skills prompt.

CREATE OR REPLACE VIEW semantic.county_all_flags AS
SELECT
    f.fips,
    f.county_name,
    f.state_fips,
    f.year,

    -- size
    f.is_major_economic_hub,
    f.is_large_economy,
    f.is_small_economy,
    f.is_high_population,
    f.is_low_population,

    -- income & wealth
    f.is_above_median_income,
    f.is_high_income,
    f.is_low_income,
    f.is_high_agi,
    f.is_low_agi,
    f.is_affluent,
    f.is_economically_distressed_proxy,
    f.is_above_median_gdp_per_capita,

    -- economic structure
    f.is_wage_economy,
    f.is_investment_economy,
    f.is_high_filer_density,
    f.is_low_filer_density,
    f.is_high_productivity,
    f.is_commuter_county,
    f.is_economic_hub_county,

    -- growth trends
    f.is_fast_gdp_growth,
    f.is_slow_gdp_growth,
    f.is_gdp_contracting,
    f.is_income_growing,
    f.is_income_declining,
    f.is_fast_income_growth,
    f.is_population_growing,
    f.is_population_declining,
    f.is_fast_population_growth,
    f.is_rapid_population_loss,
    f.is_agi_growing,

    -- composite situations
    f.is_shrinking_and_declining,
    f.is_growing_and_prospering,
    f.is_wealthy_and_stagnant,
    f.is_low_income_high_growth,
    f.is_boomtown,
    f.is_left_behind,

    -- industry character (2001-2024)
    i.dominant_sector,
    i.pct_agriculture,
    i.pct_mining_energy,
    i.pct_manufacturing,
    i.pct_government,
    i.pct_professional_services,
    i.pct_finance_realestate,
    i.pct_education_healthcare,
    i.pct_hospitality,
    i.is_agriculture_dominant,
    i.is_energy_dominant,
    i.is_manufacturing_dominant,
    i.is_government_dominant,
    i.is_finance_dominant,
    i.is_knowledge_economy,
    i.is_tourism_economy,
    i.is_eds_meds_economy,
    i.is_natural_resource_economy,
    i.is_goods_producing_economy,
    i.is_service_economy,

    -- migration (2020-2024)
    m.net_migration,
    m.domestic_migration,
    m.international_migration,
    m.is_net_migration_positive,
    m.is_net_migration_negative,
    m.is_domestic_migration_positive,
    m.is_domestic_out_migration,
    m.is_immigration_significant,
    m.is_immigration_driven_growth,
    m.is_domestic_migration_magnet,
    m.is_domestic_exodus,

    -- household-normalized metrics (2001-2024 where IRS + BEA overlap)
    h.hh_size_proxy,
    h.num_hh_proxy,
    h.personal_income_per_hh,
    h.agi_per_hh,
    h.wages_per_hh,
    h.non_wage_income_per_hh,
    h.gdp_per_hh,
    h.wage_pct_of_agi,
    h.personal_income_per_hh_rank,
    h.agi_per_hh_rank,
    h.wages_per_hh_rank,
    h.gdp_per_hh_rank,
    h.is_high_hh_income,
    h.is_low_hh_income,
    h.is_above_median_hh_income,
    h.is_high_capital_gdp_ratio,
    h.is_large_hh_county,
    h.is_small_hh_county,
    h.is_wage_dependent_hh,
    h.is_investment_hh_county,

    -- data availability
    f.has_gdp_data,
    f.has_income_data,
    f.has_tax_data,
    f.has_population_data

FROM semantic.county_flags f
LEFT JOIN semantic.county_industry_flags i ON i.fips = f.fips AND i.year = f.year
LEFT JOIN semantic.county_migration       m ON m.fips = f.fips AND m.year = f.year
LEFT JOIN semantic.county_hh             h ON h.fips = f.fips AND h.year = f.year;
