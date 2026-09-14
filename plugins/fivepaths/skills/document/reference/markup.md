# The v3 markup contract, for a single-file document

Everything here is self-contained. The full specification lives in the
`cdn.fivepaths.com` repository (`MARKUP.md`, `DESIGN_GUIDE.md`) and its live
reference page is <https://cdn.fivepaths.com/microsite/v3/>. You do not need
either checked out.

v3 styles **elements and their position**, not class names. Three tiers, in
order:

1. **Nothing.** The element and where it sits identify it: `main > section`,
   `section > header`, `header > h2 + p`.
2. **An attribute with a value**, for an enumerated property: `data-band="alt"`,
   `data-cols="3"`.
3. **A class**, only where a real variant must be named: `ghost`, `ink`, `teal`,
   `tld`, `visually-hidden`. Those five are the whole list. A class the
   stylesheet does not define is a bug.

Do not invent class names. If a document genuinely needs one, prefix it
(`fp-doc-…`) and define it in the page-local `<style>`.

## Head

Pin the release. A published release is immutable, so a pinned file never
changes underneath the document.

```html
<link rel="stylesheet" href="https://cdn.fivepaths.com/microsite/v3/base-3.4.2.css">
<script src="https://cdn.fivepaths.com/microsite/v3/theme-1.0.0.js"></script>
```

`theme-1.0.0.js` is blocking in `<head>` on purpose: it replays the reader's
stored colour scheme before first paint. It binds any `body > header button`
as the toggle, and it guards `localStorage` in both directions, so it behaves
correctly inside the share viewer's sandboxed frame (the choice simply does
not persist there).

## Bands

A `<section>` is a band. The dark values re-point the neutral tokens, so every
component inside adapts with no rule of its own.

| Markup | Is |
|---|---|
| `<section>` | the default light band |
| `<section data-band="alt">` | the alternating ground |
| `<section data-band="dark">` | a dark band |
| `<section data-band="hero">` | the opening band, dark, carries the `h1` |
| `<section data-band="proof">` | a one-line claim beside a badge, dark |
| `<section data-band="cta">` | the closing band, dark, centred |
| `<section data-band="strip">` | a thin rule-bounded band |
| `<section data-tight>` | less vertical air, any band |

Alternate `alt` with the default band down the page so sections separate
without rules.

### The content column

A section is a grid with named tracks. Any child gets the content track. A
figure can ask for more:

- `<figure data-width="wide">` reaches the wide track
- `<figure data-width="full">` reaches the viewport edges and loses its frame

### The section head

```html
<section data-band="alt">
  <header>
    <p>Findings</p>          <!-- eyebrow: a p first, with a heading after it -->
    <h2>What we measured</h2>
    <p>A lead paragraph.</p> <!-- lead: the p right after the heading -->
  </header>
  <p>Body copy.</p>
</section>
```

The eyebrow only renders as one when a heading follows it. A lead paragraph
outside the `header` gets no lead styling.

## Lists

| Markup | Is |
|---|---|
| `<ul>` in `main` | a tick list |
| `<ul data-marker="check">` | the same, with a check for "verified" |
| `<ul data-cols="3">` | columns once there is room |
| `<ol>` in `main` | numbered in a ring |
| `<ol data-list="steps">` | the numbered grid |
| `<ul data-list="cards" data-cols="3">` | the card grid |

When a whole card is a link, the link is the item's only child, so the target
is the card rather than the words in it:

```html
<ul data-list="cards" data-cols="3">
  <li><a href="#detail">
    <h3>Heading</h3>
    <p>Supporting line.</p>
    <span>Read on &rarr;</span>   <!-- the affordance, last -->
  </a></li>
  <li><div>
    <h3>No link</h3>
    <p>A card with nothing to point at is a div.</p>
  </div></li>
</ul>
```

## Layouts

| Markup | Is |
|---|---|
| `<div data-layout="split">` | equal panels, each child a panel |
| `<div data-layout="feature">` | two columns, copy then media |
| `<div data-layout="feature flip">` | media first |
| `<div data-layout="feature uneven">` | 5fr to 7fr |
| `<div data-layout="feature top">` | aligned to the top |
| `<div data-layout="shots">` | a grid of figures |

Modifiers are matched with `~=`, so they compose.

## Figures

A figure is told apart by what is inside it, and that is what frames it.
**A table always goes inside a `<figure>`**, or it will not scroll sideways on
a narrow screen.

| Contains | Renders as |
|---|---|
| `img` or `picture` | a screenshot: bordered, rounded, lifted |
| `table` | a table that scrolls sideways inside its own box |
| `blockquote` | a quotation with a rule down the left |
| `pre` | a code listing whose `figcaption` is the title bar |

```html
<figure>
  <table>
    <caption>What each row means</caption>
    <thead><tr><th scope="col">Item</th><th scope="col">Value</th></tr></thead>
    <tbody><tr><th scope="row">First</th><td>12</td></tr></tbody>
  </table>
</figure>
```

## Actions

```html
<div data-actions>
  <a href="#start">The primary ask</a>
  <a class="ghost" href="#more">Secondary</a>
</div>
```

The first link in a group is the fill; everything after it is secondary. One
primary per view: a second one needs a second group, which is visible in
review.

In a shared document most "actions" are in-page anchors or `mailto:` links.
The reader reached the page through Share, so do not link back to it.

## Everything else

| Element | Is |
|---|---|
| `<aside>` | a callout. `data-severity="warning"` or `"critical"`; the first `p` is the label |
| `<details>` | a disclosure. `<summary>` is the control |
| `<dl>` | a definition list, good for document metadata |
| `<small>` | fine print |
| `<span data-chip>` | a small badge |
| `<code>`, `<pre>` | inline and block code |
| `body > a:first-child` | the skip link |
| `body > header` | brand first (an `a`), then `nav` |
| `body > footer` | the document footer |

```html
<aside data-severity="warning">
  <p>Before you act on this</p>
  <p>The figures cover January to June only.</p>
</aside>
```

## Colour

Two hues, one job each. Never write a literal colour.

- **Amber `--fp-amber` is a fill, never text on a light ground.** Buttons,
  chips, highlights. As text on a light ground use `--fp-bronze`.
- **Teal `--fp-accent` carries every text accent**: links, eyebrows, tick
  marks, focus rings.
- Neutral inks and papers do everything else. The `--fp-route-*` blips are for
  **data** only (series keys, route badges), never chrome.

A tint is `color-mix()` against a token, not a new literal, so it follows the
dark-band remap. Every pairing in the sheet clears WCAG AAA; keep it that way.

## Checklist

- Pinned `base-3.4.2.css`, the font preload, and `theme-1.0.0.js` in `<head>`
- A skip link as `body`'s first child, and `<main id="main">`
- One `h1`, in the hero band; headings descend without skipping a level
- Every table wrapped in a `figure`
- No literal colours, no invented class names, no `style=` attributes
- Both colour schemes checked
