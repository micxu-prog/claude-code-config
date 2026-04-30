#!/usr/bin/env python3
# reads ccusage output from stdin, shows first N + last M day rows with compacted separator
import sys

FIRST = 3
LAST = 5

lines = sys.stdin.read().splitlines()

header_lines = []
table_lines = []
in_table = False

for line in lines:
    if line.startswith('\u250c'):  # ┌
        in_table = True
    if in_table:
        table_lines.append(line)
    else:
        header_lines.append(line)

if not table_lines:
    print('\n'.join(lines))
    sys.exit(0)

top_border = table_lines[0]
col_header = []
row_blocks = []
current_block = []
total_block = []
bottom_border = ''

i = 1
while i < len(table_lines) and not table_lines[i].startswith('\u251c'):  # ├
    col_header.append(table_lines[i])
    i += 1

while i < len(table_lines):
    line = table_lines[i]
    if line.startswith('\u2514'):  # └
        bottom_border = line
        break
    if line.startswith('\u251c'):  # ├
        if current_block:
            row_blocks.append(current_block)
        current_block = [line]
    else:
        current_block.append(line)
    i += 1

if current_block:
    row_blocks.append(current_block)

if row_blocks and any('Total' in l for l in row_blocks[-1]):
    total_block = row_blocks.pop()

# build compact separator
compact_sep = row_blocks[0][0] if row_blocks else ''
compact_data = ''
if row_blocks and len(row_blocks[0]) > 1:
    data_template = row_blocks[0][1]
    parts = data_template.split('\u2502')  # │
    compact_parts = []
    for j, p in enumerate(parts):
        if j == 0 or j == len(parts) - 1:
            compact_parts.append(p)
        elif j == 1:
            text = ' ...'
            compact_parts.append(text + ' ' * (len(p) - len(text)))
        elif j == 2:
            text = ' (compacted)'
            compact_parts.append(text + ' ' * max(0, len(p) - len(text)))
        else:
            compact_parts.append(' ' * len(p))
    compact_data = '\u2502'.join(compact_parts)

for l in header_lines:
    print(l)
print(top_border)
for l in col_header:
    print(l)

for block in row_blocks[:FIRST]:
    for l in block:
        print(l)

print(compact_sep)
print(compact_data)

for block in row_blocks[-LAST:]:
    for l in block:
        print(l)

for l in total_block:
    print(l)
print(bottom_border)
