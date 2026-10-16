#!/usr/bin/env bash
# Local quality gate: localisation, static analysis and the test suite.
#
#   tool/check.sh            # l10n + analyze + tests (perf tests skipped)
#   tool/check.sh --perf     # also run the `perf`-tagged time-budget tests
#
# Integration tests need a simulator/emulator and are not run here; see
# docs/TESTING.md.
set -u
cd "$(dirname "$0")/.."

run_perf=0
[[ "${1:-}" == "--perf" ]] && run_perf=1

results=()
failed=0
step() { # name, command...
  local name=$1; shift
  local start=$SECONDS
  echo "==> $name"
  if "$@"; then
    results+=("PASS  $name ($((SECONDS - start))s)")
  else
    results+=("FAIL  $name ($((SECONDS - start))s)")
    failed=1
  fi
}

# Generated localisations are up to date and nothing is untranslated.
l10n_check() {
  local tmp
  tmp=$(mktemp -d)
  cp lib/l10n/app_localizations*.dart "$tmp/"
  flutter gen-l10n >/dev/null || return 1
  local ok=0
  for f in lib/l10n/app_localizations*.dart; do
    if ! cmp -s "$f" "$tmp/$(basename "$f")"; then
      echo "  $f was out of date (regenerated now; commit the result)"
      ok=1
    fi
  done
  rm -rf "$tmp"
  if [[ -f untranslated_messages.json ]] &&
    [[ "$(tr -d '[:space:]' < untranslated_messages.json)" != "{}" ]]; then
    echo "  untranslated messages:"; cat untranslated_messages.json
    ok=1
  fi
  return $ok
}

step "l10n (gen-l10n up to date, no untranslated messages)" l10n_check
step "flutter analyze" flutter analyze --no-pub
step "flutter test (unit + widget)" flutter test --no-pub
if [[ $run_perf == 1 ]]; then
  step "flutter test --tags perf" flutter test --no-pub --tags perf --run-skipped
fi

echo
echo "Summary"
printf '  %s\n' "${results[@]}"
exit $failed
