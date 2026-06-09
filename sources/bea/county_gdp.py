"""BEA CAGDP2 — County GDP by industry (nominal, current dollars).

Downloads the BEA Regional bulk ZIP for table CAGDP2, extracts the single
all-areas CSV, loads it verbatim, then unpivots years into rows.
"""

from __future__ import annotations

import logging
import zipfile
from pathlib import Path

import duckdb

from ... import config
from ..base import Source
from ..http import download_file

log = logging.getLogger(__name__)

_ZIP_URL = "https://apps.bea.gov/regional/zip/CAGDP2.zip"
_SQL_DIR = Path(__file__).resolve().parent / "sql"


class BEACountyGDP(Source):
    name = "bea_county_gdp"
    description = "BEA CAGDP2 — county GDP by NAICS industry, nominal dollars, 2001–2024."

    @property
    def _raw_dir(self) -> Path:
        return config.RAW_DIR / "bea" / "cagdp2"

    @property
    def _zip_path(self) -> Path:
        return self._raw_dir / "CAGDP2.zip"

    @property
    def _csv_path(self) -> Path:
        return self._raw_dir / "CAGDP2__ALL_AREAS.csv"

    def download(self) -> None:
        download_file(_ZIP_URL, self._zip_path, label=self.name)
        if not self._csv_path.exists():
            with zipfile.ZipFile(self._zip_path) as zf:
                all_areas = next(n for n in zf.namelist() if "ALL_AREAS" in n and n.endswith(".csv"))
                self._csv_path.write_bytes(zf.read(all_areas))
            log.info("[%s] extracted %s", self.name, self._csv_path.name)

    def build_raw(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS raw")
        con.execute(f"""
            CREATE OR REPLACE TABLE raw.bea_cagdp2 AS
            SELECT * FROM read_csv(
                '{self._csv_path.as_posix()}',
                header=true, all_varchar=true,
                quote='"', ignore_errors=true
            )
        """)
        n = con.execute("SELECT count(*) FROM raw.bea_cagdp2").fetchone()[0]
        log.info("[%s] raw loaded: %d rows", self.name, n)

    def build_curated(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS curated")
        sql = (_SQL_DIR / "county_gdp_curated.sql").read_text()
        for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
            con.execute(stmt)
        log.info("[%s] curated built", self.name)

    def build_semantic(self, con: duckdb.DuckDBPyConnection) -> None:
        con.execute("CREATE SCHEMA IF NOT EXISTS semantic")
        sql = (_SQL_DIR / "county_gdp_semantic.sql").read_text()
        for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
            con.execute(stmt)
        log.info("[%s] semantic built", self.name)
