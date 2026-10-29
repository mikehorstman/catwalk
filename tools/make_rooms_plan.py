#!/usr/bin/env python3
"""Turns the rooms plan (markdown) into docs/plan-rooms.html.

Edit the markdown in .hermes/plans/, not the HTML. Run: python3 tools/make_rooms_plan.py
"""
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = sorted((ROOT / ".hermes" / "plans").glob("*rooms-decorations-gifts.md"))[-1]
OUT = ROOT / "docs" / "plan-rooms.html"


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![*\w])\*([^*\n]+)\*(?![*\w])", r"<em>\1</em>", text)
    return text


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def table(lines):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lines]
    head, body = rows[0], rows[2:]
    out = ["<div class='tw'><table><thead><tr>"]
    out += [f"<th>{inline(c)}</th>" for c in head]
    out.append("</tr></thead><tbody>")
    for r in body:
        out.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>")
    out.append("</tbody></table></div>")
    return "".join(out)


def convert(md: str):
    lines = md.split("\n")
    out, toc = [], []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("```"):
            j = i + 1
            block = []
            while j < len(lines) and not lines[j].startswith("```"):
                block.append(lines[j])
                j += 1
            out.append("<pre>" + html.escape("\n".join(block)) + "</pre>")
            i = j + 1
            continue
        if line.startswith("|"):
            j = i
            while j < len(lines) and lines[j].startswith("|"):
                j += 1
            out.append(table(lines[i:j]))
            i = j
            continue
        m = re.match(r"^(#{1,4}) (.*)", line)
        if m:
            level, text = len(m.group(1)), m.group(2)
            sid = slug(text)
            if level in (2, 3):
                toc.append((level, text, sid))
            out.append(f"<h{level} id='{sid}'>{inline(text)}</h{level}>")
            i += 1
            continue
        if line.strip() == "---":
            out.append("<hr>")
            i += 1
            continue
        if line.startswith(">"):
            j = i
            quote = []
            while j < len(lines) and lines[j].startswith(">"):
                quote.append(lines[j].lstrip("> ").rstrip())
                j += 1
            out.append("<blockquote>" + inline(" ".join(quote)) + "</blockquote>")
            i = j
            continue
        if re.match(r"^\s*([-*]|\d+\.) ", line):
            ordered = bool(re.match(r"^\s*\d+\. ", line))
            tag = "ol" if ordered else "ul"
            items = []
            j = i
            while j < len(lines) and (
                re.match(r"^\s*([-*]|\d+\.) ", lines[j]) or re.match(r"^\s{2,}\S", lines[j])
            ):
                if re.match(r"^\s*([-*]|\d+\.) ", lines[j]):
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    text = re.sub(r"^\s*([-*]|\d+\.) ", "", lines[j])
                    items.append([indent, text])
                else:
                    items[-1][1] += " " + lines[j].strip()
                j += 1
            html_items = []
            for indent, text in items:
                cls = " class='sub'" if indent >= 2 else ""
                html_items.append(f"<li{cls}>{inline(text)}</li>")
            out.append(f"<{tag}>" + "".join(html_items) + f"</{tag}>")
            i = j
            continue
        if line.strip() == "":
            i += 1
            continue
        j = i
        para = []
        while j < len(lines) and lines[j].strip() and not re.match(
            r"^(#{1,4} |\||```|>|---|\s*([-*]|\d+\.) )", lines[j]
        ):
            para.append(lines[j].strip())
            j += 1
        out.append("<p>" + inline(" ".join(para)) + "</p>")
        i = j
    return "\n".join(out), toc


CSS = """
:root{--cream:#fbf6ec;--card:#fffdf8;--ink:#23303a;--muted:#6b7780;--sage:#8fae9b;--teal:#3a7d7b;--orange:#e8944a;--line:#e6dccb}
*{box-sizing:border-box}
body{margin:0;background:var(--cream);color:var(--ink);font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
.wrap{display:grid;grid-template-columns:260px minmax(0,1fr);gap:32px;max-width:1240px;margin:0 auto;padding:24px}
nav{position:sticky;top:16px;align-self:start;max-height:calc(100vh - 32px);overflow:auto;font-size:14px;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px}
nav a{display:block;color:var(--ink);text-decoration:none;padding:4px 6px;border-radius:8px}
nav a:hover{background:#f1e9d9}
nav a.l3{padding-left:20px;color:var(--muted);font-size:13px}
nav b{display:block;margin:0 0 8px;color:var(--teal)}
main{min-width:0}
h1{font-size:34px;line-height:1.15;margin:8px 0 16px}
h2{font-size:25px;margin:44px 0 12px;padding-top:10px;border-top:2px solid var(--line);color:var(--teal)}
h3{font-size:19px;margin:30px 0 8px}
h4{font-size:16px;margin:20px 0 6px}
p{margin:10px 0}
blockquote{margin:14px 0;padding:12px 16px;background:#eef4ef;border-left:4px solid var(--sage);border-radius:0 12px 12px 0}
code{background:#f1e9d9;padding:1px 6px;border-radius:6px;font:13px ui-monospace,Menlo,monospace}
pre{background:#23303a;color:#f4efe3;padding:16px;border-radius:14px;overflow:auto;font:13px/1.4 ui-monospace,Menlo,monospace}
hr{border:0;border-top:1px solid var(--line);margin:28px 0}
ul,ol{padding-left:24px;margin:10px 0}
li{margin:4px 0}
li.sub{margin-left:20px;list-style:circle}
.tw{overflow-x:auto;margin:14px 0;border:1px solid var(--line);border-radius:14px;background:var(--card)}
table{border-collapse:collapse;width:100%;font-size:14.5px}
th{background:#efe6d3;text-align:left;padding:9px 12px;white-space:nowrap}
td{padding:8px 12px;border-top:1px solid var(--line);vertical-align:top}
tr:nth-child(even) td{background:#fffaf0}
strong{color:#16222b}
.badge{display:inline-block;background:var(--orange);color:#fff;border-radius:999px;padding:3px 12px;font-size:13px;font-weight:600}
@media(max-width:900px){.wrap{grid-template-columns:1fr}nav{position:static;max-height:none}}
"""


def main():
    md = SRC.read_text()
    body, toc = convert(md)
    nav = "".join(
        f"<a class='l{lvl}' href='#{sid}'>{html.escape(re.sub(r'[`*]', '', text))}</a>"
        for lvl, text, sid in toc
        if lvl == 2 or text.startswith("Slice")
    )
    page = (
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width,initial-scale=1'>"
        "<title>Catwalk: rooms, decorations, gifts and wishes</title>"
        f"<style>{CSS}</style></head><body><div class='wrap'>"
        f"<nav><b>Contents</b>{nav}</nav><main>"
        "<span class='badge'>Plan, not built yet</span>"
        f"{body}</main></div></body></html>"
    )
    OUT.write_text(page)
    print("wrote", OUT, len(page), "bytes from", SRC.name)


if __name__ == "__main__":
    sys.exit(main())
