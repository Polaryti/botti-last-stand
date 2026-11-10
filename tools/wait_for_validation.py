#!/usr/bin/env python3
"""Publish only after this exact commit passes its branch's push checks."""
import json
import os
import subprocess
import time

def verdict(runs, commit, branch="main"):
    matching = [r for r in runs if r['head_sha'] == commit and r['event'] == 'push' and r['head_branch'] == branch]
    if not matching:
        return False
    latest = max(matching, key=lambda r: r['id'])
    if latest['status'] != 'completed':
        return False
    if latest['conclusion'] != 'success':
        raise RuntimeError(f"Validation did not pass: {latest['html_url']} ({latest['conclusion']})")
    return True

def main():
    commit = os.environ['GITHUB_SHA']
    repo = os.environ['GITHUB_REPOSITORY']
    branch = os.environ.get('GITHUB_REF_NAME', 'main')
    deadline = time.monotonic() + 1500
    while time.monotonic() < deadline:
        data = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repo}/actions/workflows/validate.yml/runs?branch={branch}&event=push&per_page=20'], text=True))
        if verdict(data['workflow_runs'], commit, branch):
            print(f'Full {branch} validation passed for {commit}')
            return
        print('Waiting for this commit to pass the full validation workflow.', flush=True)
        time.sleep(15)
    raise TimeoutError('Validation did not finish; the release will not publish')

if __name__ == '__main__':
    main()
