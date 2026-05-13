#!/usr/bin/env bash
# Kor prepopulate_exercise_gifs.ts. Laser SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY
# fran exercise_gifs.local (samma monster som shipmondo_test.local).
#
#   bash supabase/scripts/run_prepopulate_exercise_gifs.sh
# Valfria env-overrides:
#   THROTTLE_MS=300 LIMIT=50 START_INDEX=200 bash ...
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
  echo "Deno finns inte. Installerar till ~/.deno..."
  if ! command -v curl &>/dev/null; then
    echo "Fel: behover curl. Installera fran https://deno.land eller: brew install deno"
    exit 1
  fi
  curl -fsSL https://deno.land/install.sh | sh
  export DENO_INSTALL="${DENO_INSTALL:-$HOME/.deno}"
  export PATH="$DENO_INSTALL/bin:$PATH"
fi

LOCAL_ENV="$ROOT/supabase/scripts/exercise_gifs.local"
if [[ -f "$LOCAL_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV"
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo ""
  echo "Saknar SUPABASE_URL och/eller SUPABASE_SERVICE_ROLE_KEY."
  echo "Skapa $LOCAL_ENV med innehallet:"
  echo "  export SUPABASE_URL=\"https://xebatkodviqgkpsbyuiv.supabase.co\""
  echo "  export SUPABASE_SERVICE_ROLE_KEY=\"...\""
  echo ""
  exit 1
fi

export SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY

exec deno run --allow-env --allow-net --allow-read --allow-write \
  "$ROOT/supabase/scripts/prepopulate_exercise_gifs.ts" "$@"
