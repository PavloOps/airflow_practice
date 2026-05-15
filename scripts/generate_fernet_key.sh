#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from cryptography.fernet import Fernet

print(Fernet.generate_key().decode())
PY
