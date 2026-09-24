test_that("external source hashes fail closed", {
  root <- tempfile()
  dir.create(root)
  writeLines("original", file.path(root, "source.csv"))
  manifest <- tempfile(fileext = ".yaml")
  yaml::write_yaml(list(sources = list(test = list(
    repository = "dp-data",
    path = "source.csv",
    sha256 = digest::digest(file.path(root, "source.csv"), algo = "sha256", file = TRUE)
  ))), manifest)
  expect_true(verify_manifest(manifest, root))
  writeLines("changed", file.path(root, "source.csv"))
  expect_error(verify_manifest(manifest, root), "Source hash mismatch")
  unlink(file.path(root, "source.csv"))
  expect_error(verify_manifest(manifest, root), "Missing source file")
})

test_that("numerical drift is reported and rejected", {
  root <- tempfile()
  dir.create(root)
  target <- file.path(root, "result.csv")
  writeLines(c("estimate", "1.5"), target)
  baseline <- tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(
    path = "result.csv",
    sha256 = digest::digest(target, algo = "sha256", file = TRUE)
  ), baseline)
  report <- tempfile(fileext = ".csv")
  expect_true(all(verify_numerical_baseline(baseline, root, report)$unchanged))
  writeLines(c("estimate", "1.6"), target)
  expect_error(verify_numerical_baseline(baseline, root, report), "Numerical baseline changed")
  comparison <- readr::read_csv(report, show_col_types = FALSE)
  expect_false(comparison$unchanged)
  expect_equal(comparison$path, "result.csv")
  unlink(target)
  expect_error(verify_numerical_baseline(baseline, root, report), "Numerical baseline changed")
})

test_that("all analytical sources are pinned public upstream files", {
  upstream <- SOURCE_MANIFEST$sources[
    vapply(SOURCE_MANIFEST$sources, function(x) {
      identical(x$repository, "dp-data")
    }, logical(1L))
  ]
  expect_length(upstream, 3L)
  expect_true(verify_manifest())
  expect_true(all(vapply(upstream, function(x) {
    startsWith(x$path, "data/northern-ireland-2007/")
  }, logical(1L))))
})
