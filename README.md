# kenhoulin.info — Academic Website

Personal academic website for Ken-Hou Lin, Professor of Sociology at UT Austin.
Built with [Quarto](https://quarto.org). Hosted on GitHub Pages at `kenhoulin.info`.

## Quick start

```bash
# Prerequisites: Quarto + R. Required R packages are auto-installed by the
# build step (scripts/bib_to_network.R); to pre-install them manually:
# install.packages(c("bib2df", "dplyr", "tidyr", "jsonlite", "stringr", "httr", "readr", "bibtex"))

quarto render        # builds _site/
quarto preview       # live preview at localhost:4242
```

## Project structure

```
_quarto.yml                  site config + pre-render hook
index.qmd                    homepage
cv.qmd                       CV (HTML + PDF)
research.qmd                 research statement
publications/
  index.qmd                  publications page (graph + filters)
  publications.bib           canonical publication data  ← edit here
  network.js                 D3 force-directed graph
  filter.js                  filter chip UI
data/                        YAML files for CV sections (talks, teaching, etc.)
scripts/
  csv_to_bib.R               one-time CSV → .bib migration
  bib_to_network.R           build-step: .bib → network.json + publications.json
assets/
  cv-template.tex            LaTeX CV template
```

## Adding a publication

Edit `publications/publications.bib` directly, then `quarto render` to rebuild.

## Deployment

Hosted on GitHub Pages. There is no CI build — deploy manually from a clean
working tree:

```bash
quarto publish gh-pages   # renders, then pushes _site/ to the gh-pages branch
```

GitHub Pages serves the `gh-pages` branch at `kenhoulin.info` (see `CNAME`).
Commit source changes to `main` separately; only `gh-pages` is the live site.
