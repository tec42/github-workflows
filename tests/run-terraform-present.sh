#!/usr/bin/env bash
#
# tests/run-terraform-present.sh — the self-test of shared/terraform-present.sh, runnable anywhere.
#
# The assertion that matters is the third one: **a repository with no Terraform must not fail.**
# That is the thing a Terraform gate gets wrong first, and the way it gets switched off again.
#
# It lives as a script as well as a workflow because this repository's GitHub Actions currently fail
# at startup for every workflow (a repository setting, not this file): then the evidence is still one
# command away. Same reasoning as tests/run.sh.
#
# Usage: bash tests/run-terraform-present.sh
set -uo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "❌ $*"; exit 1; }

echo "1/4 a directory holding a .tf file is found"
mkdir -p "$tmp/with/nested"
echo 'resource "null_resource" "x" {}' > "$tmp/with/nested/main.tf"
bash shared/terraform-present.sh "$tmp/with" >/dev/null \
  || fail "a directory with a nested .tf was reported as empty"

echo "2/4 a directory holding no .tf file is not found"
mkdir -p "$tmp/without"
echo 'not terraform' > "$tmp/without/README.md"
if bash shared/terraform-present.sh "$tmp/without" >/dev/null; then
  fail "a directory with no .tf was reported as holding terraform"
fi

echo "3/4 a missing directory is not an error to the caller, only a 'no'"
if bash shared/terraform-present.sh "$tmp/nothing-here" >/dev/null; then
  fail "a missing directory was reported as holding terraform"
fi

echo "4/4 this repository's own answer is 'no' — it carries no service terraform"
if bash shared/terraform-present.sh terraform >/dev/null; then
  fail "github-workflows was reported as holding service terraform"
fi

echo
echo "✅ all four assertions hold"
