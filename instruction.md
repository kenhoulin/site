# How to Update Your CV & Website

This is the operating manual for the site at `kenhoulin.info`. Everything — the
PDF CV *and* the website — is built from a handful of plain-text source files by
a single command: `quarto render`. You never edit the PDF or the HTML directly;
you edit the **sources**, then re-render.

---

## 1. The Big Picture (Dependency Flowchart)

```
                         ┌──────────────────────────────────────┐
   SOURCES (edit these)  │                                        │
   ──────────────────    │                                        │
                         ▼                                        ▼
   publications/                                          data/*.yml
   publications.bib                                       ├── education.yml
   (every paper, book,                                    ├── appointments.yml
    chapter, working                                      ├── grants.yml
    paper, op-ed)                                         ├── awards.yml
        │                                                 ├── talks.yml
        │                                                 ├── teaching.yml
        │                                                 └── service.yml
        │                                                       │
        │                                                       │
        ▼                                                       │
   ┌─────────────────────────────┐                             │
   │  quarto render              │                              │
   │   (runs the whole pipeline) │                              │
   └─────────────────────────────┘                             │
        │                                                       │
        │  STEP A — pre-render hook                             │
        │  _quarto-pre-render.R → scripts/bib_to_network.R      │
        │     • reads publications.bib                          │
        │     • fetches citation counts from OpenAlex           │
        │       (cached in openalex_cache.json)                 │
        │     • writes  publications/network.json               │
        │     • writes  publications/publications.json          │
        │                                                       │
        ├──────────────────────┬────────────────────────────┐  │
        ▼                       ▼                            ▼  ▼
   STEP B                  STEP C                        STEP D
   cv.qmd  ───────────►   index.qmd ──────────►   (index.qmd ALSO pulls
   reads publications.bib  homepage text +          from data/*.yml? NO —
   + ALL data/*.yml        loads the two .json      only cv.qmd uses the
   + assets/cv-template.tex files via JavaScript:    YAML files)
   + assets/photo? NO        publications/network.js
        │                     publications/filter.js
        ▼                     styles.css + assets/photo.jpg
   cv.pdf  (the CV)            │
        │                      ▼
        └────────────►   _site/   ◄───────────────────────────┘
                         (the finished website — index.html, cv.pdf,
                          assets, json, js, css — ready to deploy)
```

**The one rule to remember:** publications live in **`publications.bib`** and
feed *both* the CV and the website graph. Everything else on the CV lives in
**`data/*.yml`**. The website's text (bio, contact) lives in **`index.qmd`**.

---

## 2. Prerequisites (one-time setup)

You need three things installed and on your PATH:

1. **Quarto** — https://quarto.org/docs/get-started/
2. **R** (Rscript) — https://cran.r-project.org/
3. **R packages** used by the build scripts. Run once in R:

   ```r
   install.packages(c("bib2df", "dplyr", "tidyr", "jsonlite",
                      "stringr", "httr", "yaml"))
   ```

4. **A LaTeX engine** for the PDF CV (`pdflatex`). If you don't have one:

   ```r
   quarto install tinytex      # run in a terminal, not R
   ```

Verify everything works:

```bash
quarto check
```

---

## 3. The Core Workflow (memorize this)

Whatever you change, the loop is always the same:

```bash
# 1. Edit a source file (a .bib, a .yml, or index.qmd)

# 2. Preview live in your browser while you work:
quarto preview
#    → opens localhost:xxxx, auto-reloads on save

# 3. When happy, do a full clean build:
quarto render
#    → writes everything into _site/

# 4. Check the results:
#    _site/index.html   (the website)
#    cv.pdf             (the CV — also copied into _site/)

# 5. Deploy (see Section 9)
git add -A
git commit -m "Update publications" 
git push          # Netlify rebuilds automatically (once connected)
```

> **Tip:** `quarto preview` is your friend for the website. For the PDF CV,
> render `cv.qmd` on its own to iterate faster:
> `quarto render cv.qmd`

---

## 4. Adding / Editing a Publication  ← most common task

