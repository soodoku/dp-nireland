test_that("analysis keeps unadministered waves missing", {
  skip_if_not(file.exists(file.path(DERIVED_DIR, "respondent_wave.csv")))
  data <- readr::read_csv(
    file.path(DERIVED_DIR, "respondent_wave.csv"),
    show_col_types = FALSE
  )
  expect_true(all(is.na(data$primary_total[!data$administered])))
  expect_equal(sum(data$administered & data$wave == 2L), 124L)
  expect_equal(sum(data$administered & data$wave == 3L), 243L)
  expect_true(all(abs(data$balance) <= 1, na.rm = TRUE))
  zero_arguments <- data$supporting_total + data$opposing_total == 0
  expect_true(all(is.na(data$balance[zero_arguments])))
})

test_that("respondent identifiers and analysis keys are unique", {
  skip_if_not(file.exists(file.path(DERIVED_DIR, "survey.csv")))
  survey <- readr::read_csv(file.path(DERIVED_DIR, "survey.csv"), show_col_types = FALSE)
  wave <- readr::read_csv(
    file.path(DERIVED_DIR, "respondent_wave.csv"),
    show_col_types = FALSE
  )
  expect_equal(anyDuplicated(survey$respondent_id), 0L)
  expect_equal(anyDuplicated(paste(wave$respondent_id, wave$wave)), 0L)
  expect_equal(length(unique(stats::na.omit(survey$group_id[survey$participant_t2]))), 20L)
  expect_equal(sum(survey$participant_t2 & is.na(survey$group_id)), 0L)
  expect_equal(survey$group_id[survey$respondent_id == 112084],
               survey$group_id[survey$respondent_id == 172082])
  expect_equal(survey$group_id[survey$respondent_id == 112084], "N")
})

test_that("survey variables are rebuilt from raw columns", {
  survey <- readr::read_csv(file.path(DERIVED_DIR, "survey.csv"), show_col_types = FALSE)
  raw <- arrow::read_parquet(SOURCE_SURVEY) |>
    dplyr::transmute(
      respondent_id = as.integer(.data$cserial),
      attend = .data$attend,
      cgq36 = .data$cgq36,
      t2q1c = .data$t2q1c,
      t3q1c = .data$t3q1c,
      t2q2a = .data$t2q2a,
      t3q2a = .data$t3q2a,
      t2q5g = .data$t2q5g,
      t3q5g = .data$t3q5g
    )
  comparison <- survey |>
    dplyr::left_join(raw, by = "respondent_id", relationship = "one-to-one")

  expect_equal(comparison$participant_t2, comparison$attend %in% 1)
  expect_equal(comparison$control_t3, !is.na(comparison$cgq36))
  expect_equal(comparison$t2q1cr, comparison$t2q1c / 10)
  expect_equal(comparison$t3q1cr, comparison$t3q1c / 10)
  expect_equal(comparison$t2q2ar, comparison$t2q2a / 10)
  expect_equal(comparison$t3q2ar, comparison$t3q2a / 10)
  expect_equal(comparison$t2q5gr, comparison$t2q5g / 10)
  expect_equal(comparison$t3q5gr, comparison$t3q5g / 10)
})
