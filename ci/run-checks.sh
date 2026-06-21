#!/usr/bin/env bash
# Verification suite.
#   Hard gates (require terraform): fmt, validate, terraform test.
#   Optional (skipped if the tool isn't installed): tflint, trivy, checkov.
#   Set STRICT_SECURITY=1 to make trivy/checkov failures gate the run.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

if ! have terraform; then
  echo "ERROR: terraform is not installed. Install it, or run ./validate.sh to use Docker." >&2
  exit 1
fi
echo "==> terraform: $(terraform version | head -1)"

echo "==> terraform fmt (check)"
terraform fmt -check -recursive

echo "==> terraform init (no backend)"
terraform init -backend=false -input=false >/dev/null

echo "==> terraform validate"
terraform validate

if have tflint; then
  echo "==> tflint"
  tflint --init
  tflint --recursive
else
  echo "==> tflint SKIPPED (not installed)"
fi

echo "==> terraform test (mocked, offline)"
terraform test

if have trivy; then
  echo "==> trivy config scan"
  trivy config . || { [ "${STRICT_SECURITY:-0}" = "1" ] && exit 1 || echo "   (advisory)"; }
else
  echo "==> trivy SKIPPED (not installed)"
fi

if have checkov; then
  echo "==> checkov"
  checkov -d . --config-file .checkov.yaml || { [ "${STRICT_SECURITY:-0}" = "1" ] && exit 1 || echo "   (advisory)"; }
else
  echo "==> checkov SKIPPED (not installed)"
fi

echo ""
echo "==> done. Hard gates passed."
