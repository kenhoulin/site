#!/usr/bin/env Rscript
# check_dois.R — verify every DOI in publications.bib resolves to the matching paper.
#
# Why this exists: a DOI can be a valid, resolving identifier yet point to a
# DIFFERENT paper (e.g. an off-by-one suffix that lands on a real article).
# Such errors return HTTP 200, so an existence/404 check passes them. The only
# reliable test is to fetch each DOI's registered metadata from CrossRef and
# compare title + first-author surname + year back against the .bib entry.
#
# Usage:   Rscript scripts/check_dois.R
# Exit:    0 = all good, 1 = one or more mismatches (suitable for CI/hooks).

source("scripts/_libpaths.R")

suppressPackageStartupMessages({
  library(bib2df)
  library(dplyr)
  library(stringr)
  library(httr)
})

bib_path <- "publications/publications.bib"
mailto   <- "kenhoulin@utexas.edu"   # polite-pool contact for CrossRef
TITLE_SIM_MIN <- 0.90                 # accept titles >= 90% similar
YEAR_TOLERANCE <- 1                   # online-first vs print year can differ by 1

if (!file.exists(bib_path)) stop("publications.bib not found at: ", bib_path)

# bib2df warns on the abstract blank lines; we only need key/title/author/year/doi,
# so suppress and read directly (no abstract normalization needed here).
bib <- suppressWarnings(bib2df(bib_path))
names(bib) <- str_to_lower(names(bib))
if (!"doi" %in% names(bib)) bib$doi <- NA_character_

# ── helpers ────────────────────────────────────────────────────────────────
norm_title <- function(x) {
  x <- str_to_lower(x %||% "")
  x <- str_replace_all(x, "[^a-z0-9 ]", " ")  # drop punctuation
  x <- str_squish(x)
  x
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

# Levenshtein-based similarity in [0,1] using base R adist() — no extra deps.
# Publishers often register only the main title (no subtitle), so if the
# shorter normalized title is a prefix of the longer one, treat it as a match.
title_similarity <- function(a, b) {
  a <- norm_title(a); b <- norm_title(b)
  if (!nzchar(a) || !nzchar(b)) return(0)
  short <- if (nchar(a) <= nchar(b)) a else b
  long  <- if (nchar(a) <= nchar(b)) b else a
  if (startsWith(long, short)) return(1)         # subtitle-only difference
  d <- as.integer(adist(a, b))
  1 - d / max(nchar(a), nchar(b))
}

first_surname <- function(author_field) {
  # bib2df stores authors as a list-column of "Surname, Given" strings.
  a <- author_field[[1]]
  if (length(a) == 0) return("")
  str_to_lower(str_trim(str_split(a[1], ",")[[1]][1]))
}

fetch_crossref <- function(doi) {
  url <- paste0("https://api.crossref.org/works/", utils::URLencode(doi, reserved = TRUE))
  res <- tryCatch(
    GET(url, add_headers(`User-Agent` = paste0("doi-check (mailto:", mailto, ")")),
        timeout(20)),
    error = function(e) NULL
  )
  if (is.null(res) || status_code(res) != 200) return(NULL)
  m <- content(res, as = "parsed", type = "application/json")$message
  list(
    title   = if (length(m$title)) m$title[[1]] else "",
    surname = if (length(m$author)) str_to_lower(m$author[[1]]$family %||% "") else "",
    year    = tryCatch(
      m$issued$`date-parts`[[1]][[1]], error = function(e) NA_integer_
    )
  )
}

# ── run checks ───────────────────────────────────────────────────────────────
entries <- bib |> filter(!is.na(doi) & nzchar(str_trim(doi)))
message("Checking ", nrow(entries), " DOIs against CrossRef ...\n")

fail <- 0L
for (i in seq_len(nrow(entries))) {
  key <- entries$bibtexkey[i]
  doi <- str_trim(entries$doi[i])
  cr  <- fetch_crossref(doi)

  if (is.null(cr)) {
    cat(sprintf("FAIL  %-28s %s\n      -> DOI did not resolve on CrossRef\n",
                key, doi))
    fail <- fail + 1L
    Sys.sleep(0.2); next
  }

  sim       <- title_similarity(entries$title[i], cr$title)
  bib_sn    <- first_surname(entries$author[i])
  yr_bib    <- suppressWarnings(as.integer(entries$year[i]))
  yr_cr     <- suppressWarnings(as.integer(cr$year))
  title_ok  <- sim >= TITLE_SIM_MIN
  author_ok <- !nzchar(bib_sn) || !nzchar(cr$surname) || bib_sn == cr$surname
  year_ok   <- is.na(yr_bib) || is.na(yr_cr) || abs(yr_bib - yr_cr) <= YEAR_TOLERANCE

  if (title_ok && author_ok && year_ok) {
    cat(sprintf("ok    %-28s %s\n", key, doi))
  } else {
    fail <- fail + 1L
    cat(sprintf("FAIL  %-28s %s\n", key, doi))
    if (!title_ok)
      cat(sprintf("      -> title %.0f%%: bib=\"%s\" vs doi=\"%s\"\n",
                  100 * sim, entries$title[i], cr$title))
    if (!author_ok)
      cat(sprintf("      -> first author: bib=\"%s\" vs doi=\"%s\"\n",
                  bib_sn, cr$surname))
    if (!year_ok)
      cat(sprintf("      -> year: bib=%s vs doi=%s\n", yr_bib, yr_cr))
  }
  Sys.sleep(0.2)   # be polite to the API
}

cat(sprintf("\n%d checked, %d failed.\n", nrow(entries), fail))
if (fail > 0) quit(status = 1)
