#!/bin/bash
# shows first N and last M day rows from ccusage with a compacted separator
FIRST=3  # first N day rows to show
LAST=5   # last M day rows to show

output=$(npx ccusage@17.2.1 2>&1)

# extract everything into arrays of "row blocks"
# a row block = separator line (├──) + data lines (│ ...) until next separator or └
python3 - "$FIRST" "$LAST" <<'PYEOF' <<<"$output"
import sys

first_n = int(sys.argv[1])
last_m = int(sys.argv[2])

lines = sys.stdin.read().splitlines()

# find the title/header section (everything before the table)
header_lines = []
table_lines = []
in_table = False

for line in lines:
    if line.startswith('┌'):
        in_table = True
    if in_table:
        table_lines.append(line)
    else:
        header_lines.append(line)

# parse table into: top_border, col_header, separator, then row_blocks, then total_block, bottom_border
# row blocks are grouped by ├ separators
if not table_lines:
    print('\n'.join(lines))
    sys.exit(0)

top_border = table_lines[0]  # ┌...
# find column header lines (between ┌ and first ├)
col_header = []
row_blocks = []
current_block = []
total_block = []
bottom_border = ''

i = 1
# collect column headers
while i < len(table_lines) and not table_lines[i].startswith('├'):
    col_header.append(table_lines[i])
    i += 1

# now parse row blocks: each starts with ├ and contains │ lines until next ├ or └
while i < len(table_lines):
    line = table_lines[i]
    if line.startswith('└'):
        bottom_border = line
        break
    if line.startswith('├'):
        if current_block:
            row_blocks.append(current_block)
        current_block = [line]
    else:
        current_block.append(line)
    i += 1

if current_block:
    row_blocks.append(current_block)

# last row block is the Total row
if row_blocks and any('Total' in l for l in row_blocks[-1]):
    total_block = row_blocks.pop()

# build separator row matching table width
sep_line = row_blocks[0][0] if row_blocks else ''
# create a "compacted" visual break
# use the separator line but replace content with dots
compact_sep = sep_line
# create a data line with "..." centered
if row_blocks and len(row_blocks[0]) > 1:
    data_template = row_blocks[0][1]
    # replace cell contents with spaces/dots
    parts = data_template.split('│')
    compact_data_parts = []
    for j, p in enumerate(parts):
        if j == 0 or j == len(parts)-1:
            compact_data_parts.append(p)
        elif j == 1:
            # date column
            content = ' ' * ((len(p)-3)//2) + '...' + ' ' * ((len(p)-3+1)//2)
            compact_data_parts.append(content[:len(p)])
        elif j == 2:
            # models column
            mid = len(p)
            text = '(compacted)'
            pad_l = (mid - len(text)) // 2
            pad_r = mid - len(text) - pad_l
            compact_data_parts.append(' ' * pad_l + text + ' ' * pad_r)
        else:
            compact_data_parts.append(' ' * len(p))
    compact_data = '│'.join(compact_data_parts)

# print output
for l in header_lines:
    print(l)

print(top_border)
for l in col_header:
    print(l)

# first N rows
for block in row_blocks[:first_n]:
    for l in block:
        print(l)

# compacted separator
print(compact_sep)
print(compact_data)

# last M rows
for block in row_blocks[-last_m:]:
    for l in block:
        print(l)

# total
for l in total_block:
    print(l)

print(bottom_border)
PYEOF
