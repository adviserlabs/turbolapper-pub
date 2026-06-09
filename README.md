# US County Economics — Artifact Bundle

A self-contained dataset bundle covering **~3,200 US counties** with GDP, income, taxes, population, migration, industry sector composition, and household-normalized metrics — all pre-joined and pre-flagged into a single `.duckdb` file.

## What's here

| File | Purpose |
|---|---|
| `BUNDLE.json` | Machine-readable manifest: sources, tables, year ranges, LLM prompt hint |
| `docs/SCHEMA_REFERENCE.md` | Every table and column described |
| `docs/GEO_CATALOG.md` | Geography reference: FIPS codes, state table, CPI metros |
| `docs/TEST_QUESTIONS.md` | 55 canonical questions with reference SQL |
| `docs/KNOWN_UNKNOWNS.md` | Flags and questions we can't answer yet, with data sources to add |
| `sources/` | Python + SQL build pipeline (requires turbolapper engine) |

## What's in the bundle

Four raw data sources, all public domain US government data:

| Source | Dataset | Years | Counties |
|---|---|---|---|
| BEA | CAGDP2 — GDP by county and industry | 2001–2024 | 3,126 |
| BEA | CAINC1 — Personal income, population, per-capita income | 1969–2024 | 3,148 |
| IRS | Statistics of Income — AGI and wages by county | 2015–2022 | 3,203 |
| Census | Population Estimates Program — population + migration | 2020–2024 | 3,143 |

Built into a medallion architecture (raw → curated → semantic) ending in:

- **`semantic.county_all_flags`** — 96-column wide table, one row per county per year. The primary surface for LLM queries. Contains every metric and 55+ boolean flags.
- **`semantic.county_hh`** — household-normalized metrics (income, wages, GDP per tax filing unit). Normalizes for population density so rural and urban counties are comparable for household-level decisions.
- **`semantic.county_industry_flags`** — industry sector shares and dominance flags from BEA NAICS line codes.
- **`semantic.county_migration`** — domestic and international migration flows.

## Quick start with an LLM

Point any LLM at the `.duckdb` file and the `BUNDLE.json` manifest. The `llm_prompt_hint` field in the manifest gives the model everything it needs to start querying. Full schema context is in `docs/SCHEMA_REFERENCE.md`.

```python
import duckdb
con = duckdb.connect("turbolapper.duckdb", read_only=True)

# Top 10 boomtowns in 2022
con.execute("""
    SELECT county_name, state_fips,
           ROUND(yoy_gdp_growth_pct, 1) AS gdp_growth,
           ROUND(yoy_pop_growth_pct, 2) AS pop_growth,
           dominant_sector
    FROM semantic.county_all_flags
    WHERE year = 2022 AND is_boomtown IS TRUE
    ORDER BY yoy_gdp_growth_pct DESC LIMIT 10
""").df()
```

## Flag philosophy

Boolean flags pre-answer thousands of common questions. Each flag is:
- **NULL** when data is unavailable (not false — distinguishes unknown from no)
- **Relative** when rank-based (top quartile = top quartile *within that year*, stable across time)
- **Absolute** when structurally meaningful (wage share thresholds, migration sign)

Example flags: `is_boomtown`, `is_left_behind`, `is_energy_dominant`, `is_commuter_county`, `is_domestic_migration_magnet`, `is_investment_hh_county`

## Building the bundle

Requires the [turbolapper](https://github.com/adviserlabs/turbolapper-priv) engine.

```sh
uv run turbolapper ingest          # downloads + builds everything (~2-3 GB download)
uv run turbolapper ingest --no-download  # rebuild from cached data
```

## Contributing

See `docs/KNOWN_UNKNOWNS.md` for the prioritized list of flags and data sources not yet added. Each entry includes the source URL, difficulty rating, and what questions it would unlock.

High-priority additions:
1. Census SAIPE poverty rates — unlocks `is_below_poverty_line`
2. USDA Rural-Urban Continuum Codes — unlocks `is_rural` / `is_metro`
3. BLS LAUS unemployment — unlocks `is_high_unemployment`
4. BEA Regional Price Parities — unlocks cost-of-living adjusted comparisons

## License

Build code: MIT. Data: public domain (US Government works — BEA, IRS, Census Bureau).
