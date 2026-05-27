#!/usr/bin/env Rscript
# _quarto-pre-render.R — runs before every `quarto render`
# Regenerates network.json and publications.json from publications.bib

source("scripts/bib_to_network.R")