**File:** `publications/publications.bib`
**Affects:** CV (PDF) **and** website graph + publication list.

### 4a. Add a new entry

Open `publications/publications.bib` and add a BibTeX block. Pick the entry type
that matches the work — this controls which CV section it lands in and its color
on the graph:

| BibTeX type      | CV section            | Outlet field used |
|------------------|-----------------------|-------------------|
| `@book`          | Books                 | `publisher`       |
| `@article`       | Refereed Articles     | `journal`         |
| `@incollection`  | Book Chapters         | `booktitle`       |
| `@inproceedings` | Book Chapters         | `booktitle`       |
| `@unpublished`   | Working Papers        | `howpublished`    |
| `@techreport`    | Working Papers        | `howpublished`    |
| `@misc`          | Op-Eds, Reviews, Other| `journal`/`howpublished` |

**Template for a journal article:**

```bibtex
@article{lin2027example,
  author      = {Lin, Ken-Hou and Coauthor, Jane},
  title       = {The Title of the Paper},
  year        = {2027},
  journal     = {American Sociological Review},
  volume      = {92},
  number      = {3},
  pages       = {400--430},
  doi         = {10.1177/xxxxxxxx},
  keywords    = {inequality, labor markets, methods},
  abstract    = {One or more paragraphs. Blank lines between paragraphs are
                 preserved and shown as separate paragraphs on the website.},
  featured    = {true},
}
```

### 4b. Field rules — read these carefully

- **Citation key** (`lin2027example`): must be **unique**. Convention is
  `[lastname][year][firstword]`, all lowercase. This is the node id in the graph.
- **`author`**: BibTeX format `Last, First and Last, First`. Use
  `Lin, Ken-Hou` exactly — the CV script **bolds your name** automatically by
  matching "Ken-Hou … Lin".
- **`keywords`**: **the engine of the graph.** Two papers get connected by an
  edge when they share ≥1 keyword; the more shared keywords, the thicker the
  edge. Separate keywords with **commas or semicolons**. Reuse existing keywords
  so papers actually link up — skim the .bib for the vocabulary already in use
  (e.g. `financialization`, `inequality`, `gender`, `race`, `methods`,
  `organizations`, `labor markets`). A keyword used by only one paper produces an
  isolated node.
- **`doi`**: optional but recommended. It powers the `[DOI]` link on the CV
  **and** the live citation count (fetched from OpenAlex). No DOI → no citation
  count for that paper.
- **`abstract`**: optional. Shown on the website when you click a node. Blank
  lines = paragraph breaks (the build script handles this).
- **`featured = {true}`**: optional. *(Currently parsed into the JSON but the
  homepage has no "selected work" section, so it has no visible effect today.
  Harmless to keep for the future.)*
- **`pages`**: use `400--430` (double dash); it's normalized to a single dash.

### 4c. Edit or remove a publication

Just edit the fields in place, or delete the whole `@type{...}` block. Re-render.

### 4d. Citation counts

Counts come from **OpenAlex** (keyed on DOI) and are cached in
`publications/openalex_cache.json` so renders are fast and offline-friendly.

- To **refresh** counts, delete `publications/openalex_cache.json` and re-render
  (requires internet; it re-fetches every DOI).
