# _libpaths.R — shared library-path bootstrap.
# Sourced by both bib_to_network.R and cv.qmd so packages installed under an
# earlier R minor version (e.g. bib2df) stay visible to whichever R runs the build.
local({
  base <- file.path(Sys.getenv("USERPROFILE"), "AppData", "Local", "R", "win-library")
  libs <- list.dirs(base, recursive = FALSE, full.names = TRUE)
  libs <- libs[dir.exists(libs)]
  if (length(libs)) .libPaths(unique(c(libs, .libPaths())))
})
