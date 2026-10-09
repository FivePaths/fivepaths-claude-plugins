---
name: document
description: Write or convert a document into one self-contained FivePaths-branded HTML file, built to the cdn.fivepaths.com microsite v3 markup contract and the FivePaths writing rules. Use when asked for a branded document, report, brief, summary, proposal, findings or write-up as HTML, when turning a Markdown, Word or PDF file or notes from the conversation into a FivePaths page, or as the first step before anything is published to share.fivepaths.com.
---

# Write a FivePaths document

The result is **one self-contained HTML file** in the FivePaths design system,
ready to open in a browser or to hand to the `share` skill. Everything this
skill needs is bundled with it. `$SKILL` below is
`${CLAUDE_PLUGIN_ROOT}/skills/document`.

## Resolve the source first

The content may be:

- **A file in the project.** Markdown or HTML: read it directly. Word or PDF:
  extract the text and structure first (the `docx` and `pdf` skills do this)
  and work from that.
- **Work already in this conversation.** Findings, a plan, an analysis: write
  it up.
- **A topic.** Write the document.

"The current document" or "this" means the file most recently discussed or
edited in the session. If two candidates are equally plausible, ask.

Derive the title from the document and name the file after it, lowercase with
hyphens (`q3-findings.html`). Write it into the working directory unless told
otherwise.

## Write it

Read `$SKILL/reference/markup.md` and `$SKILL/reference/voice.md` before
writing. Start from `$SKILL/assets/template.html`, a working skeleton with the
head, the skip link, the header and its theme toggle, and the footer already
correct. Copy it; never edit the bundled copy.

**Pin the current release, not the bundled one.** The template pins the
release that was current when this skill was last published, and the CDN
moves faster than the skill. Before writing, read the live release:

```bash
curl -s https://cdn.fivepaths.com/microsite/v3/ | grep -o 'The current release is [0-9.]*'
curl -s https://cdn.fivepaths.com/microsite/v3/ | grep -o 'fonts/overpass-latin-wght-normal[^"]*\.woff2' | head -1
```

Put that release in the stylesheet link and that font file in the preload.
Pinning still matters: a published release never changes, so the document
keeps the sheet it was checked against. If the live release is a new major
(`v4`) rather than a newer 3.x, stop and say so; the bundled contract only
covers v3. If the page cannot be reached, keep the template's pin.

Rules that come from where the file ends up:

- **One file.** Inline the page-local CSS, reference images as absolute
  `https://` URLs or `data:` URIs, and keep the whole file under 25 MB. A share
  holding a single HTML file renders in the browser; a second file turns the
  share into a download list.
- **Tokens, never literal colours.** The design system supplies both colour
  schemes and the responsive layout from tokens. Do not rebuild either.
- **No link back to share.fivepaths.com or to a sign-in page.** When the
  document is shared, the reader is already inside the viewer, which supplies
  its own navigation.
- **Keep the substance.** Converting a document means carrying every section,
  table, figure and number across, in the source's order, rewritten only where
  the writing rules require. Do not summarise unless asked to.

## Check it

Open the file in the Browser pane and look at it. Confirm the layout holds at
a narrow width, both colour schemes read correctly, and the console is clean.
Fix what you find. A document a client will open is worth the look.

## Report back

Give the path and the title. If the request was to share or send it, continue
with the `share` skill; this skill publishes nothing.

## Files

| Path under `$SKILL` | What |
|---|---|
| `reference/markup.md` | The v3 markup contract: bands, lists, figures, actions, colour |
| `reference/voice.md` | The writing rules, and the slop patterns to avoid |
| `assets/template.html` | A correct empty document to start from |
