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

test_that("estimate references tolerate roundoff but reject substantive drift", {
  root <- tempfile()
  dir.create(root)
  reference <- file.path(root, "reference.csv")
  target <- file.path(root, "estimate.csv")
  baseline <- file.path(root, "baseline.csv")
  report <- file.path(root, "comparison.csv")
  data <- tibble::tibble(estimate = c(1.5, 2), n = c(10, 20), label = c("a", "b"))
  readr::write_csv(data, reference)
  readr::write_csv(tibble::tibble(
    path = "estimate.csv", reference_path = "reference.csv",
    sha256 = digest::digest(reference, algo = "sha256", file = TRUE)
  ), baseline)
  data$estimate[1] <- 1.5 + 5e-11
  readr::write_csv(data, target)
  result <- verify_numerical_baseline(baseline, root, report)
  expect_false(result$unchanged)
  expect_true(result$equivalent)
  expect_gt(result$max_absolute_difference, 0)
  data$estimate[1] <- 1.51
  readr::write_csv(data, target)
  expect_error(verify_numerical_baseline(baseline, root, report), "Numerical baseline changed")
  data$estimate[1] <- 1.5
  data$n[1] <- 11
  readr::write_csv(data, target)
  expect_false(compare_estimate_reference(target, reference)$equivalent)
  data$n[1] <- 10
  data$label[1] <- "changed"
  readr::write_csv(data, target)
  expect_false(compare_estimate_reference(target, reference)$equivalent)
  data$label[1] <- "a"
  data$estimate[1] <- NA_real_
  readr::write_csv(data, target)
  expect_false(compare_estimate_reference(target, reference)$equivalent)
  data$estimate[1] <- Inf
  readr::write_csv(data, target)
  expect_false(compare_estimate_reference(target, reference)$equivalent)
  readr::write_csv(data[2:1, ], target)
  expect_false(compare_estimate_reference(target, reference)$equivalent)
  readr::write_csv(data[-1, ], target)
  expect_false(compare_estimate_reference(target, reference)$equivalent)
  writeLines("tampered", reference)
  expect_error(verify_numerical_baseline(baseline, root, report), "reference hash mismatch")
})
