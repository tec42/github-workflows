#!/usr/bin/env bash
#
# shared/terraform-present.sh — is there any Terraform here to check?
#
# Used by reusable-terraform-check.yml (INVEST-005-EPIC-017-FEATURE-002-US-033, phase 1) to decide
# whether to run `fmt` and `validate` at all.
#
# **A service with no Terraform is not a failure, it is a service with no Terraform.** Callers
# normally trigger the check from a path filter, so it only runs when a `.tf` file changed — but a
# repository that calls it unconditionally, or one whose Terraform lives elsewhere, must not go red
# for having nothing to check.
#
# It lives as a script rather than four lines inside the YAML so that it can be *tested*: this
# repository's GitHub Actions currently fail at startup for every workflow (a repository setting,
# not these files), so a check whose only proof is a green run has no proof at all. See
# tests/run-terraform-present.sh, and the same reasoning in tests/run.sh.
#
# Usage: bash shared/terraform-present.sh <directory>
#   exit 0 — at least one *.tf exists under <directory>
#   exit 1 — the directory is missing, or holds no *.tf
set -uo pipefail

dir="${1:-terraform}"

if [ ! -d "$dir" ]; then
  echo "no such directory: $dir"
  exit 1
fi

# `-print -quit` stops at the first hit: a repository with a large Terraform tree should not be
# walked in full just to answer "is there any".
if [ -z "$(find "$dir" -name '*.tf' -print -quit)" ]; then
  echo "no *.tf under: $dir"
  exit 1
fi

echo "terraform found under: $dir"
exit 0
