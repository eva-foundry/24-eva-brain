#!/usr/bin/env python
"""
EVA Brain API discovery runner.

- Opens a logged-in browser session (CDP) or launches a new browser.
- Sends questions sequentially for ungrounded and grounded scenarios.
- Captures screenshots, HTML, network logs, and markdown run logs.

ASCII-only output to avoid encoding issues.
"""

import argparse
import asyncio
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from playwright.async_api import async_playwright, Page, Browser, BrowserContext

DEFAULT_TIMEOUT_MS = 120_000
DEFAULT_STABLE_SECONDS = 3
DEFAULT_POLL_MS = 500


@dataclass
class Scenario:
    name: str
    pre_actions: List[Dict[str, Any]]


def _timestamp() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def _read_text_file(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def _read_questions(path: Path) -> List[str]:
    lines = [ln.strip() for ln in path.read_text(encoding="utf-8").splitlines()]
    return [ln for ln in lines if ln and not ln.startswith("#")]


def _redact_headers(headers: Dict[str, str]) -> Dict[str, str]:
    redacted = {}
    for k, v in headers.items():
        lk = k.lower()
        if lk in ("authorization", "cookie", "set-cookie"):
            redacted[k] = "[REDACTED]"
        elif "token" in lk or "secret" in lk or "key" in lk:
            redacted[k] = "[REDACTED]"
        else:
            redacted[k] = v
    return redacted


def _safe_filename(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9_-]+", "_", value)
    return value[:80].strip("_") or "item"


async def _save_artifacts(page: Page, out_dir: Path, label: str) -> Dict[str, str]:
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = _timestamp()
    screenshot_path = out_dir / f"eva_brain_screenshot_{label}_{stamp}.png"
    html_path = out_dir / f"eva_brain_html_{label}_{stamp}.html"
    await page.screenshot(path=str(screenshot_path), full_page=True)
    html_content = await page.content()
    html_path.write_text(html_content, encoding="utf-8")
    return {"screenshot": str(screenshot_path), "html": str(html_path)}


async def _wait_for_response_stable(
    page: Page,
    response_selector: str,
    timeout_ms: int,
    stable_seconds: int,
    poll_ms: int,
) -> str:
    await page.wait_for_selector(response_selector, timeout=timeout_ms)
    end_time = asyncio.get_event_loop().time() + (timeout_ms / 1000.0)
    last_text = ""
    stable_for = 0.0

    while True:
        current = await page.locator(response_selector).last.inner_text()
        if current == last_text:
            stable_for += poll_ms / 1000.0
        else:
            stable_for = 0.0
            last_text = current

        if stable_for >= stable_seconds:
            return current

        if asyncio.get_event_loop().time() > end_time:
            return last_text

        await asyncio.sleep(poll_ms / 1000.0)


async def _apply_actions(page: Page, actions: List[Dict[str, Any]]) -> None:
    for action in actions:
        kind = action.get("type")
        if kind == "click":
            await page.click(action["selector"], timeout=DEFAULT_TIMEOUT_MS)
        elif kind == "fill":
            await page.fill(action["selector"], action.get("value", ""), timeout=DEFAULT_TIMEOUT_MS)
        elif kind == "select":
            await page.select_option(action["selector"], action.get("value"))
        elif kind == "press":
            await page.press(action["selector"], action.get("key", "Enter"))
        elif kind == "wait_for":
            await page.wait_for_selector(action["selector"], timeout=DEFAULT_TIMEOUT_MS)
        elif kind == "sleep":
            await asyncio.sleep(float(action.get("seconds", 1.0)))
        else:
            raise ValueError(f"Unknown action type: {kind}")


def _default_config() -> Dict[str, Any]:
    return {
        "chat_input_selector": "textarea, input[type='text']",
        "send_button_selector": "button[type='submit'], button[aria-label='Send']",
        "response_selector": "div[role='article'], .answer, .result, .response",
        "ungrounded_pre_actions": [],
        "grounded_pre_actions": [],
        "response_stable_seconds": DEFAULT_STABLE_SECONDS,
        "response_poll_ms": DEFAULT_POLL_MS,
    }


def _load_config(path: Optional[Path]) -> Dict[str, Any]:
    cfg = _default_config()
    if path and path.exists():
        cfg.update(json.loads(path.read_text(encoding="utf-8")))
    return cfg


async def _run_scenario(
    page: Page,
    scenario: Scenario,
    cfg: Dict[str, Any],
    context_text: str,
    questions: List[str],
    out_dir: Path,
    network_log: List[Dict[str, Any]],
) -> None:
    log_path = out_dir / f"eva_brain_run_{scenario.name}_{_timestamp()}.md"
    log_lines = []

    log_lines.append(f"# EVA Brain Run Log - {scenario.name}\n")
    log_lines.append(f"- Timestamp: {_timestamp()}\n")

    await _apply_actions(page, scenario.pre_actions)

    input_selector = cfg["chat_input_selector"]
    send_selector = cfg["send_button_selector"]
    response_selector = cfg["response_selector"]

    for idx, question in enumerate(questions, start=1):
        q_label = f"{scenario.name}_q{idx}"
        start = datetime.now()
        await _save_artifacts(page, out_dir, f"{q_label}_before")

        await page.fill(input_selector, "")
        await page.fill(input_selector, question)

        # If send button exists, click. Otherwise press Enter.
        try:
            await page.click(send_selector, timeout=3000)
        except Exception:
            await page.press(input_selector, "Enter")

        answer = await _wait_for_response_stable(
            page,
            response_selector,
            DEFAULT_TIMEOUT_MS,
            int(cfg["response_stable_seconds"]),
            int(cfg["response_poll_ms"]),
        )

        end = datetime.now()
        await _save_artifacts(page, out_dir, f"{q_label}_after")

        duration = (end - start).total_seconds()

        log_lines.append(f"## Question {idx}\n")
        log_lines.append(f"- Start: {start.isoformat()}\n")
        log_lines.append(f"- End: {end.isoformat()}\n")
        log_lines.append(f"- Duration seconds: {duration:.2f}\n")
        log_lines.append("\n### Prompt\n")
        log_lines.append(f"{question}\n")
        log_lines.append("\n### Response\n")
        log_lines.append(f"{answer}\n")

    # Append network summary
    log_lines.append("\n## Network Summary\n")
    for item in network_log:
        log_lines.append(f"- {item.get('method')} {item.get('url')} [{item.get('status')}]\n")

    log_path.write_text("\n".join(log_lines), encoding="utf-8")


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True, help="Site URL to open")
    parser.add_argument("--context-file", required=True, help="Plain text scenario context")
    parser.add_argument("--questions-file", required=True, help="Plain text questions, one per line")
    parser.add_argument("--output-dir", required=True, help="Output directory for logs and artifacts")
    parser.add_argument("--config", help="Optional JSON config for selectors and actions")
    parser.add_argument("--connect", help="CDP websocket URL (use existing logged-in browser)")
    parser.add_argument("--headed", action="store_true", help="Run browser in headed mode when launching")
    parser.add_argument("--record-har", action="store_true", help="Record HAR when launching a new browser")
    args = parser.parse_args()

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    context_text = _read_text_file(Path(args.context_file))
    questions = _read_questions(Path(args.questions_file))
    cfg = _load_config(Path(args.config)) if args.config else _default_config()

    network_log: List[Dict[str, Any]] = []

    async with async_playwright() as p:
        browser: Optional[Browser] = None
        context: Optional[BrowserContext] = None

        if args.connect:
            browser = await p.chromium.connect_over_cdp(args.connect)
            if browser.contexts:
                context = browser.contexts[0]
            else:
                context = await browser.new_context()
        else:
            launch = await p.chromium.launch(headless=not args.headed)
            if args.record_har:
                context = await launch.new_context(record_har_path=str(out_dir / f"eva_brain_{_timestamp()}.har"))
            else:
                context = await launch.new_context()
            browser = launch

        page = await context.new_page()

        def on_request(request):
            network_log.append({
                "url": request.url,
                "method": request.method,
                "request_headers": _redact_headers(request.headers),
                "type": request.resource_type,
            })

        async def on_response(response):
            entry = {
                "url": response.url,
                "status": response.status,
                "response_headers": _redact_headers(response.headers),
            }
            network_log.append(entry)

        page.on("request", on_request)
        page.on("response", on_response)

        await page.goto(args.url, wait_until="domcontentloaded", timeout=DEFAULT_TIMEOUT_MS)

        # Scenarios
        scenarios = [
            Scenario("ungrounded", cfg.get("ungrounded_pre_actions", [])),
            Scenario("grounded", cfg.get("grounded_pre_actions", [])),
        ]

        # Attach context as a preamble note to the log by creating a context file in output
        (out_dir / f"eva_brain_context_{_timestamp()}.txt").write_text(context_text, encoding="utf-8")

        for scenario in scenarios:
            await _run_scenario(page, scenario, cfg, context_text, questions, out_dir, network_log)

        # Persist network log
        network_path = out_dir / f"eva_brain_network_{_timestamp()}.json"
        network_path.write_text(json.dumps(network_log, indent=2), encoding="utf-8")

        if browser:
            await browser.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
