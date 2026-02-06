#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from urllib.request import Request, urlopen


DEFAULT_SOURCE_URL = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"


def fetch_json(url):
    req = Request(url, headers={"User-Agent": "OllamaBotPricing/1.0"})
    with urlopen(req, timeout=30) as resp:
        if resp.status != 200:
            raise RuntimeError(f"Failed to fetch {url} (status {resp.status})")
        return json.loads(resp.read().decode("utf-8"))


def normalize(value):
    return value.strip().lower()


def split_provider(model_name):
    if "/" in model_name:
        provider, model = model_name.split("/", 1)
        return normalize(provider), normalize(model)
    lower = normalize(model_name)
    if "claude" in lower:
        return "anthropic", lower
    if lower.startswith("gpt-") or lower.startswith("o1-") or "gpt" in lower:
        return "openai", lower
    if "gemini" in lower:
        return "gemini", lower
    if "command-r" in lower or "cohere" in lower:
        return "cohere", lower
    if "mistral" in lower:
        return "mistral", lower
    if "groq" in lower:
        return "groq", lower
    if "perplexity" in lower or lower.startswith("pplx"):
        return "perplexity", lower
    if "together" in lower:
        return "together", lower
    if "fireworks" in lower:
        return "fireworks", lower
    return "unknown", lower


def build_catalog(raw, source_name, source_url):
    providers = {}
    for model_name, info in raw.items():
        input_cost = info.get("input_cost_per_token")
        output_cost = info.get("output_cost_per_token")
        if input_cost is None and output_cost is None:
            continue
        try:
            input_cost = float(input_cost or 0.0)
            output_cost = float(output_cost or 0.0)
        except (TypeError, ValueError):
            continue
        provider, model = split_provider(model_name)
        providers.setdefault(provider, {})
        providers[provider][model] = {
            "inputPer1K": round(input_cost * 1000.0, 8),
            "outputPer1K": round(output_cost * 1000.0, 8),
            "currency": "USD",
            "source": source_name
        }
    return providers


def main():
    parser = argparse.ArgumentParser(description="Update OllamaBot pricing catalog.")
    parser.add_argument("--url", default=DEFAULT_SOURCE_URL)
    parser.add_argument("--output", default="")
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    output_path = args.output
    if not output_path:
        config_dir = os.path.join(os.path.expanduser("~"), ".config", "ollamabot")
        os.makedirs(config_dir, exist_ok=True)
        output_path = os.path.join(config_dir, "pricing.json")

    started = time.time()
    raw = fetch_json(args.url)
    providers = build_catalog(raw, "litellm", args.url)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    payload = {
        "version": 1,
        "updatedAt": timestamp,
        "sources": [
            {
                "name": "litellm",
                "url": args.url,
                "fetchedAt": timestamp
            }
        ],
        "providers": providers
    }

    with open(output_path, "w", encoding="utf-8") as f:
        if args.pretty:
            json.dump(payload, f, indent=2)
        else:
            json.dump(payload, f)

    elapsed = time.time() - started
    print(f"Pricing catalog updated: {output_path}")
    print(f"Providers: {len(providers)} | Time: {elapsed:.2f}s")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
