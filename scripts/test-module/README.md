# Test Module (Outside Dev Environment)

This module deploys Zabbix containers, collects detailed logs, and analyzes them
outside the development environment. It can run with Podman or Docker.

## Install optional dependencies

```bash
python3 -m pip install -r scripts/test-module/requirements.txt
```

## Usage

```bash
# Build + start + collect logs + analyze
scripts/test-module/run-tests.sh build up

# Only collect logs + analyze
scripts/test-module/run-tests.sh
```

## Outputs

- logs/test_run_<timestamp>/logs/*.log
- logs/test_run_<timestamp>/inspect/*.json
- logs/test_run_<timestamp>/stats/resources.txt
- logs/test_run_<timestamp>/analysis.json
- logs/test_run_<timestamp>/analysis.md
