#!/usr/bin/env bash
# Run the full verification suite locally.
#   - If terraform is on PATH, run directly (lint/security tools used if present).
#   - Otherwise, build and run the pinned container against your live files.
set -euo pipefail
cd "$(dirname "$0")"

if command -v terraform >/dev/null 2>&1; then
  echo ">> Running with local toolchain."
  exec bash ci/run-checks.sh
elif command -v docker >/dev/null 2>&1; then
  echo ">> No local terraform found; using Docker (full toolchain, pinned)."
  docker build -t tf-ci .
  # Bind-mount the live tree and run as the current user so no root-owned
  # files (.terraform/) are left behind on the host.
  exec docker run --rm \
    -e HOME=/tmp \
    -u "$(id -u):$(id -g)" \
    -v "$PWD":/work -w /work \
    tf-ci
else
  echo "ERROR: install Terraform (>=1.7) or Docker to validate locally." >&2
  exit 1
fi
