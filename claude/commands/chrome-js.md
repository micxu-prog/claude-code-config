# Chrome JavaScript Executor

Execute JavaScript in the frontmost Chrome tab and return results.

## Usage

Run this skill when the user wants to:
- Extract data from a webpage open in Chrome
- Run JavaScript in the browser console
- Scrape dropdown options, table data, or other DOM elements

## Instructions

Use AppleScript to execute JavaScript in Chrome. The user may provide custom JS or ask for common extractions.

### Common Extractions

**Dropdown/listbox options (like Kendo UI):**
```javascript
Array.from(document.querySelectorAll('ul.k-list li.k-item, select option, [role=\"listbox\"] [role=\"option\"]')).map(el => el.textContent.trim()).filter(t => t)
```

**All select dropdowns:**
```javascript
Array.from(document.querySelectorAll('select')).map(sel => ({name: sel.name || sel.id, options: Array.from(sel.options).map(o => o.textContent.trim())}))
```

**Table data:**
```javascript
Array.from(document.querySelectorAll('table tr')).map(tr => Array.from(tr.querySelectorAll('td,th')).map(cell => cell.textContent.trim()))
```

### Execution

Run JavaScript in Chrome using osascript:

```bash
osascript -e '
tell application "Google Chrome"
    set jsResult to execute front window'\''s active tab javascript "YOUR_JS_HERE"
    return jsResult
end tell
'
```

For multi-line or complex JS, save to a temp file first or escape properly.

### Output

Format the results nicely for the user - as a numbered list, table, or JSON depending on what makes sense.

## Example

User: "extract all dropdown options from BIOSMOD"

1. Run the Kendo UI extraction JS via osascript
2. Parse the JSON result
3. Format as a numbered list
