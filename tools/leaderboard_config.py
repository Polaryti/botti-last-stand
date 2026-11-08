#!/usr/bin/env python3
"""Generate the Epic portal configuration reference from the game's stable profession keys."""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def configuration():
    source = (ROOT / 'scripts/leaderboard.gd').read_text()
    block = re.search(r'const PAIRS: Array\[String\] = \[(.*?)\]', source, re.S).group(1)
    pairs = re.findall(r'"([^\"]+)"', block)
    if len(pairs) != len(set(pairs)):
        raise ValueError('Duplicate leaderboard profession key')
    channels = []
    for prefix, channel in [('BLS_DEV_', 'development'), ('BLS_', 'production')]:
        stats = [prefix + 'POINTS'] + [prefix + 'PLAY_' + pair.replace('|', '_').upper() for pair in pairs]
        channels.append({'channel': channel,
                         'stats': [{'name': name, 'aggregation': 'MAX'} for name in stats],
                         'leaderboard': {'name': prefix + 'LIFETIME', 'stat': prefix + 'POINTS',
                                         'sort': 'descending', 'aggregation': 'MAX', 'end_date': None}})
    return {'purpose': 'Epic Developer Portal configuration reference', 'channels': channels}


if __name__ == '__main__':
    target = ROOT / 'config/epic-leaderboards.json'
    target.parent.mkdir(exist_ok=True)
    target.write_text(json.dumps(configuration(), indent=2) + '\n')
    print(target)
