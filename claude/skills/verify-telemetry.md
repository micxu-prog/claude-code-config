---
name: verify-telemetry
description: Verify telemetry data arrived in Prometheus/Tempo after sending metrics or spans. Run this proactively after any simulate script, test build, or manual telemetry send to confirm data landed. Auto-detects environment (dev/prod/test) or accepts explicit argument.
when_to_use: After running simulate scripts, after sending telemetry data, after test builds on Windows VDI, after any command that sends metrics or spans to the GFW telemetry pipeline. Should be invoked proactively without waiting for the user to ask.
---

Run the verification script:

```bash
~/.claude/hooks/verify-telemetry.sh [dev|prod|test]
```

If environment is not specified, default to `dev`.

Wait ~30-60 seconds after data is sent before running (Prometheus scrape interval is 15s, plus OTLP export delay).

Report the results to the user. If checks fail, suggest:
- Data may still be in transit (wait and retry)
- Stale series (CLI data goes stale after 5 min of no new scrapes)
- Wrong environment (check if .env points to DEV vs PROD)
- Token issues (check if GFW_TELEMETRY_NVAUTH_TOKEN is set)