- A render with no internet still works — it just keeps the cached numbers (and
  shows none for brand-new DOIs until you're back online).

---

## 5. Updating CV Sections (everything that is NOT a publication)

All non-publication CV content lives in `data/*.yml`. These feed **only the CV
PDF** (the website does not display them). Edit the YAML, then
`quarto render cv.qmd`.

YAML rules: indent with **spaces** (never tabs), keep the `- ` list dashes
aligned, and wrap any value containing a colon, comma, or quote in
`"double quotes"`.

### `data/education.yml` — Education
```yaml
- degree: Ph.D., Sociology
  institution: University of Massachusetts–Amherst
  year: 2013
```

### `data/appointments.yml` — Appointments
```yaml
- title: Professor, Department of Sociology
  institution: University of Texas at Austin
  years: "2024–present"
```
Order them as you want them to appear (current first).

### `data/grants.yml` — Grants & Fellowships
```yaml
- title: "Project Title"
  role: Principal Investigator        # or "Co-Principal Investigator (PI: Name)"
  funder: Funding Agency
  amount: "$120,000"                  # optional
  years: "2025–2027"
```

### `data/awards.yml` — Honors & Awards
```yaml
- name: Award Name
  org: Granting Organization
  year: 2024            # use either `year: 2024`
  # years: "2016–2017"  # ...OR `years:` for a range
```

### `data/talks.yml` — Presentations
```yaml
- year: 2026
  title: "Talk Title"
  venue: Conference or Host
  location: City, Country
  invited: true        # optional; adds "(Invited)" — omit for contributed talks
```
Talks are auto-grouped by year (newest first).

### `data/teaching.yml` — Teaching
A single record with two lists:
```yaml
- institution: University of Texas at Austin
  graduate:
    - "Course Name"
  undergraduate:
    - "Course Name"
```

### `data/service.yml` — Service & Advising (the most structured file)
This one has **nested sections**. Keep the top-level keys exactly as named —
the CV script looks for each by name:

```yaml
editorial:                       # → "Editorial Positions"
  - role: Editor-in-Charge
    org: Socio-Economic Review
    years: "2021–present"

professional_associations:       # → "Professional Associations"
  - role: Council Member, ...
    org: American Sociological Association
    years: "2022–2025"

university:                      # → "University Service"
  departmental:                  #   (sub-grouped: Departmental / College-wide / University-wide)
    - role: Member, Executive Committee
      years: "2025–2027"
  college_wide:
    - role: ...
      years: "..."
  university_wide:
    - role: ...
      years: "..."

advising:                        # → "Graduate Advising"
  dissertation_chair:
    - name: Student Name
      years: "2018–2022"
      role: Co-Chair             # optional
  dissertation_committee:
    - name: Student Name
      years: "2024–present"
```

> Note: the `reviewer:` block (journals / grant agencies / tenure cases) exists
> in the file but is **not currently rendered** on the CV. Edit it freely; to
> show it you'd need to add a block to `cv.qmd`.

---

## 6. Updating Website Text (bio, contact, photo)

**File:** `index.qmd` — this is the entire one-page website.

- **Bio / About paragraphs:** edit the prose under `## About`.
- **Contact details:** edit the `<dl class="contact-grid">` block under
  `## Contact` (email, office, mailing address, Scholar link).
- **Top-of-page contact icons:** the `.hero-contacts` block (email / Google
  Scholar / CV link).
- **Photo:** replace `assets/photo.jpg` with a new file **of the same name**
  (or change the path in the `![](assets/photo.jpg)` line near the top).
- **The Research section** contains the interactive graph — it's built from HTML
  placeholders that the JavaScript fills in. Don't remove the `id=` attributes
  (`pub-network`, `keyword-chips`, `pub-list`, etc.); the scripts target them.

Re-render with `quarto render` (or `quarto preview` to watch it live).

---

## 7. Changing How Things Look

| You want to change…                 | Edit this file                          |
|-------------------------------------|-----------------------------------------|
| Website colors, fonts, spacing, layout | `styles.css`                         |
| Graph behavior (node size, colors, physics, tooltip) | `publications/network.js` |
| Filter chips / publication-list behavior | `publications/filter.js`           |
| **PDF CV** layout, margins, fonts, section formatting | `assets/cv-template.tex` |
| CV section order / wording / which sections appear | `cv.qmd`                  |
| Site title, nav bar, footer         | `_quarto.yml`                           |

The `.js`, `.css`, and `.json` files are listed as `resources` in `_quarto.yml`
so Quarto copies them into `_site/` on every render — you usually don't touch
that config.

---

## 8. Build Outputs — what gets generated (don't hand-edit these)

These are **regenerated on every render**; editing them directly is pointless:

- `publications/network.json` — graph nodes + edges (from `bib_to_network.R`)
- `publications/publications.json` — full publication list for the filter UI
- `publications/openalex_cache.json` — cached citation counts (safe to delete to force a refresh)
- `cv.pdf` and `cv.tex` — the rendered CV (`cv.tex` kept because `keep-tex: true`)
- `_site/` — the complete website Netlify serves
- `.quarto/` — Quarto's internal cache

`_site/`, `.quarto/`, and R history files are git-ignored. The JSON files **are**
committed so the site can build even if OpenAlex is unreachable.

---

## 9. Deploying the Site

The intended host is **Netlify**, auto-building from a GitHub repo on every push.

> **Current status:** this repo has **no git remote configured yet** and Netlify
> isn't connected. Until that's set up, "deploy" just means rendering locally.
> The first-time setup below is a one-time task.

### First-time setup (once)
1. Create a repo on GitHub (private or public).
2. Connect it locally:
   ```bash
   git remote add origin https://github.com/<you>/<repo>.git
   git push -u origin main
   ```
3. In Netlify: **Add new site → Import from GitHub**, pick the repo.
   - Build command: `quarto render`
   - Publish directory: `_site`
4. Netlify gives you a `*.netlify.app` URL — verify the site there first.
5. Point `kenhoulin.info` DNS at Netlify (registrar nameservers or A/CNAME
   records per Netlify's instructions). **Keep the old Google Site live until
   the new one is confirmed working at the custom domain.**

### Routine deploys (every time after)
```bash
git add -A
git commit -m "describe what changed"
git push
```
Netlify rebuilds automatically. Because Netlify runs `quarto render` itself, the
JSON/PDF will regenerate in the cloud — but committing your locally-built
versions is good insurance and keeps the repo self-consistent.

---

## 10. Quick Reference — "I want to…"

| Task | File(s) to edit | Command |
|------|-----------------|---------|
| Add / edit a paper, book, chapter | `publications/publications.bib` | `quarto render` |
| Connect two papers in the graph | add a shared `keywords` value in both entries | `quarto render` |
| Refresh citation counts | delete `publications/openalex_cache.json` | `quarto render` (needs internet) |
| Add a talk | `data/talks.yml` | `quarto render cv.qmd` |
| Add a grant / award | `data/grants.yml` / `data/awards.yml` | `quarto render cv.qmd` |
| Update service / advising | `data/service.yml` | `quarto render cv.qmd` |
| Update appointments / education | `data/appointments.yml` / `data/education.yml` | `quarto render cv.qmd` |
| Update teaching | `data/teaching.yml` | `quarto render cv.qmd` |
| Edit bio / contact text | `index.qmd` | `quarto render` |
| Replace photo | `assets/photo.jpg` (same name) | `quarto render` |
| Restyle the website | `styles.css` | `quarto render` |
| Change graph look/behavior | `publications/network.js` | `quarto render` |
| Reformat the PDF CV | `assets/cv-template.tex` / `cv.qmd` | `quarto render cv.qmd` |
| Preview while editing | — | `quarto preview` |
| Publish | commit + push | `git push` (Netlify auto-builds) |

---

## 11. Troubleshooting

- **`quarto render` fails in the pre-render step** → it's almost always
  `publications.bib`. Check for a missing comma, an unbalanced `{ }`, or a
  duplicate citation key. The error message names the offending entry.
- **A paper is missing from the CV** → its BibTeX `@type` maps to a section that
  didn't get printed, or a typo in a required field. Confirm the type against the
  table in Section 4a.
- **A paper is an isolated dot in the graph** → its keywords don't match any
  other paper's. Align spelling/casing with existing keywords.
- **Citation count shows blank** → no DOI on that entry, or OpenAlex hasn't
  indexed it yet, or you rendered offline before it was cached.
- **YAML error** → you used a tab instead of spaces, or an unquoted value
  containing `:` `,` or `"`. Wrap the value in double quotes.
- **PDF won't build / LaTeX error** → run `quarto install tinytex`, then retry.
  Math/special characters in your text are escaped automatically by `cv.qmd`, so
  you can type `&`, `%`, `$`, `_` normally in YAML and .bib values.
- **Website looks stale after editing** → hard-refresh the browser, or stop and
  restart `quarto preview`.
