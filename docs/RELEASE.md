# Releasing LedgerZero

## Version numbers (automatic)

`bash tool/release.sh` builds the Play bundle and sets the version itself:

* **Version name** (what users see, e.g. 1.2.0): the `version:` in
  `pubspec.yaml`. `--bump patch|minor|major` raises it and commits the
  change (`chore(release): 1.2.1`).
* **Build number** (Android `versionCode`, must grow with every upload): the
  number of commits on `HEAD` (`git rev-list --count HEAD`). Every release
  from `main` gets a higher one without anybody counting. Do not rewrite
  `main`'s history (it would lower the count); build releases from `main`.
* **Commit:** the short hash is compiled in (`--dart-define=GIT_COMMIT`) and
  shown in Settings and About next to the version: "Version 1.2.0 (build
  642) · a1b2c3d".

The script refuses to build while the working tree has changes, the
publisher's details for the legal pages are missing, or
`android/key.properties` is not there; it runs `tool/check.sh` first
(`--skip-checks` to leave it out) and writes the legal web pages.
`--apk` builds an APK instead of the bundle. Debug and `flutter run` builds
keep the pubspec's version (build 1).

## Legal pages

The privacy policy, the terms of use and the imprint are bundled with the
app (`assets/legal/*_en.md`, `*_de.md`) and shown in Settings (and About) in
the app's language; they work offline.

* **Publisher:** `assets/legal/publisher.json` holds the name, the postal
  address (one line per entry), the email and, optionally, phone and VAT ID.
  Every page takes them from there. While name, address or email is empty
  the pages show "[to be added]", the imprint entry is hidden, and
  `tool/release.sh` refuses to build.
* **Web pages:** `python3 tool/legal/build_pages.py` writes the same texts as
  self-contained HTML to `build/legal/` (EN and DE, an index page). Upload
  them anywhere static (GitHub Pages, Netlify, your web space) and enter the
  privacy page's URL in the Play Console (App content > Privacy policy).
* **Content:** the texts describe what the app does (data on the phone only,
  card notifications, Wi-Fi sync, camera for pairing, backups and Android
  backup, Google Play for purchases, statistics and ratings) under the GDPR
  and German law (§ 5 DDG imprint). They are a careful draft, not legal
  advice: have them checked before the first release, and update
  `effectiveDate` when they change.

## Icons

`python3 tool/icons/generate_icons.py` (needs Pillow) makes every icon from
one geometry, a "0" with three ledger lines in white on the teal gradient:

* adaptive launcher icon (vector background and foreground) with a
  monochrome layer for themed icons (Android 13+), plus round and square
  PNGs for Android 7.0 and 7.1;
* the white status-bar icon for notifications (`ic_stat_ledgerzero`, kept
  from resource shrinking by `res/raw/keep.xml`), tinted with the brand
  colour in the notification shade;
* the launch screen logo (before Android 12; 12+ shows the adaptive icon on
  the system splash);
* `store/play_icon_512.png` and `store/feature_graphic.png` for the Play
  listing, and `store/icon_preview.png` to check every variant.

Change the colours or proportions in the script and run it again; do not
edit the generated files.

## Rating prompt

Google Play's in-app review dialog (`in_app_review`) is requested at a good
moment, right after To Be Budgeted reaches zero, and only when it is due:
at least 7 days after the first start, on at least 5 days of use, at most 3
times and at least 120 days apart (`ReviewPrompter`). Google decides whether
the dialog really appears. "Rate LedgerZero" in Settings and About opens the
Play Store page directly.

## Checklist for an upload

1. `assets/legal/publisher.json` filled in, legal texts checked.
2. `bash tool/release.sh --bump patch` (or minor) on `main`.
3. Upload `build/legal/` and the `.aab`; Pro product set up (docs/PRO.md).
4. After the rollout: `git tag v<version> && git push --tags`.
