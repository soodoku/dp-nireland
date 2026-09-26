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
