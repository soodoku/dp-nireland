test_that("external source hashes fail closed", {
  root <- tempfile()
  dir.create(root)
  writeLines("original", file.path(root, "source.csv"))
  manifest <- tempfile(fileext = ".yaml")
  yaml::write_yaml(list(sources = list(test = list(
    path = "source.csv",
    sha256 = digest::digest(file.path(root, "source.csv"), algo = "sha256", file = TRUE)
  ))), manifest)
  expect_true(verify_manifest(manifest, root))
  writeLines("changed", file.path(root, "source.csv"))
  expect_error(verify_manifest(manifest, root), "Source hash mismatch")
  unlink(file.path(root, "source.csv"))
  expect_error(verify_manifest(manifest, root), "Missing source file")
})

test_that("only analytical inputs are pinned", {
  sources <- SOURCE_MANIFEST$sources
  expect_setequal(names(sources), c("survey", "discussion_groups", "open_ended_coding"))
  expect_true(verify_manifest())
  expect_true(all(vapply(sources, function(x) {
    startsWith(x$path, "data/northern-ireland-2007/") ||
      identical(x$path, "output/memberships.parquet")
  }, logical(1L))))
})

test_that("published coding preserves comma-separated source labels", {
  codes <- arrow::read_parquet(SOURCE_CODING)
  examples <- tibble::tribble(
    ~respondent_id, ~wave, ~topic, ~side, ~slot, ~coder, ~raw_code,
    131201L, 2L, 21L, "b", 1L, "ch", "1,3",
    131201L, 2L, 21L, "b", 1L, "la", "1,3",
    147026L, 2L, 19L, "a", 4L, "monty", "4,93",
    272038L, 2L, 20L, "b", 1L, "monty", "5,93"
  )
  actual <- dplyr::inner_join(
    examples, codes,
    by = c("respondent_id", "wave", "topic", "side", "slot", "coder"),
    suffix = c("_expected", "_actual"), relationship = "one-to-one"
  )
  expect_equal(nrow(actual), nrow(examples))
  expect_identical(actual$raw_code_actual, actual$raw_code_expected)
  expect_equal(adjudicate_signature(
    code_signature(actual$raw_code_actual[[1L]]),
    code_signature(actual$raw_code_actual[[2L]]), NA_character_
  ), "1,3")
})
