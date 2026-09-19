#!/usr/bin/env bash
#
# tests/run.sh — the self-test of shared/check-no-plain-http-internal.sh, runnable anywhere.
#
# The same two assertions the workflow makes: the allowed fixture passes, and the planted one fails
# with all four lines named. It lives as a script as well as a workflow because this repository's
# GitHub Actions currently fail at startup for every workflow (a repository setting, not this file):
# then the evidence is still one command away.
#
# Usage: bash tests/run.sh
set -uo pipefail
cd "$(dirname "$0")/.."

fail() { echo "❌ $*"; exit 1; }

echo "1/2 the allowed fixture must pass"
bash shared/check-no-plain-http-internal.sh tests/fixtures/pass || fail "the allowed fixture was flagged"

echo
echo "2/2 the planted fixture must fail, naming every line"
output=$(bash shared/check-no-plain-http-internal.sh tests/fixtures/fail)
status=$?
echo "$output"
[[ $status -ne 0 ]] || fail "the check passed on the planted fixture — it would not catch the mistake"
for expected in 'main.tf:3' 'main.tf:5' 'main.tf:7' '.github/workflows/deploy.yml:5'; do
  grep -q "$expected" <<<"$output" || fail "the check missed $expected"
done

echo
echo "✅ both fixtures behaved as expected"
