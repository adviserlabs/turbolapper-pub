"""Shared HTTP download helpers for non-BLS sources."""

from __future__ import annotations

import logging
import time
from pathlib import Path

import httpx

from .. import config

log = logging.getLogger(__name__)


def client() -> httpx.Client:
    return httpx.Client(
        headers={"User-Agent": config.USER_AGENT},
        timeout=config.HTTP_TIMEOUT,
        follow_redirects=True,
    )


def download_file(url: str, dest: Path, *, label: str = "") -> None:
    """Download url to dest with retry/backoff. Skips if dest already exists."""
    if dest.exists():
        log.info("[%s] already cached: %s", label, dest.name)
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    last_exc: Exception | None = None
    for attempt in range(1, config.HTTP_MAX_RETRIES + 1):
        try:
            with client() as c:
                resp = c.get(url)
                resp.raise_for_status()
                dest.write_bytes(resp.content)
                log.info("[%s] downloaded %s (%d bytes)", label, dest.name, len(resp.content))
                return
        except httpx.HTTPError as exc:
            last_exc = exc
            wait = min(2 ** attempt, 30)
            log.warning("[%s] GET %s failed (attempt %d/%d): %s — retrying in %ds",
                        label, url, attempt, config.HTTP_MAX_RETRIES, exc, wait)
            time.sleep(wait)
    assert last_exc is not None
    raise last_exc
