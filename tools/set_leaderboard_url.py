#!/usr/bin/env python3
"""Point a build at its channel's leaderboard, during CI only.

Dev builds use the Worker "botti-board-dev" and production builds "botti-board". Their address is
https://<worker>.<account subdomain>.workers.dev; the account's subdomain is read from Cloudflare
with the same token the deploy workflow uses (CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID).
Without those secrets nothing is written, and the game's leaderboard says it isn't set up.
"""

import argparse
import json
import os
from pathlib import Path
import re
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
WORKERS = {"dev": "botti-board-dev", "production": "botti-board"}


def subdomain(account: str, token: str) -> str:
    request = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4/accounts/{account}/workers/subdomain",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.load(response)
    name = (data.get("result") or {}).get("subdomain", "")
    if not data.get("success") or not re.fullmatch(r"[a-z0-9-]+", name):
        raise RuntimeError("Cloudflare did not return a workers.dev subdomain. Open Workers & Pages once in the Cloudflare dashboard to create it.")
    return name


def address(channel: str, account: str, token: str) -> str:
    return f"https://{WORKERS[channel]}.{subdomain(account, token)}.workers.dev"


def write(project: Path, url: str) -> None:
    text = project.read_text()
    line = f"leaderboard_url={json.dumps(url)}"
    match = re.search(r"^\[botti\]\n(.*?)(?=^\[|\Z)", text, re.M | re.S)
    if match is None:
        text = text.rstrip() + f"\n\n[botti]\n\n{line}\n"
    else:
        body = match.group(1)
        if re.search(r"^leaderboard_url=.*$", body, re.M):
            body = re.sub(r"^leaderboard_url=.*$", lambda _: line, body, flags=re.M)
        else:
            body = body.rstrip() + f"\n{line}\n\n"
        text = text[:match.start(1)] + body + text[match.end(1):]
    project.write_text(text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("channel", choices=sorted(WORKERS))
    parser.add_argument("--project-dir", type=Path, default=ROOT)
    parser.add_argument("--print-only", action="store_true", help="print the address without changing the project")
    args = parser.parse_args()
    token = os.environ.get("CLOUDFLARE_API_TOKEN", "")
    account = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "")
    if not token or not account:
        print("::warning::No Cloudflare secrets: this build has no leaderboard.")
        raise SystemExit(0)
    try:
        url = address(args.channel, account, token)
    except Exception as error:  # The game still builds; its leaderboard says it isn't set up.
        print(f"::warning::Could not find the leaderboard's address, so this build has none: {error}")
        raise SystemExit(0)
    if args.print_only:
        print(url)
    else:
        write(args.project_dir / "project.godot", url)
        print(f"Leaderboard for {args.channel}: {url}")
        out = os.environ.get("GITHUB_OUTPUT")
        if out:
            with open(out, "a") as handle:
                handle.write(f"leaderboard_url={url}\n")
    sys.exit(0)
