# CI (GitHub Actions) templates

This folder contains **templates** to help you run the RM validation gates in CI.

## What this provides

- A GitHub Actions workflow template that:
  - runs the **prepack gate** (`prepack_gate_validate.py`) as a **matrix per module**
  - uploads gate summaries + QA reports as artifacts
  - (on PRs) posts/updates a **single PR comment** with a combined gate summary
  - optionally posts a **webhook notification** (Slack/Discord/email gateway) on **FAIL**

## How to use

1) Copy the workflow template:
- `DATA/QA/CI/github_actions_rm_prepack_gate.yml`
  → `.github/workflows/rm_prepack_gate.yml`

2) Ensure your repo has the module folders at root:
- `RM_CORE/`
- `RM_ACT1/`
- `RM_QA/`
- `RM_ART/`
- `RM_LEGACY/`

3) The workflow will:
- fail the build if the gate prints `PREPACK_GATE: FAIL`
- upload `gate_<MODULE>.md` and `RM_QA/DATA/QA/RPT_*.csv` artifacts (even on failure)
- send an **optional webhook** (set `secrets.RM_NOTIFY_WEBHOOK`) with a short JSON summary when a matrix leg fails

## Status badge (optional)

Add this to your repo `README.md` (update org/repo + workflow filename if you changed it):

```md
![RM Prepack Gate](https://github.com/<ORG>/<REPO>/actions/workflows/rm_prepack_gate.yml/badge.svg)
```

## Notes

- The templates assume the **module folders**, not the module ZIPs.
- Python caching is enabled via `actions/setup-python` (`cache: pip`). No extra requirements are needed for the gate itself.
