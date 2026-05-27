#!/usr/bin/env Rscript
# bib_to_network.R — build-step: parse publications.bib → network.json + publications.json
# Called by _quarto-pre-render.R before each Quarto build.

suppressPackageStartupMessages({
  library(bib2df)    # install.packages("bib2df")
  library(dplyr)
  library(tidyr)
  library(jsonlite)
  library(stringr)
})

bib_path  <- "publications/publications.bib"
net_path  <- "publications/network.json"
pub_path  <- "publications/publications.json"

if (!file.exists(bib_path)) stop("publications.bib not found at: ", bib_path)

bib <- bib2df(bib_path)

# ── Normalize columns to lowercase ─────────────────────────────────────────
names(bib) <- str_to_lower(names(bib))

# ── Outlet: derive from entry type ─────────────────────────────────────────
outlet_col <- function(row) {
  type <- str_to_lower(row$category)
  if (type == "article")       return(row$journal  %||% "")
  if (type == "book")          return(row$publisher %||% "")
  if (type %in% c("incollection","inproceedings")) return(row$booktitle %||% "")
  return(row$howpublished %||% "")
}

`%||%` <- function(a, b) if (!is.null(a) && !is.na(a) && nchar(a) > 0) a else b

bib_type_map <- c(
  article       = "article",
  book          = "book",
  incollection  = "chapter",
  inproceedings = "chapter"
)

pubs <- bib |>
  rowwise() |>
  mutate(
    id       = str_to_lower(bibtexkey),
    type     = bib_type_map[str_to_lower(category)] %||% "other",
    outlet   = outlet_col(cur_data()),
    kw_raw   = keywords %||% "",
    keywords = list(str_trim(str_split(kw_raw, "[;,]")[[1]])),
    doi      = doi %||% "",
    url      = url %||% "",
    abstract = abstract %||% "",
    authors  = paste(unlist(author), collapse = "; "),
    featured = isTRUE(as.logical(featured %||% "false"))
  ) |>
  ungroup() |>
  select(id, title, authors, year, type, outlet, keywords, doi, url, abstract, featured)

# ── publications.json ───────────────────────────────────────────────────────
pub_list <- pubs |>
  mutate(year = as.integer(year)) |>
  arrange(desc(year))

write_json(pub_list, pub_path, auto_unbox = TRUE, pretty = TRUE)
message("Wrote ", pub_path, " (", nrow(pub_list), " entries)")

# ── Compute pairwise edges (shared keywords) ────────────────────────────────
nodes <- pub_list |>
  select(id, title, year, type, outlet, keywords, doi, url, abstract)

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
