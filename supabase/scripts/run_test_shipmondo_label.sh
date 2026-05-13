#!/usr/bin/env bash
# Kör Shipmondo CLI-testet: läser SHIPMONDO_API_USER / SHIPMONDO_API_KEY från
# shipmondo_test.local (se shipmondo_test.local.example).
#
#   bash supabase/scripts/run_test_shipmondo_label.sh
# Valfria flaggor skickas vidare, t.ex. --keep-pdf --carrier dhl

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if ! command -v deno &>/dev/null; then
  DENO_INSTALL="${DENO_INSTALL:-$HOME/.deno}"
  if [[ -x "$DENO_INSTALL/bin/deno" ]]; then
    export PATH="$DENO_INSTALL/bin:$PATH"
  fi
fi

if ! command -v deno &>/dev/null; then
  echo "Deno finns inte — installerar till ~/.deno (officiellt skript, en gång)…"
  if ! command -v curl &>/dev/null; then
    echo "Fel: behöver curl. Installera från https://deno.land eller: brew install deno"
    exit 1
  fi
  curl -fsSL https://deno.land/install.sh | sh
  export DENO_INSTALL="${DENO_INSTALL:-$HOME/.deno}"
  export PATH="$DENO_INSTALL/bin:$PATH"
fi

LOCAL_ENV="$ROOT/supabase/scripts/shipmondo_test.local"
if [[ -f "$LOCAL_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV"
fi

if [[ -z "${SHIPMONDO_API_USER:-}" || -z "${SHIPMONDO_API_KEY:-}" ]]; then
  echo ""
  echo "Saknar SHIPMONDO_API_USER och/eller SHIPMONDO_API_KEY."
  echo "Gör så här:"
  echo "  cp supabase/scripts/shipmondo_test.local.example supabase/scripts/shipmondo_test.local"
  echo "  redigera shipmondo_test.local och sätt båda variablerna."
  echo ""
  exit 1
fi

exec deno run --allow-env --allow-net --allow-read --allow-write --allow-run \
  "$ROOT/supabase/scripts/test_shipmondo_label.ts" "$@"
