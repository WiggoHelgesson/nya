#!/usr/bin/env bash
# Kör Sendify-testet åt dig: installerar Deno om det saknas, läser API-nyckel
# från sendify_test.local, kör test_sendify_label.ts
#
# Så här (en gång):
#   1) cp supabase/scripts/sendify_test.local.example supabase/scripts/sendify_test.local
#   2) Öppna sendify_test.local i en editor och klistra in din riktiga SENDIFY_API_KEY
#   3) Kör:
#        bash supabase/scripts/run_test_sendify_label.sh
#      (valfria flaggor efter skriptet, t.ex. --keep-pdf)

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

LOCAL_ENV="$ROOT/supabase/scripts/sendify_test.local"
if [[ -f "$LOCAL_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV"
fi

if [[ -z "${SENDIFY_API_KEY:-}" ]]; then
  echo ""
  echo "Du saknar SENDIFY_API_KEY."
  echo "Gör så här:"
  echo "  cp supabase/scripts/sendify_test.local.example supabase/scripts/sendify_test.local"
  echo "  öppna sendify_test.local och sätt din nyckel på raden export SENDIFY_API_KEY=..."
  echo ""
  exit 1
fi

exec deno run --allow-env --allow-net --allow-read --allow-write --allow-run \
  "$ROOT/supabase/scripts/test_sendify_label.ts" "$@"
