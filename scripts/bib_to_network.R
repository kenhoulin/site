#!/usr/bin/env Rscript
# bib_to_network.R — build-step: parse publications.bib → network.json + publications.json
# Called by _quarto-pre-render.R before each Quarto build.

# Include all user libraries (covers packages installed under earlier minor versions)
local({
  base <- file.path(Sys.getenv("USERPROFILE"), "AppData", "Local", "R", "win-library")
  libs <- list.dirs(base, recursive = FALSE, full.names = TRUE)
  libs <- libs[dir.exists(libs)]
  if (length(libs)) .libPaths(unique(c(libs, .libPaths())))
})

suppressPackageStartupMessages({
  library(bib2df)    # install.packages("bib2df")
  library(dplyr)
  library(tidyr)
  library(jsonlite)
  library(stringr)
  library(httr)
})

bib_path   <- "publications/publications.bib"
net_path   <- "publications/network.json"
pub_path   <- "publications/publications.json"
cache_path <- "publications/openalex_cache.json"
openalex_mailto <- "kenhoulin@utexas.edu"

if (!file.exists(bib_path)) stop("publications.bib not found at: ", bib_path)

# bib2df drops fields that contain blank lines inside the {...} block.
# Pre-process: inside abstract = {...}, replace paragraph breaks (blank lines)
# with a marker and flatten remaining newlines, so multi-paragraph abstracts
# survive parsing. The marker is restored to "\n\n" after parsing; the front-end
# turns "\n\n" into separate <p> elements.
PARA_MARK <- "@@PARA@@"
bib_raw  <- paste(readLines(bib_path, warn = FALSE), collapse = "\n")
bib_norm <- str_replace_all(
  bib_raw,
  regex("(abstract\\s*=\\s*\\{)([^{}]*)(\\})", ignore_case = TRUE),
  function(m) {
    parts <- str_match(m, regex("(?s)(abstract\\s*=\\s*\\{)([^{}]*)(\\})", ignore_case = TRUE))
    inner <- parts[, 3]
    inner <- str_replace_all(inner, "[ \\t]*\\n[ \\t]*\\n+[ \\t]*", PARA_MARK) # blank line → marker
    inner <- str_replace_all(inner, "[ \\t]*\\n[ \\t]*", " ")                  # soft wrap → space
    paste0(parts[, 2], inner, parts[, 4])
  }
)
tmp_bib <- tempfile(fileext = ".bib")
writeLines(bib_norm, tmp_bib)
bib <- bib2df(tmp_bib)

# ── Normalize columns to lowercase ─────────────────────────────────────────
names(bib) <- str_to_lower(names(bib))

# ── Ensure optional columns exist (bib2df omits columns absent from all entries)
for (col in c("doi", "url", "abstract", "keywords", "featured",
              "journal", "publisher", "booktitle", "howpublished")) {
  if (!col %in% names(bib)) bib[[col]] <- NA_character_
}

# ── Outlet: derive from entry type ─────────────────────────────────────────
na_to_empty <- function(x) ifelse(is.na(x) | !nchar(trimws(x)), "", trimws(x))

outlet_col <- function(row) {
  type <- str_to_lower(row$category)
  if (type == "article")                          return(na_to_empty(row$journal))
  if (type == "book")                             return(na_to_empty(row$publisher))
  if (type %in% c("incollection","inproceedings")) return(na_to_empty(row$booktitle))
  return(na_to_empty(row$howpublished))
}

bib_type_map <- c(
  article       = "article",
  book          = "book",
  incollection  = "chapter",
  inproceedings = "chapter"
)

# ── OpenAlex citation counts (cached to disk) ──────────────────────────────
cache <- if (file.exists(cache_path)) {
  tryCatch(fromJSON(cache_path, simplifyVector = FALSE), error = function(e) list())
} else list()

fetch_openalex_citations <- function(doi) {
  doi <- tolower(trimws(doi))
  if (!nzchar(doi)) return(NA_integer_)
  if (!is.null(cache[[doi]])) return(as.integer(cache[[doi]]))
  url <- paste0("https://api.openalex.org/works/doi:", doi,
                "?mailto=", openalex_mailto)
  res <- tryCatch(GET(url, timeout(15)), error = function(e) NULL)
  if (is.null(res) || status_code(res) != 200) {
    message("  OpenAlex miss for ", doi)
    return(NA_integer_)
  }
  body <- content(res, as = "parsed", type = "application/json")
  n <- body$cited_by_count
  if (is.null(n)) return(NA_integer_)
  cache[[doi]] <<- as.integer(n)
  Sys.sleep(0.1)
  as.integer(n)
}

pubs <- bib |>
  rowwise() |>
  mutate(
    id       = str_to_lower(bibtexkey),
    type     = { t <- bib_type_map[str_to_lower(category)]; if (is.na(t)) "other" else t },
    outlet   = suppressWarnings(outlet_col(cur_data())),
    kw_raw   = na_to_empty(.data[["keywords"]]),
    keywords = list(str_trim(str_split(kw_raw, "[;,]")[[1]])),
    doi      = na_to_empty(.data[["doi"]]),
    url      = na_to_empty(.data[["url"]]),
    abstract = str_replace_all(na_to_empty(.data[["abstract"]]), PARA_MARK, "\n\n"),
    authors  = paste(unlist(author), collapse = "; "),
    featured = isTRUE(as.logical(na_to_empty(.data[["featured"]])))
  ) |>
  ungroup() |>
  mutate(citations = vapply(doi, fetch_openalex_citations, integer(1))) |>
  select(id, title, authors, year, type, outlet, keywords, doi, url, abstract, featured, citations)

# Persist citation cache for next render
write_json(cache, cache_path, auto_unbox = TRUE, pretty = TRUE)

# ── publications.json ───────────────────────────────────────────────────────
pub_list <- pubs |>
  mutate(year = as.integer(year)) |>
  arrange(desc(year))

write_json(pub_list, pub_path, auto_unbox = TRUE, pretty = TRUE)
message("Wrote ", pub_path, " (", nrow(pub_list), " entries)")

# ── Compute pairwise edges (shared keywords) ────────────────────────────────
nodes <- pub_list |>
  select(id, title, year, type, outlet, keywords, doi, url, abstract, citations)

# explode keywords
kw_long <- pubs |>
  select(id, keywords) |>
  unnest(keywords) |>
  filter(nchar(keywords) > 0)

edges_raw <- inner_join(kw_long, kw_long, by = "keywords", relationship = "many-to-many") |>
  filter(id.x < id.y) |>   # each pair once, no self-loops
  group_by(source = id.x, target = id.y) |>
  summarise(weight = n(), .groups = "drop")

network <- list(nodes = nodes, edges = edges_raw)
write_json(network, net_path, auto_unbox = TRUE, pretty = TRUE)
message("Wrote ", net_path, " (", nrow(nodes), " nodes, ", nrow(edges_raw), " edges)")
