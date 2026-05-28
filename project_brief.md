# Academic Website & CV — Project Brief

## Overview

Build a personal academic website and CV for Ken-Hou Lin (Professor of Sociology, UT Austin) using Quarto. The site replaces the existing Google Sites setup at `kenhoulin.info`. Single source of truth for CV and website content; one build produces both a downloadable PDF CV and an HTML website.

The distinctive feature is an interactive **publications network graph** on the publications page, with multi-dimensional filtering by user-defined keywords and publication outlets.

## Tech Stack

- **Quarto** for site generation (HTML + PDF from shared sources)
- **BibTeX** as canonical publication data (`publications.bib`)
- **YAML** for non-publication CV data (talks, teaching, grants, service, awards)
- **R** for data-processing scripts (CSV → BibTeX, BibTeX → network JSON)
- **D3.js** for the publications network visualization
- **Git + GitHub + Netlify** for version control and deployment
- Custom domain: `kenhoulin.info`

## File Structure

```
kenhoulin-site/
├── _quarto.yml                  # site config
├── index.qmd                    # homepage
├── cv.qmd                       # renders to cv.html + cv.pdf
├── research.qmd                 # research statement
├── publications/
│   ├── index.qmd                # publications page with graph + filters
│   ├── publications.bib         # canonical publication data
│   ├── network.js               # D3 visualization
│   └── filter.js                # filter UI logic
├── data/
│   ├── talks.yml
│   ├── teaching.yml
│   ├── grants.yml
│   ├── service.yml
│   ├── awards.yml
│   └── education.yml
├── scripts/
│   ├── csv_to_bib.R             # one-time migration of publications spreadsheet
│   └── bib_to_network.R         # build-step: generates network.json from .bib
├── assets/
│   └── cv-template.tex          # LaTeX template for PDF CV
├── styles.css
├── _quarto-pre-render.R         # runs bib_to_network.R before each build
└── README.md
```

## Component Specifications

### 1. CV (HTML + PDF)

**Source:** `cv.qmd` pulls from `publications.bib` and all `data/*.yml` files.

**Outputs:** 
- `cv.html` — embedded in the website navigation
- `cv.pdf` — stable filename, downloadable from the HTML CV page via a "Download PDF" button

**Page requirements:**
- Visible "Last updated: [date]" on the HTML CV page, auto-populated from Quarto build date
- The "Download PDF" button links to `cv.pdf`
- PDF uses a clean academic LaTeX template (single column, minimal color, professional). Adapt from `awesome-cv` or a similar template — confirm style with Ken before finalizing.
- Both versions show the same sections in the same order: Education, Appointments, Publications (grouped by type: peer-reviewed articles, books, chapters, other), Grants, Honors & Awards, Invited Talks, Teaching, Service.

### 2. Publications Page (the main feature)

**Page layout (desktop):**
- Top: brief intro paragraph
- Left column (60%): network graph
- Right column (40%): sticky filter panel + publication list

**Filter panel contains:**
- Keyword chips (clickable, multi-select)
- Outlet chips (clickable, multi-select)
- AND/OR toggle for keyword filtering (default: AND)
- "Clear filters" button
- Publication count: "Showing X of Y publications"

**Publication list below filters:**
- Updates live as filters change
- Each entry: authors, year, title, venue, links (DOI, PDF if available)
- Grouped by year, descending

**Network graph:**
- **Nodes:** publications only (unimodal). No keyword nodes.
- **Edges:** between two publications if they share ≥1 keyword. Edge weight = number of shared keywords. Visualize weight via edge thickness or opacity.
- **Layout:** D3 force-directed simulation
- **Node visual:** small circle, color-coded by primary outlet category (journal article / book / chapter / other) or by dominant research area — confirm with Ken
- **Hover:** show publication title in tooltip
- **Click on node:** opens a side detail panel with full citation, abstract (if available), and external links
- **Filter sync:** when filters are active, non-matching nodes dim to ~15% opacity; matching nodes stay full opacity; edges between two dimmed nodes also dim
- **Performance:** target ~50 nodes now, scaling to ~150 over the long term

**Mobile (<768px):**
- Hide graph entirely
- Show filter chips and publication list only
- Same filter logic

### 3. Network Data Pipeline

