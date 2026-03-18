#!/usr/bin/env python3
"""
confluence-update.py - convert markdown to confluence storage format and push via REST API.

usage:
    python3 confluence-update.py <page-id> <markdown-file> [--dry-run] [--output FILE] [--title TITLE]
"""

import argparse
import json
import re
import sys
from pathlib import Path


# --------------------------------------------------------------------------- #
#  auth                                                                         #
# --------------------------------------------------------------------------- #

TOKEN_PATH = Path.home() / ".ai-pim-utils" / "confluence" / "token"
BASE_URL = "https://nvidia.atlassian.net/wiki"
USER = "micxu@nvidia.com"


def _get_token() -> str:
    if not TOKEN_PATH.exists():
        sys.exit(f"error: token file not found at {TOKEN_PATH}")
    return TOKEN_PATH.read_text().strip()


def _auth_header() -> dict:
    import base64
    token = _get_token()
    creds = base64.b64encode(f"{USER}:{token}".encode()).decode()
    return {"Authorization": f"Basic {creds}", "Content-Type": "application/json"}


# --------------------------------------------------------------------------- #
#  confluence REST helpers                                                      #
# --------------------------------------------------------------------------- #

def get_page_info(page_id: str) -> dict:
    import urllib.request
    url = f"{BASE_URL}/rest/api/content/{page_id}?expand=version,title"
    req = urllib.request.Request(url, headers=_auth_header())
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def update_page(page_id: str, title: str, version: int, xhtml: str, dry_run: bool = False) -> dict:
    import urllib.request
    payload = {
        "version": {"number": version + 1},
        "title": title,
        "type": "page",
        "body": {
            "storage": {
                "value": xhtml,
                "representation": "storage",
            }
        },
    }
    data = json.dumps(payload).encode()
    url = f"{BASE_URL}/rest/api/content/{page_id}"
    req = urllib.request.Request(url, data=data, headers=_auth_header(), method="PUT")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


# --------------------------------------------------------------------------- #
#  markdown -> confluence storage format (XHTML) converter                     #
# --------------------------------------------------------------------------- #

def md_to_confluence(md: str) -> str:
    """
    convert markdown to confluence storage format.
    handles: headings, bold, italic, code blocks, inline code, tables,
             horizontal rules, unordered/ordered lists, links, blockquotes.
    """
    lines = md.split("\n")
    output: list[str] = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # ------------------------------------------------------------------ #
        #  fenced code blocks  ```lang ... ```                                #
        # ------------------------------------------------------------------ #
        fence_match = re.match(r'^```(\w*)\s*$', line)
        if fence_match:
            lang = fence_match.group(1) or "none"
            code_lines: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i])
                i += 1
            # skip closing ```
            i += 1
            code_content = "\n".join(code_lines)
            # escape xml special chars inside code block
            code_content = _xml_escape(code_content)
            output.append(
                f'<ac:structured-macro ac:name="code">'
                f'<ac:parameter ac:name="language">{lang}</ac:parameter>'
                f'<ac:plain-text-body><![CDATA[{code_content}]]></ac:plain-text-body>'
                f'</ac:structured-macro>'
            )
            continue

        # ------------------------------------------------------------------ #
        #  horizontal rule  ---                                               #
        # ------------------------------------------------------------------ #
        if re.match(r'^-{3,}\s*$', line) or re.match(r'^_{3,}\s*$', line) or re.match(r'^\*{3,}\s*$', line):
            output.append('<hr/>')
            i += 1
            continue

        # ------------------------------------------------------------------ #
        #  headings  # H1 ... ###### H6                                       #
        # ------------------------------------------------------------------ #
        h_match = re.match(r'^(#{1,6})\s+(.*)', line)
        if h_match:
            level = len(h_match.group(1))
            text = _inline(h_match.group(2))
            output.append(f'<h{level}>{text}</h{level}>')
            i += 1
            continue

        # ------------------------------------------------------------------ #
        #  tables  | col | col |                                               #
        # ------------------------------------------------------------------ #
        if line.startswith('|') and '|' in line[1:]:
            table_lines: list[str] = []
            while i < len(lines) and lines[i].startswith('|'):
                table_lines.append(lines[i])
                i += 1
            output.append(_convert_table(table_lines))
            continue

        # ------------------------------------------------------------------ #
        #  unordered list  - item  or  * item                                 #
        # ------------------------------------------------------------------ #
        if re.match(r'^(\s*)[*\-+]\s+', line):
            list_lines: list[str] = []
            while i < len(lines) and (re.match(r'^(\s*)[*\-+]\s+', lines[i]) or re.match(r'^(\s{2,})', lines[i])):
                list_lines.append(lines[i])
                i += 1
            output.append(_convert_list(list_lines, ordered=False))
            continue

        # ------------------------------------------------------------------ #
        #  ordered list  1. item                                               #
        # ------------------------------------------------------------------ #
        if re.match(r'^(\s*)\d+\.\s+', line):
            list_lines = []
            while i < len(lines) and (re.match(r'^(\s*)\d+\.\s+', lines[i]) or re.match(r'^(\s{2,})', lines[i])):
                list_lines.append(lines[i])
                i += 1
            output.append(_convert_list(list_lines, ordered=True))
            continue

        # ------------------------------------------------------------------ #
        #  blockquote  > text                                                  #
        # ------------------------------------------------------------------ #
        if line.startswith('>'):
            bq_lines: list[str] = []
            while i < len(lines) and lines[i].startswith('>'):
                bq_lines.append(lines[i].lstrip('> '))
                i += 1
            inner = _inline("\n".join(bq_lines))
            output.append(f'<blockquote><p>{inner}</p></blockquote>')
            continue

        # ------------------------------------------------------------------ #
        #  blank line -> paragraph break                                       #
        # ------------------------------------------------------------------ #
        if line.strip() == '':
            output.append('')
            i += 1
            continue

        # ------------------------------------------------------------------ #
        #  regular paragraph line                                              #
        # ------------------------------------------------------------------ #
        output.append(f'<p>{_inline(line)}</p>')
        i += 1

    return "\n".join(output)


