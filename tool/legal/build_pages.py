#!/usr/bin/env python3
"""Builds web pages of the legal texts the app bundles (assets/legal/).

Google Play needs the privacy policy at a public URL. This writes plain,
self-contained HTML pages (no scripts, no external requests) to
build/legal/, ready to upload to any static host (GitHub Pages, Netlify,
your own web space):

  index.html            links to all pages
  privacy.html  privacy-de.html
  terms.html    terms-de.html
  imprint.html  imprint-de.html

The text and the publisher's details (assets/legal/publisher.json) are the
same as in the app; edit those files, not the output. Run from the
repository root:  python3 tool/legal/build_pages.py
"""

import html
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEGAL = os.path.join(ROOT, "assets", "legal")
OUT = os.path.join(ROOT, "build", "legal")

DOCUMENTS = ("privacy", "terms", "imprint")


def load_publisher():
    with open(os.path.join(LEGAL, "publisher.json"), encoding="utf-8") as f:
        p = json.load(f)
    return {
        "name": p.get("name", "").strip(),
        "address": [a.strip() for a in p.get("address", []) if a.strip()],
        "email": p.get("email", "").strip(),
        "phone": p.get("phone", "").strip(),
        "vatId": p.get("vatId", "").strip(),
        "effectiveDate": p.get("effectiveDate", "").strip(),
    }


def is_complete(p):
    return bool(p["name"] and p["address"] and p["email"])


def fill(text, p, language):
    """The same fields as LegalTexts.fill in the app."""
    de = language == "de"
    missing = "[wird ergänzt]" if de else "[to be added]"

    def ok(v):
        return v or missing

    block = [ok(p["name"])] + (p["address"] or [missing])
    block.append(("E-Mail" if de else "Email") + ": " + ok(p["email"]))
    if p["phone"]:
        block.append(("Telefon" if de else "Phone") + ": " + p["phone"])
    if p["vatId"]:
        block.append(("USt-IdNr." if de else "VAT ID") + ": " + p["vatId"])
    fields = {
        "name": ok(p["name"]),
        "email": ok(p["email"]),
        "effectiveDate": ok(p["effectiveDate"]),
        "publisherBlock": "\n".join(block),
    }
    return re.sub(r"\{\{(\w+)\}\}", lambda m: fields.get(m.group(1), m.group(0)), text)


def inline(text):
    out = html.escape(text)
    out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"(https?://[^\s<),]+)", r'<a href="\1">\1</a>', out)
    return out.replace("\n", "<br>\n")


def to_html(text):
    """The Markdown subset of the files: #, ##, - and paragraphs."""
    parts, para, items, title = [], [], [], ""

    def flush():
        if para:
            parts.append("<p>" + inline("\n".join(para)) + "</p>")
            para.clear()
        if items:
            parts.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items.clear()

    for raw in text.splitlines():
        line = raw.rstrip()
        if not line.strip():
            flush()
        elif line.startswith("## "):
            flush()
            parts.append(f"<h2>{inline(line[3:].strip())}</h2>")
        elif line.startswith("# "):
            flush()
            title = line[2:].strip()
            parts.append(f"<h1>{inline(title)}</h1>")
        elif line.startswith("- "):
            if para:
                flush()
            items.append(line[2:].strip())
        else:
            if items:
                flush()
            para.append(line.strip())
    flush()
    return title, "\n".join(parts)


PAGE = """<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · LedgerZero</title>
<style>
  :root {{ color-scheme: light dark; --fg: #1b1f1e; --muted: #56605e; --bg: #ffffff; --accent: #00796b; }}
  @media (prefers-color-scheme: dark) {{ :root {{ --fg: #e3e8e6; --muted: #a9b3b0; --bg: #121514; --accent: #4db6ac; }} }}
  body {{ margin: 0; background: var(--bg); color: var(--fg);
         font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }}
  main {{ max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }}
  h1 {{ font-size: 1.8rem; line-height: 1.25; margin: 0 0 8px; }}
  h2 {{ font-size: 1.15rem; margin: 28px 0 6px; }}
  a {{ color: var(--accent); }}
  nav {{ font-size: .9rem; color: var(--muted); margin-bottom: 24px; }}
  li {{ margin-bottom: 6px; }}
</style>
</head>
<body>
<main>
<nav><a href="index.html">LedgerZero</a> · {switch}</nav>
{body}
</main>
</body>
</html>
"""


def main():
    p = load_publisher()
    os.makedirs(OUT, exist_ok=True)
    links = []
    for doc in DOCUMENTS:
        if doc == "imprint" and not is_complete(p):
            print("Imprint skipped: fill in name, address and email in assets/legal/publisher.json.")
            continue
        for lang in ("en", "de"):
            with open(os.path.join(LEGAL, f"{doc}_{lang}.md"), encoding="utf-8") as f:
                title, body = to_html(fill(f.read(), p, lang))
            name = f"{doc}.html" if lang == "en" else f"{doc}-de.html"
            other = f"{doc}-de.html" if lang == "en" else f"{doc}.html"
            switch = f'<a href="{other}">{"Deutsch" if lang == "en" else "English"}</a>'
            with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
                f.write(PAGE.format(lang=lang, title=html.escape(title), switch=switch, body=body))
            links.append((title, name, lang))
    items = "".join(f'<li><a href="{n}">{html.escape(t)}</a> ({l.upper()})</li>' for t, n, l in links)
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
        f.write(PAGE.format(lang="en", title="Legal", switch="", body=f"<h1>LedgerZero</h1><ul>{items}</ul>"))
    if not is_complete(p):
        print("Warning: publisher details are incomplete; the pages show placeholders.", file=sys.stderr)
    print(f"Pages written to {os.path.relpath(OUT, ROOT)}/")


if __name__ == "__main__":
    main()