`scripts/bib_to_network.R` runs before each Quarto build (via `_quarto-pre-render.R`):

1. Parse `publications/publications.bib`
2. Extract for each entry: citation key, title, authors, year, venue, keywords (split on `;` or `,`), DOI, URL
3. Determine outlet from entry type:
   - `@article` → `journal` field
   - `@incollection` → `booktitle` field
   - `@inproceedings` → `booktitle` field
   - `@book` → `publisher` field
4. Compute pairwise shared-keyword counts; create edges where count ≥1, store count as `weight`
5. Emit `publications/network.json`:
```json
{
  "nodes": [
    {"id": "lin2024divested", "title": "...", "year": 2024, "outlet": "AJS", "keywords": ["financialization","inequality"], "type": "article", "doi": "..."}
  ],
  "edges": [
    {"source": "lin2024divested", "target": "smith2023labor", "weight": 2}
  ]
}
```
6. Also emit `publications/publications.json` (full publication list for the filter UI)

### 4. BibTeX Conventions

Each entry must have:
- `keywords = {kw1; kw2; kw3}` — semicolon-separated (Ken will curate these)
- Standard fields: `author`, `title`, `year`, `journal`/`booktitle`/`publisher`, `doi` or `url`

Optional custom fields Ken may use:
- `featured = {true}` — marks publications shown on the homepage "selected work" section
- `pdf = {path/to/file.pdf}` — if Ken wants to host PDFs directly

### 5. CSV to BibTeX Conversion Script

`scripts/csv_to_bib.R` is a one-time migration. Ken will provide his publications CSV. The script should:
- Read CSV (expect columns roughly: authors, year, title, venue, type, doi, keywords)
- Map type to BibTeX entry type
- Generate citation keys: `[firstAuthorLastName][year][firstSignificantWord]`
- Write `publications/publications.bib`
- Print any rows that failed validation for Ken to fix manually

Show Ken the script before running it; confirm column mapping based on his actual CSV structure.

### 6. Homepage (`index.qmd`)

- Header: name, title, affiliation, contact links (email, ORCID, Google Scholar, GitHub)
- Brief bio paragraph (Ken provides text)
- "Selected publications" — pull from `.bib` entries tagged `featured = {true}`
- Quick links to CV, full publications page, research statement

### 7. Research Statement (`research.qmd`)

Stub initially. Ken will draft content. Should have a structure that accommodates 2-3 paragraphs per research stream with links to representative publications.

### 8. Styling

- Clean, academic, readable. Think NYU/Princeton faculty pages, not flashy.
- System font stack or a serif like EB Garamond / Source Serif for body
- Generous whitespace
- Responsive but desktop-first (the graph is the centerpiece)
- Dark mode optional, only if trivially supported by the Quarto theme

## Deployment

1. Initialize git repo
2. Push to GitHub (Ken's account; private or public per his preference)
3. Connect Netlify to the GitHub repo with build command `quarto render` and publish directory `_site`
4. Test on the Netlify-assigned URL (e.g., `kenhoulin.netlify.app`)
5. Once Ken approves, point `kenhoulin.info` DNS to Netlify (he'll need to update the domain registrar's nameservers or A records)
6. Keep the existing Google Site live until the new site is verified working at the custom domain

## Working Notes for Claude Code

- Ken uses R Markdown for academic writing and knows R well; explanations using R idioms are welcome
- Ken prefers minimal viable technical setups over complex ones — favor simplicity in dependencies and tooling
- Ken's research streams are roughly: labor markets & inequality, gender, quantitative methods & prediction markets. The keyword taxonomy in the .bib should reflect these.
- Before each substantive design decision (CV template style, graph node coloring, color palette), surface options to Ken rather than guessing
- Build in this order: scaffolding → CV → homepage → publications page (graph last, since it's the most complex)
- Use the Quarto listings feature where appropriate (e.g., the publication list could be a Quarto listing styled with custom CSS, with the graph as an additional layer)
- Test the build end-to-end after each phase before moving on

## What Ken Will Provide

- Publications CSV (from his existing master spreadsheet)
- CV content for non-publication sections (talks, teaching, grants, service, awards, education)
- Bio text for homepage
- Photo (optional)
- Confirmation on visual style choices when prompted
- Domain access for DNS cutover