def _xml_escape(text: str) -> str:
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    return text


def _inline(text: str) -> str:
    """convert inline markdown (bold, italic, inline code, links) to xhtml."""
    # inline code -- do first to avoid processing content inside
    # use a placeholder approach so we don't double-process
    placeholders: dict[str, str] = {}
    counter = [0]

    def stash(replacement: str) -> str:
        key = f"\x00PLACEHOLDER{counter[0]}\x00"
        placeholders[key] = replacement
        counter[0] += 1
        return key

    # inline code  `code`
    def replace_code(m: re.Match) -> str:
        return stash(f'<code>{_xml_escape(m.group(1))}</code>')
    text = re.sub(r'`([^`]+)`', replace_code, text)

    # links  [text](url)
    def replace_link(m: re.Match) -> str:
        link_text = m.group(1)
        url = m.group(2)
        return stash(f'<a href="{url}">{link_text}</a>')
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', replace_link, text)

    # bold+italic  ***text*** or ___text___
    text = re.sub(r'\*{3}(.+?)\*{3}', r'<strong><em>\1</em></strong>', text)
    text = re.sub(r'_{3}(.+?)_{3}', r'<strong><em>\1</em></strong>', text)

    # bold  **text** or __text__
    text = re.sub(r'\*{2}(.+?)\*{2}', r'<strong>\1</strong>', text)
    text = re.sub(r'_{2}(.+?)_{2}', r'<strong>\1</strong>', text)

    # italic  *text* or _text_
    text = re.sub(r'\*(.+?)\*', r'<em>\1</em>', text)
    text = re.sub(r'_(.+?)_', r'<em>\1</em>', text)

    # restore placeholders
    for key, val in placeholders.items():
        text = text.replace(key, val)

    # escape any remaining & < > that aren't already part of tags
    # (this is a best-effort approach; we avoid re-escaping tag content)
    # only escape bare & that isn't already &amp; &lt; &gt; etc.
    text = re.sub(r'&(?!amp;|lt;|gt;|quot;|apos;|#)', '&amp;', text)

    return text


def _convert_table(lines: list[str]) -> str:
    """convert markdown table lines to confluence xhtml table."""
    rows: list[list[str]] = []
    for line in lines:
        # skip separator row  |---|---|
        if re.match(r'^[\|\s\-:]+$', line):
            continue
        cells = [c.strip() for c in line.strip('|').split('|')]
        rows.append(cells)

    if not rows:
        return ''

    html = ['<table><tbody>']
    for row_idx, row in enumerate(rows):
        html.append('<tr>')
        tag = 'th' if row_idx == 0 else 'td'
        for cell in row:
            html.append(f'<{tag}>{_inline(cell)}</{tag}>')
        html.append('</tr>')
    html.append('</tbody></table>')
    return '\n'.join(html)


def _convert_list(lines: list[str], ordered: bool) -> str:
    """convert markdown list lines to xhtml ul/ol."""
    tag = 'ol' if ordered else 'ul'
    items = []
    for line in lines:
        # strip the list marker
        text = re.sub(r'^\s*(?:\d+\.|[*\-+])\s+', '', line)
        items.append(f'<li>{_inline(text)}</li>')
    return f'<{tag}>{"".join(items)}</{tag}>'


# --------------------------------------------------------------------------- #
#  main                                                                         #
# --------------------------------------------------------------------------- #

def main() -> None:
    parser = argparse.ArgumentParser(description="convert markdown and push to confluence")
    parser.add_argument("page_id", help="confluence page id (numeric)")
    parser.add_argument("markdown_file", help="path to markdown file")
    parser.add_argument("--dry-run", action="store_true", help="convert but do not push")
    parser.add_argument("--output", help="save converted xhtml to this file (implies --dry-run preview)")
    parser.add_argument("--title", help="override page title")
    args = parser.parse_args()

    md_path = Path(args.markdown_file)
    if not md_path.exists():
        sys.exit(f"error: markdown file not found: {md_path}")

    md_content = md_path.read_text(encoding="utf-8")
    xhtml = md_to_confluence(md_content)

    if args.output:
        Path(args.output).write_text(xhtml, encoding="utf-8")
        print(f"xhtml saved to {args.output}")

    if args.dry_run:
        print("dry-run mode: skipping push")
        if not args.output:
            print(xhtml[:2000])
        return

    print(f"fetching page info for id={args.page_id} ...")
    info = get_page_info(args.page_id)
    current_version = info["version"]["number"]
    current_title = args.title or info["title"]
    print(f"  title   : {current_title}")
    print(f"  version : {current_version} -> {current_version + 1}")

    print("pushing update ...")
    result = update_page(args.page_id, current_title, current_version, xhtml)
    new_version = result["version"]["number"]
    page_url = f"{BASE_URL}/pages/{args.page_id}"
    print(f"done. page updated to version {new_version}")
    print(f"url: {page_url}")


if __name__ == "__main__":
    main()
