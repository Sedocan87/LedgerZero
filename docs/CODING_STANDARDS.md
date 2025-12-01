# Coding Standards

## Internationalization (L10n)

**Rule:** Never hardcode text like `Text("Budget")` in widgets. Always use `Text(AppLocalizations.of(context)!.budget)`.

**Why:** It allows you to switch languages instantly and handles date formats automatically.
