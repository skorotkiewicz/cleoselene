#!/usr/bin/env python3
import os
import re

try:
    import markdown
except ImportError:
    print("Error: 'markdown' module not found. Please run 'pip3 install markdown'")
    exit(1)

TEMPLATE_PATH = "website/index.template.html"
OUTPUT_PATH = "website/index.html"
MANUAL_PATH = "engine/MANUAL.md"

def main():
    if not os.path.exists(TEMPLATE_PATH):
        if os.path.exists(OUTPUT_PATH):
            os.rename(OUTPUT_PATH, TEMPLATE_PATH)
        else:
            print("Error: No template found.")
            return

    with open(TEMPLATE_PATH, 'r') as f:
        template = f.read()

    with open(MANUAL_PATH, 'r') as f:
        manual_md = f.read()

    # Convert Markdown to HTML with tables extension
    manual_html = markdown.markdown(manual_md, extensions=['tables', 'fenced_code'])
    
    # Wrap in a div for styling
    manual_html = f'<div class="manual-content">{manual_html}</div>'
    
    if "<!-- MANUAL_CONTENT -->" in template:
        final_html = template.replace("<!-- MANUAL_CONTENT -->", manual_html)
    else:
        final_html = re.sub(r'<pre><code>LUA API REFERENCE.*?</code></pre>', manual_html, template, flags=re.S)

    with open(OUTPUT_PATH, 'w') as f:
        f.write(final_html)
    
    print(f"Generated {OUTPUT_PATH} from {MANUAL_PATH} using 'markdown' lib")

if __name__ == "__main__":
    main()
