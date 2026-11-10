#!/usr/bin/env bash
# Builds a Play Store release with an automatic version.
#
#   bash tool/release.sh                 build the bundle as pubspec's version
#   bash tool/release.sh --bump patch    0.1.0 -> 0.1.1 first (minor, major)
#   bash tool/release.sh --apk           an APK instead of the app bundle
#   bash tool/release.sh --skip-checks   without tool/check.sh (not advised)
#
# Version name: the "version:" in pubspec.yaml (only --bump changes it).
# Build number (Android versionCode): the number of commits on HEAD, so every
# release from main gets a higher one without anybody counting. The commit's
# short hash goes into the app (Settings > About shows "… · a1b2c3d").
#
# Refuses to build while the working tree has changes, the publisher's
# details for the legal pages are missing (assets/legal/publisher.json), the
# upload key is not set up (android/key.properties) or the checks fail.
set -euo pipefail

cd "$(dirname "$0")/.."

bump=""
format="appbundle"
checks=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) bump="${2:-}"; shift 2 ;;
    --apk) format="apk"; shift ;;
    --skip-checks) checks=0; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

fail() { echo "release: $*" >&2; exit 1; }

[[ -z "$(git status --porcelain)" ]] || fail "the working tree has changes; commit them first."
branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$branch" == "main" ]] || echo "release: note: building from '$branch', not main." >&2

python3 - <<'PY' || fail "fill in name, address and email in assets/legal/publisher.json (privacy policy, terms, imprint)."
import json, sys
p = json.load(open("assets/legal/publisher.json", encoding="utf-8"))
ok = p.get("name", "").strip() and [a for a in p.get("address", []) if a.strip()] and p.get("email", "").strip()
sys.exit(0 if ok else 1)
PY

[[ -f android/key.properties ]] || fail "android/key.properties is missing (upload key, see README > Release signing)."

current="$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' pubspec.yaml)"
[[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "pubspec.yaml has no version like 1.2.3."

if [[ -n "$bump" ]]; then
  IFS=. read -r major minor patch <<<"$current"
  case "$bump" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) fail "--bump takes major, minor or patch." ;;
  esac
  next="$major.$minor.$patch"
  # The commit that bumps the version counts too.
  build=$(( $(git rev-list --count HEAD) + 1 ))
  sed -i.bak "s/^version: .*/version: $next+$build/" pubspec.yaml && rm pubspec.yaml.bak
  git add pubspec.yaml
  git commit -q -m "chore(release): $next"
  current="$next"
  echo "release: version $next"
fi

build="$(git rev-list --count HEAD)"
commit="$(git rev-parse --short HEAD)"

if [[ "$checks" == 1 ]]; then
  bash tool/check.sh
fi

python3 tool/legal/build_pages.py

echo "release: building $current ($build, $commit)"
flutter build "$format" --release \
  --flavor production -t lib/main_production.dart \
  --build-name="$current" --build-number="$build" \
  --dart-define=GIT_COMMIT="$commit"

if [[ "$format" == "appbundle" ]]; then
  out="build/app/outputs/bundle/productionRelease/app-production-release.aab"
else
  out="build/app/outputs/flutter-apk/app-production-release.apk"
fi
echo
echo "release: $out"
echo "release: version $current, build $build, commit $commit"
echo "release: legal web pages in build/legal/ (upload them before submitting)"
if [[ -n "$bump" ]]; then
  echo "release: tag it once it is live:  git tag v$current && git push --tags"
fi
