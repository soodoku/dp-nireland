test_that("code sets are parsed without concatenating labels", {
  expect_equal(parse_code_set("4,5"), c(4L, 5L))
  expect_equal(parse_code_set("c4.c5"), c(4L, 5L))
  expect_equal(parse_code_set("c1, c5, 93"), c(1L, 5L, 93L))
  expect_length(parse_code_set("Vague"), 0L)
})

test_that("adjudication respects normalized agreement and unresolved conflict", {
  expect_equal(adjudicate_signature("4,5", "4,5", NA_character_), "4,5")
  expect_equal(adjudicate_signature("4", "5", "6"), "6")
  expect_true(is.na(adjudicate_signature("4", "5", NA_character_)))
  expect_equal(adjudicate_signature(NA_character_, "5", NA_character_), "5")
})

test_that("cluster-robust differences use group one minus group zero", {
  data <- data.frame(
    outcome = c(10, 12, 1, 3, 11, 2),
    group = c(1L, 1L, 0L, 0L, 1L, 0L),
    cluster = c("g1", "g1", "c1", "c2", "g2", "c3")
  )
  fit <- stats::lm(outcome ~ group, data = data)
  result <- cr2_term(fit, "group", data$cluster)
  expect_equal(result$estimate, 9)
  expect_lt(result$conf_low, result$estimate)
  expect_gt(result$conf_high, result$estimate)
})

test_that("controls and ungrouped participants are singleton clusters", {
  clusters <- discussion_cluster(
    participant = c(TRUE, TRUE, FALSE, FALSE),
    group_id = c(4, NA, NA, NA),
    respondent_id = 1:4
  )
  expect_equal(clusters, c("group_4", "respondent_2", "respondent_3", "respondent_4"))
})

test_that("argument balance is bounded and undefined without arguments", {
  expect_equal(argument_balance(3, 1), 0.5)
  expect_equal(argument_balance(1, 3), -0.5)
  expect_equal(argument_balance(c(4, 0), c(0, 4)), c(1, -1))
  expect_true(is.na(argument_balance(0, 0)))
  expect_true(is.na(argument_balance(NA_real_, 1)))
})
