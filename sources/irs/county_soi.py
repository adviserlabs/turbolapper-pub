"""IRS SOI — Individual Income Tax Statistics by County.

Downloads annual county AGI CSV files for the years defined in YEARS.
Each file has one row per (county, agi_stub) where agi_stub=0 is the
all-returns total and stubs 1–6 are income brackets.

Key columns used:
  STATEFIPS, COUNTYFIPS, COUNTYNAME, agi_stub
  N1        — number of returns (proxy for tax-filing households)
  A00100    — adjusted gross income ($thousands)
  N00200    — number of returns with wages
  A00200    — wages and salaries ($thousands)
"""

from __future__ import annotations

import logging
from pathlib import Path

import duckdb

from ... import config
from ..base import Source
from ..http import download_file

log = logging.getLogger(__name__)

# Tax years with confirmed public CSV availability.
# Add newer years as IRS releases them (~2-year lag from tax year).
YEARS = list(range(2015, 2023))  # 2015–2022

_BASE_URL = "https://www.irs.gov/pub/irs-soi/{yy}incyallagi.csv"
_SQL_DIR = Path(__file__).resolve().parent / "sql"


class IRSCountySOI(Source):
    name = "irs_county_soi"
    description = "IRS SOI county-level AGI, wages, return counts by income bracket, 2015–2022."

    @property
    def _raw_dir(self) -> Path:
        return config.RAW_DIR / "irs" / "soi"

    def _csv_path(self, year: int) -> Path:
        return self._raw_dir / f"irs_soi_{year}.csv"

    def download(self) -> None:
        for year in YEARS:
            yy = str(year)[2:]
            url = _BASE_URL.format(yy=yy)
            download_file(url, self._csv_path(year), label=self.name)

    def build_raw(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS raw")
        paths = [self._csv_path(y) for y in YEARS if self._csv_path(y).exists()]
        if not paths:
            raise RuntimeError(f"[{self.name}] no IRS SOI files found — run download first")
        # Select only the stable columns present in all years (schema drifts year-to-year).
        cols = "STATEFIPS, STATE, COUNTYFIPS, COUNTYNAME, agi_stub, N1, N2, A00100, N00200, A00200"
        parts = []
        for y, p in zip(YEARS, paths):
            parts.append(
                f"SELECT {y} AS tax_year, {cols} "
                f"FROM read_csv('{p.as_posix()}', header=true, all_varchar=true, ignore_errors=true)"
            )
        con.execute(
            "CREATE OR REPLACE TABLE raw.irs_soi AS " + " UNION ALL ".join(parts)
        )
        n = con.execute("SELECT count(*) FROM raw.irs_soi").fetchone()[0]
        log.info("[%s] raw loaded: %d rows (%d years)", self.name, n, len(paths))

    def build_curated(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS curated")
        sql = (_SQL_DIR / "county_soi_curated.sql").read_text()
        for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
            con.execute(stmt)
        log.info("[%s] curated built", self.name)

    def build_semantic(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS semantic")
        sql = (_SQL_DIR / "county_soi_semantic.sql").read_text()
        for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
            con.execute(stmt)
        log.info("[%s] semantic built", self.name)
