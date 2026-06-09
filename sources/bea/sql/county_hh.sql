-- Household-normalized county metrics.
--
-- Goal: make county comparisons meaningful for household-level decisions
-- (where to live, affordability, real purchasing power) rather than aggregate
-- economic size, which always favors large/dense counties.
--
-- Household proxy: IRS num_returns ≈ tax filing units ≈ households.
-- This is imperfect (some multi-earner HHs file jointly, some individuals file
-- separately) but it's the best county-level proxy available without ACS microdata.
--
-- All "per_hh_*" metrics use num_returns as denominator.
-- "per_capita_*" metrics use BEA population.
-- "hh_size" = population / num_returns (average persons per filing unit).

CREATE OR REPLACE TABLE semantic.county_hh AS
WITH base AS (
    SELECT
        u.fips,
        u.county_name,
        u.state_fips,
        u.year,

        -- raw building blocks
        u.gdp_dollars,
        u.personal_income_thousands * 1000            AS personal_income_dollars,
        u.per_capita_income,
        u.agi_dollars,
        u.wages_dollars,
        u.num_returns,
        u.population,

        -- ── HOUSEHOLD SIZE ────────────────────────────────────────────────
        -- Average persons per tax filing unit (household size proxy)
        CASE WHEN num_returns > 0
             THEN ROUND(u.population::DOUBLE / num_returns, 2)
        END                                           AS hh_size_proxy,

        -- ── INCOME PER HOUSEHOLD ──────────────────────────────────────────
        -- BEA personal income divided by IRS filing units
        -- Includes wages, investment income, transfer payments (richer than AGI)
        CASE WHEN num_returns > 0
             THEN ROUND((u.personal_income_thousands * 1000) / num_returns)
        END                                           AS personal_income_per_hh,

        -- IRS AGI per filing unit (taxable income only — excludes transfers)
        CASE WHEN num_returns > 0
             THEN ROUND(u.agi_dollars / num_returns)
        END                                           AS agi_per_hh,

        -- Wage income per filing unit (labor income only)
        CASE WHEN num_returns > 0
             THEN ROUND(u.wages_dollars / num_returns)
        END                                           AS wages_per_hh,

        -- ── GDP PER HOUSEHOLD ─────────────────────────────────────────────
        -- Local economic output per filing unit (productivity/prosperity signal)
        CASE WHEN num_returns > 0
             THEN ROUND(u.gdp_dollars / num_returns)
        END                                           AS gdp_per_hh,

        -- ── INCOME COMPOSITION ────────────────────────────────────────────
        -- Non-wage income per HH (investment, business, transfers)
        -- Negative values indicate data gap (agi < wages due to losses/adjustments)
        CASE WHEN num_returns > 0 AND u.agi_dollars >= u.wages_dollars
             THEN ROUND((u.agi_dollars - u.wages_dollars) / num_returns)
        END                                           AS non_wage_income_per_hh,

        -- Wage share of AGI (structural: what fraction of HH income is labor)
        CASE WHEN u.agi_dollars > 0
             THEN ROUND(u.wages_dollars / u.agi_dollars * 100, 1)
        END                                           AS wage_pct_of_agi,

        -- ── GROWTH PER HOUSEHOLD ──────────────────────────────────────────
        -- YoY growth in per-capita income (already normalized, stable proxy)
        u.yoy_per_capita_income_growth_pct,

        -- AGI growth YoY (tax-unit level income trajectory)
        u.yoy_agi_growth_pct

    FROM semantic.county_unified u
),
with_ranks AS (
    SELECT
        *,
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY personal_income_per_hh NULLS LAST)
            AS personal_income_per_hh_rank,
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY agi_per_hh NULLS LAST)
            AS agi_per_hh_rank,
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY wages_per_hh NULLS LAST)
            AS wages_per_hh_rank,
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY gdp_per_hh NULLS LAST)
            AS gdp_per_hh_rank,
        PERCENT_RANK() OVER (PARTITION BY year ORDER BY hh_size_proxy NULLS LAST)
            AS hh_size_rank
    FROM base
)
SELECT
    fips, county_name, state_fips, year,
    hh_size_proxy,
    population,
    num_returns                                       AS num_hh_proxy,

    -- absolute HH metrics
    personal_income_per_hh,
    agi_per_hh,
    wages_per_hh,
    non_wage_income_per_hh,
    gdp_per_hh,
    wage_pct_of_agi,
    per_capita_income,

    -- national rank within year (0=lowest, 1=highest)
    personal_income_per_hh_rank,
    agi_per_hh_rank,
    wages_per_hh_rank,
    gdp_per_hh_rank,
    hh_size_rank,

    -- ── HH-LEVEL FLAGS ────────────────────────────────────────────────────
    -- High HH income: top quartile personal income per filing unit nationally
    CASE WHEN personal_income_per_hh IS NOT NULL
         THEN personal_income_per_hh_rank >= 0.75
    END                                               AS is_high_hh_income,

    -- Low HH income: bottom quartile
    CASE WHEN personal_income_per_hh IS NOT NULL
         THEN personal_income_per_hh_rank < 0.25
    END                                               AS is_low_hh_income,

    -- Above-median HH income nationally
    CASE WHEN personal_income_per_hh IS NOT NULL
         THEN personal_income_per_hh_rank >= 0.50
    END                                               AS is_above_median_hh_income,

    -- Dual-income proxy: large economy (high GDP per HH) relative to wages
    -- High GDP/HH but modest wage/HH → likely high capital/business income county
    CASE WHEN gdp_per_hh IS NOT NULL AND wages_per_hh IS NOT NULL AND wages_per_hh > 0
         THEN ROUND(gdp_per_hh::DOUBLE / wages_per_hh, 2) > 2.5
    END                                               AS is_high_capital_gdp_ratio,

    -- Large household county: above-median household size proxy
    -- Matters for cost comparisons (larger HHs need more housing, etc.)
    CASE WHEN hh_size_proxy IS NOT NULL
         THEN hh_size_rank >= 0.50
    END                                               AS is_large_hh_county,

    -- Small household county: bottom quartile HH size (retirees, singles, urban)
    CASE WHEN hh_size_proxy IS NOT NULL
         THEN hh_size_rank < 0.25
    END                                               AS is_small_hh_county,

    -- "Wage-dependent household": wages > 80% of AGI (most income is labor)
    CASE WHEN wage_pct_of_agi IS NOT NULL
         THEN wage_pct_of_agi > 80
    END                                               AS is_wage_dependent_hh,

    -- "Investment household": wages < 55% of AGI (significant non-labor income)
    CASE WHEN wage_pct_of_agi IS NOT NULL
         THEN wage_pct_of_agi < 55
    END                                               AS is_investment_hh_county,

    yoy_per_capita_income_growth_pct,
    yoy_agi_growth_pct

FROM with_ranks;
