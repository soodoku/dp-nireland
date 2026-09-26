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

test_that("all analytical sources are pinned public upstream files", {
  upstream <- SOURCE_MANIFEST$sources[
    vapply(SOURCE_MANIFEST$sources, function(x) {
      identical(x$repository, "dp-data")
    }, logical(1L))
  ]
  expect_length(upstream, 3L)
  expect_true(verify_manifest())
  expect_true(all(vapply(upstream, function(x) {
    startsWith(x$path, "data/northern-ireland-2007/") ||
      identical(x$path, "output/memberships.parquet")
  }, logical(1L))))
})
