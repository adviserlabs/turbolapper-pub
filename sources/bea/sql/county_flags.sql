-- County semantic flag layer.
--
-- Philosophy: flags encode pre-answered questions about each county-year.
-- Three categories:
--   1. RELATIVE flags  -- percentile rank within year (stable comparisons)
--   2. STRUCTURAL flags -- economic character (what kind of economy is this?)
--   3. TREND flags      -- trajectory (what direction is this county moving?)
--
-- Thresholds are calibrated from 2022 national distributions (best year with
-- all four sources). Relative flags recompute annually so they are always
-- meaningful regardless of the year queried.
--
-- NULL convention: flag is NULL when the underlying data is unavailable,
-- so consumers can distinguish "false" from "unknown".

CREATE OR REPLACE TABLE semantic.county_flags AS
WITH base AS (
    SELECT
        fips,
        county_name,
        state_fips,
        year,

        -- raw metrics
        gdp_dollars,
        gdp_per_capita,
        yoy_gdp_growth_pct,
        gdp_rank_in_year,
        per_capita_income,
        yoy_per_capita_income_growth_pct,
        personal_income_thousands,
        avg_agi_per_return,
        yoy_agi_growth_pct,
        agi_dollars,
        wages_dollars,
        num_returns,
        population,
        yoy_pop_growth_pct,

        -- national percentile ranks recomputed per year
        -- GDP size
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY gdp_dollars NULLS LAST)
            AS gdp_pctrank,
        -- GDP per capita
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY gdp_per_capita NULLS LAST)
            AS gdp_pc_pctrank,
        -- per capita income
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY per_capita_income NULLS LAST)
            AS pci_pctrank,
        -- avg AGI per return
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY avg_agi_per_return NULLS LAST)
            AS agi_pctrank,
        -- population size
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY population NULLS LAST)
            AS pop_pctrank,
        -- GDP growth
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY yoy_gdp_growth_pct NULLS LAST)
            AS gdp_growth_pctrank,
        -- income growth
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY yoy_per_capita_income_growth_pct NULLS LAST)
            AS pci_growth_pctrank,
        -- population growth
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY yoy_pop_growth_pct NULLS LAST)
            AS pop_growth_pctrank,
        -- wage share of AGI (structural)
        CASE WHEN agi_dollars > 0 THEN wages_dollars / agi_dollars ELSE NULL END
            AS wage_share,
        -- returns per capita (tax base density, proxy for adult workforce participation)
        CASE WHEN population > 0 THEN num_returns / population ELSE NULL END
            AS returns_per_capita,
        -- GDP per return (economic output per filer, productivity proxy)
        CASE WHEN num_returns > 0 THEN gdp_dollars / num_returns ELSE NULL END
            AS gdp_per_return
    FROM semantic.county_unified
),
with_flags AS (
    SELECT
        fips,
        county_name,
        state_fips,
        year,

        -- ── SIZE FLAGS ────────────────────────────────────────────────────
        -- Is this a major economic hub? Top 10% by GDP nationally.
        CASE WHEN gdp_dollars IS NOT NULL THEN gdp_pctrank >= 0.90 END
            AS is_major_economic_hub,

        -- Top 25% by total GDP (significant regional economy)
        CASE WHEN gdp_dollars IS NOT NULL THEN gdp_pctrank >= 0.75 END
            AS is_large_economy,

        -- Bottom 25% by total GDP (small/rural economy)
        CASE WHEN gdp_dollars IS NOT NULL THEN gdp_pctrank < 0.25 END
            AS is_small_economy,

        -- Top 10% by population
        CASE WHEN population IS NOT NULL THEN pop_pctrank >= 0.90 END
            AS is_high_population,

        -- Bottom 25% by population (sparsely populated county)
        CASE WHEN population IS NOT NULL THEN pop_pctrank < 0.25 END
            AS is_low_population,

        -- ── INCOME & WEALTH FLAGS ──────────────────────────────────────────
        -- Per capita income above national median (~$51,600 in 2022)
        CASE WHEN per_capita_income IS NOT NULL THEN pci_pctrank >= 0.50 END
            AS is_above_median_income,

        -- High income: top quartile per capita income (>~$60,600 in 2022)
        CASE WHEN per_capita_income IS NOT NULL THEN pci_pctrank >= 0.75 END
            AS is_high_income,

        -- Low income: bottom quartile per capita income (<~$45,500 in 2022)
        CASE WHEN per_capita_income IS NOT NULL THEN pci_pctrank < 0.25 END
            AS is_low_income,

        -- High average AGI per tax return (top quartile ~>$77,200 in 2022)
        CASE WHEN avg_agi_per_return IS NOT NULL THEN agi_pctrank >= 0.75 END
            AS is_high_agi,

        -- Low average AGI per return (bottom quartile ~<$54,700 in 2022)
        CASE WHEN avg_agi_per_return IS NOT NULL THEN agi_pctrank < 0.25 END
            AS is_low_agi,

        -- Affluent: high on BOTH per capita income AND AGI (doubly confirmed)
        CASE WHEN per_capita_income IS NOT NULL AND avg_agi_per_return IS NOT NULL
             THEN pci_pctrank >= 0.75 AND agi_pctrank >= 0.75 END
            AS is_affluent,

        -- Economically distressed proxy: low income AND low GDP per capita
        -- (Note: formal EDA distressed definition requires unemployment + poverty data)
        CASE WHEN per_capita_income IS NOT NULL AND gdp_per_capita IS NOT NULL
             THEN pci_pctrank < 0.25 AND gdp_pc_pctrank < 0.25 END
            AS is_economically_distressed_proxy,

        -- GDP per capita above median (productive economy relative to population)
        CASE WHEN gdp_per_capita IS NOT NULL THEN gdp_pc_pctrank >= 0.50 END
            AS is_above_median_gdp_per_capita,

        -- ── STRUCTURAL / ECONOMIC CHARACTER FLAGS ────────────────────────
        -- Wage economy: wages make up >67% of AGI (working-class income base)
        -- National median wage share is ~67%
        CASE WHEN wage_share IS NOT NULL THEN wage_share > 0.67 END
            AS is_wage_economy,

        -- Investment/wealth economy: wage share <55% (significant non-wage income)
        CASE WHEN wage_share IS NOT NULL THEN wage_share < 0.55 END
            AS is_investment_economy,

        -- High tax-filing density: >48% returns per capita (engaged workforce)
        CASE WHEN returns_per_capita IS NOT NULL THEN returns_per_capita > 0.48 END
            AS is_high_filer_density,

        -- Low tax-filing density: <41% returns per capita
        -- (may indicate high elderly/dependent population or informal economy)
        CASE WHEN returns_per_capita IS NOT NULL THEN returns_per_capita < 0.41 END
            AS is_low_filer_density,

        -- High productivity: GDP per tax return above national median (~$112K in 2022)
        CASE WHEN gdp_per_return IS NOT NULL THEN gdp_per_return > 112000 END
            AS is_high_productivity,

        -- Income-GDP gap: per capita income substantially exceeds GDP per capita
        -- (residents earn more than the local economy produces — commuter county)
        CASE WHEN per_capita_income IS NOT NULL AND gdp_per_capita IS NOT NULL AND gdp_per_capita > 0
             THEN (per_capita_income / gdp_per_capita) > 1.3 END
            AS is_commuter_county,

        -- GDP concentration: county produces outsized GDP relative to income
        -- (economic activity exceeds residential income — business hub / extraction economy)
        CASE WHEN per_capita_income IS NOT NULL AND gdp_per_capita IS NOT NULL AND per_capita_income > 0
             THEN (gdp_per_capita / per_capita_income) > 1.5 END
            AS is_economic_hub_county,

        -- ── GROWTH & TREND FLAGS ──────────────────────────────────────────
        -- Fast GDP growth: top quartile YoY growth nationally
        CASE WHEN yoy_gdp_growth_pct IS NOT NULL THEN gdp_growth_pctrank >= 0.75 END
            AS is_fast_gdp_growth,

        -- Slow/declining GDP: bottom quartile YoY growth
        CASE WHEN yoy_gdp_growth_pct IS NOT NULL THEN gdp_growth_pctrank < 0.25 END
            AS is_slow_gdp_growth,

        -- Absolute GDP contraction YoY
        CASE WHEN yoy_gdp_growth_pct IS NOT NULL THEN yoy_gdp_growth_pct < 0 END
            AS is_gdp_contracting,

        -- Income growing: positive YoY per capita income growth
        CASE WHEN yoy_per_capita_income_growth_pct IS NOT NULL
             THEN yoy_per_capita_income_growth_pct > 0 END
            AS is_income_growing,

        -- Income declining YoY
        CASE WHEN yoy_per_capita_income_growth_pct IS NOT NULL
             THEN yoy_per_capita_income_growth_pct < 0 END
            AS is_income_declining,

        -- Fast income growth: top quartile nationally
        CASE WHEN yoy_per_capita_income_growth_pct IS NOT NULL
             THEN pci_growth_pctrank >= 0.75 END
            AS is_fast_income_growth,

        -- Population growing
        CASE WHEN yoy_pop_growth_pct IS NOT NULL THEN yoy_pop_growth_pct > 0 END
            AS is_population_growing,

        -- Population declining
        CASE WHEN yoy_pop_growth_pct IS NOT NULL THEN yoy_pop_growth_pct < 0 END
            AS is_population_declining,

        -- Fast population growth: top quartile nationally
        CASE WHEN yoy_pop_growth_pct IS NOT NULL THEN pop_growth_pctrank >= 0.75 END
            AS is_fast_population_growth,

        -- Rapid population loss: bottom decile YoY growth
        CASE WHEN yoy_pop_growth_pct IS NOT NULL THEN pop_growth_pctrank < 0.10 END
            AS is_rapid_population_loss,

        -- AGI growing YoY
        CASE WHEN yoy_agi_growth_pct IS NOT NULL THEN yoy_agi_growth_pct > 0 END
            AS is_agi_growing,

        -- ── COMPOSITE SITUATION FLAGS ─────────────────────────────────────
        -- "Brain drain / shrinking": declining population AND declining income
        CASE WHEN yoy_pop_growth_pct IS NOT NULL AND yoy_per_capita_income_growth_pct IS NOT NULL
             THEN yoy_pop_growth_pct < 0 AND yoy_per_capita_income_growth_pct < 0 END
            AS is_shrinking_and_declining,

        -- "Growing and prospering": top quartile both population AND income growth
        CASE WHEN pop_growth_pctrank IS NOT NULL AND pci_growth_pctrank IS NOT NULL
             THEN pop_growth_pctrank >= 0.75 AND pci_growth_pctrank >= 0.75 END
            AS is_growing_and_prospering,

        -- "High income, low growth": wealthy but stagnant (mature economy)
        CASE WHEN pci_pctrank IS NOT NULL AND pci_growth_pctrank IS NOT NULL
             THEN pci_pctrank >= 0.75 AND pci_growth_pctrank < 0.50 END
            AS is_wealthy_and_stagnant,

        -- "Low income, high growth": catching up (development trajectory)
        CASE WHEN pci_pctrank IS NOT NULL AND pci_growth_pctrank IS NOT NULL
             THEN pci_pctrank < 0.25 AND pci_growth_pctrank >= 0.75 END
            AS is_low_income_high_growth,

        -- "Boomtown": top quartile BOTH GDP growth AND population growth
        CASE WHEN gdp_growth_pctrank IS NOT NULL AND pop_growth_pctrank IS NOT NULL
             THEN gdp_growth_pctrank >= 0.75 AND pop_growth_pctrank >= 0.75 END
            AS is_boomtown,

        -- "Left behind": bottom quartile GDP growth AND declining population
        CASE WHEN gdp_growth_pctrank IS NOT NULL AND pop_growth_pctrank IS NOT NULL
             THEN gdp_growth_pctrank < 0.25 AND pop_growth_pctrank < 0.25 END
            AS is_left_behind,

        -- ── DATA AVAILABILITY FLAGS ───────────────────────────────────────
        -- Useful for the LLM to know what it can and can't answer
        (gdp_dollars IS NOT NULL)          AS has_gdp_data,
        (per_capita_income IS NOT NULL)    AS has_income_data,
        (avg_agi_per_return IS NOT NULL)   AS has_tax_data,
        (population IS NOT NULL)           AS has_population_data

    FROM base
)
SELECT * FROM with_flags;
