options(warn = 1)

font_cache <- file.path(tempdir(), "fontconfig-cache")
dir.create(font_cache, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(XDG_CACHE_HOME = font_cache)

required <- c(
  "here", "dplyr", "tidyr", "readr", "stringr", "purrr", "ggplot2",
  "clubSandwich", "tibble", "yaml", "digest", "knitr"
)
missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Install missing packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

source(here::here("scripts", "00_config.R"))
source(here::here("scripts", "00_utils.R"))
verify_manifest()

dir.create(DERIVED_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIGURE_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TABLE_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(AUDIT_DIR, recursive = TRUE, showWarnings = FALSE)

for (script in c(
  "01_prepare_survey.R",
  "02_prepare_coding.R",
  "03_build_analysis.R",
  "04_estimate.R",
  "05_exhibits.R",
  "98_validate.R"
)) {
  message("Running scripts/", script)
  source(here::here("scripts", script), local = new.env(parent = globalenv()))
}
