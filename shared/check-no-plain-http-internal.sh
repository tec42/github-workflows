#!/usr/bin/env bash
#
# check-no-plain-http-internal.sh — fail when a service would talk to another service over plain HTTP.
#
# INVEST-005-EPIC-008-FEATURE-001 phase 0 (Ralf: services talk HTTPS only) moved every internal caller
# to `https://<service>-internal.tec42.io:<tls port>`. The plaintext paths it removed were found by
# reading the code by hand, once. This check is what keeps the next one from being written.
#
# It flags an `http://` URL whose host is an internal address:
#   - a `*-internal.tec42.io` name
#   - the raw NLB name, `*.elb.<region>.amazonaws.com` or `tec42-internal-nlb-*`
#   - an interpolation that resolves to one of those: `${local.…_internal_fqdn}`, `$NLB_DNS`, …
#
# It does NOT flag:
#   - `https://` anything, or a bare port number — phase 0 step 0.6 still names TCP ports legitimately
#   - localhost, 127.0.0.1, 0.0.0.0, a container name in compose, or an example.com host
#   - the public ALB in front of render: that hop is the edge (`http` → `https` redirect), and the
#     inventory in phase 0 step 0.7 puts it out of scope
#   - a line marked `plaintext-ok: <reason>` — the escape hatch, with the reason in the line itself
#
# Usage: check-no-plain-http-internal.sh [root]      (default: the current directory)
set -uo pipefail

ROOT=${1:-.}

# The reusable workflow checks this repository out into `.ci-shared` inside the caller's workspace, so
# the scan would otherwise walk this script's own test fixtures — which contain planted plaintext URLs
# on purpose — and fail every caller. Prune the directory this script lives in whenever it is inside
# the tree being scanned.
SELF_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ROOT_ABS=$(cd -- "$ROOT" && pwd)
PRUNE=()
if [[ $SELF_DIR == "$ROOT_ABS"/* ]]; then
  PRUNE=(-path "${SELF_DIR#"$ROOT_ABS"/}" -prune -o -path "./${SELF_DIR#"$ROOT_ABS"/}" -prune -o)
fi

# Files where an internal address can end up: terraform, and the workflows that build environments.
mapfile -t FILES < <(
  find "$ROOT" \
    "${PRUNE[@]}" \
    -path '*/node_modules' -prune -o \
    -path '*/.git' -prune -o \
    -path '*/.terraform' -prune -o \
    -path '*/.ci-shared' -prune -o \
    -type f \( -name '*.tf' -o -name '*.tfvars' -o -name '*.yml' -o -name '*.yaml' \) -print \
  | grep -E '\.tf$|\.tfvars$|/\.github/workflows/[^/]+\.ya?ml$' \
  | sort
)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No terraform or workflow files under $ROOT — nothing to check."
  exit 0
fi

# An http:// URL whose host is internal. The host alternatives are deliberately narrow: a pattern that
# also matched, say, every `${var.something}` would be noise rather than a guard.
PATTERN='http://[^"'"'"' ]*('\
'[A-Za-z0-9_.-]*-internal\.tec42\.io|'\
'[A-Za-z0-9_.-]*\.elb\.[a-z0-9-]*\.?amazonaws\.com|'\
'tec42-internal-nlb|'\
'\$\{?[A-Za-z0-9_.]*([Nn][Ll][Bb][_A-Za-z0-9]*[Dd][Nn][Ss]|internal_fqdn|INTERNAL_FQDN)[A-Za-z0-9_.]*\}?'\
')'

found=0
for f in "${FILES[@]}"; do
  while IFS=: read -r line text; do
    [[ -z ${line:-} ]] && continue
    # The escape hatch: the reason has to stand on the line it excuses.
    if [[ $text == *plaintext-ok:* ]]; then
      continue
    fi
    echo "❌ ${f#"$ROOT"/}:$line: plain HTTP to an internal address"
    echo "   ${text#"${text%%[![:space:]]*}"}"
    found=1
  done < <(grep -nE "$PATTERN" "$f" || true)
done

if [[ $found -eq 1 ]]; then
  cat <<'EOF'

Services talk HTTPS only (INVEST-005-EPIC-008-FEATURE-001 phase 0).
Use the name the NLB listener's certificate covers and its TLS port, for example
  https://vehicle-manager-internal.tec42.io:3052/api/v1
read from remote state where an output exists. If a line is genuinely allowed to be plain HTTP,
mark it with `plaintext-ok: <reason>` and say why.
EOF
  exit 1
fi

echo "✅ ${#FILES[@]} terraform and workflow files: no plain HTTP to an internal address."
