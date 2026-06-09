"""Census Bureau PEP — County Population Estimates 2020–2024.

Single CSV: co-est2024-alldata.csv from the Census FTP.
Key columns: STATE, COUNTY (both zero-padded), STNAME, CTYNAME,
POPESTIMATEyyyy for 2020–2024.
SUMLEV=050 rows are counties; SUMLEV=040 are state totals (filtered out in curated).
"""

from __future__ import annotations

import logging
from pathlib import Path

import duckdb

from ... import config
from ..base import Source
from ..http import download_file

log = logging.getLogger(__name__)

_CSV_URL = (
    "https://www2.census.gov/programs-surveys/popest/datasets/"
    "2020-2024/counties/totals/co-est2024-alldata.csv"
)
_SQL_DIR = Path(__file__).resolve().parent / "sql"


class CensusCountyPopulation(Source):
    name = "census_county_pop"
    description = "Census PEP county population estimates, 2020–2024."

    @property
    def _raw_dir(self) -> Path:
        return config.RAW_DIR / "census"

    @property
    def _csv_path(self) -> Path:
        return self._raw_dir / "co-est2024-alldata.csv"

    def download(self) -> None:
        download_file(_CSV_URL, self._csv_path, label=self.name)

    def build_raw(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS raw")
        con.execute(f"""
            CREATE OR REPLACE TABLE raw.census_pep AS
            SELECT * FROM read_csv(
                '{self._csv_path.as_posix()}',
                header=true, all_varchar=true, ignore_errors=true
            )
        """)
        n = con.execute("SELECT count(*) FROM raw.census_pep").fetchone()[0]
        log.info("[%s] raw loaded: %d rows", self.name, n)

    def build_curated(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS curated")
        sql = (_SQL_DIR / "county_population_curated.sql").read_text()
        for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
            con.execute(stmt)
        log.info("[%s] curated built", self.name)

    def build_semantic(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS semantic")
        sql = (_SQL_DIR / "county_population_semantic.sql").read_text()
        for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
            con.execute(stmt)
        log.info("[%s] semantic built", self.name)
