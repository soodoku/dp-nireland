# Prepare respondent-level sample membership and covariates from the raw export.

raw_survey <- arrow::read_parquet(SOURCE_SURVEY)
raw_groups <- arrow::read_parquet(SOURCE_GROUPS)

assert_columns(
  raw_survey,
  c(
    "cserial", "attend", "time3", "cgq36", "t1q2", "female", "religall",
    "degree", "t1q8", "t2q1c", "t3q1c", "t2q2a", "t3q2a", "t2q4c",
    "t3q4c", "t2q5g", "t3q5g"
  ),
  "Raw survey data"
)
assert_columns(
  raw_groups,
  c("poll_id", "respondent_id", "session_id", "group_id"),
  "Discussion-group data"
)

groups <- raw_groups |>
  dplyr::filter(
    .data$poll_id == "northern-ireland-2007",
    .data$session_id == "deliberation"
  ) |>
  dplyr::transmute(
    respondent_id = as.integer(.data$respondent_id),
    group_label = as.character(.data$group_id)
  )
assert_unique(groups, "respondent_id", "Discussion-group data")
stopifnot(nrow(groups) == 124L)

recode_five_point <- function(x) {
  dplyr::case_when(
    x == 1 ~ 0,
    x == 2 ~ 0.25,
    x == 3 ~ 0.5,
    x == 4 ~ 0.75,
    x == 5 ~ 1,
    TRUE ~ NA_real_
  )
}

survey_source <- raw_survey |>
  dplyr::mutate(respondent_id = as.integer(.data$cserial)) |>
  dplyr::left_join(groups, by = "respondent_id", relationship = "many-to-one") |>
  dplyr::mutate(
    participant_t2 = .data$attend %in% 1,
    control_t3 = !is.na(.data$cgq36),
    participant_t3 = !is.na(.data$time3) & !.data$control_t3
  )

survey_frame <- survey_source |>
  dplyr::transmute(
    respondent_id = .data$respondent_id,
    initial_interview = !is.na(.data$attend),
    participant_t2 = .data$participant_t2,
    participant_t3 = .data$participant_t3,
    control_t3 = .data$control_t3,
    age = as.numeric(.data$t1q2),
    female = as.integer(.data$female),
    catholic = dplyr::case_when(
      .data$religall == 1 ~ 1L,
      .data$religall == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),
    degree = as.integer(.data$degree)
  )

sample_counts <- tibble::tibble(
  sample = c("initial_interview", "participant_t2", "participant_t3", "control_t3"),
  n = c(
    sum(!is.na(survey_source$attend)),
    sum(survey_source$participant_t2, na.rm = TRUE),
    sum(survey_source$participant_t3, na.rm = TRUE),
    sum(survey_source$control_t3, na.rm = TRUE)
  )
)

survey <- survey_source |>
  dplyr::transmute(
    respondent_id = .data$respondent_id,
    participant_t2 = .data$participant_t2,
    participant_t3 = .data$participant_t3,
    control_t3 = .data$control_t3,
    group_id = .data$group_label,
    age = as.numeric(.data$t1q2),
    female = as.integer(.data$female),
    catholic = dplyr::case_when(
      .data$religall == 1 ~ 1L,
      .data$religall == 2 ~ 0L,
      TRUE ~ NA_integer_
    ),
    degree = as.integer(.data$degree),
    education = dplyr::case_when(
      .data$t1q8 == 1 ~ 1,
      .data$t1q8 %in% c(2, 3) ~ 0.66,
      .data$t1q8 %in% c(4, 5) ~ 0.33,
      .data$t1q8 %in% c(6, 7) ~ 0,
      TRUE ~ NA_real_
    ),
    t2q1cr = .data$t2q1c / 10,
    t3q1cr = .data$t3q1c / 10,
    t2q2ar = .data$t2q2a / 10,
    t3q2ar = .data$t3q2a / 10,
    t2q4cr = recode_five_point(.data$t2q4c),
    t3q4cr = recode_five_point(.data$t3q4c),
    t2q5gr = .data$t2q5g / 10,
    t3q5gr = .data$t3q5g / 10
  ) |>
  dplyr::filter(.data$participant_t2 | .data$control_t3)

assert_unique(survey, "respondent_id", "Prepared survey")
stopifnot(
  sum(survey$participant_t2) == 124L,
  sum(survey$participant_t3) == 93L,
  sum(survey$control_t3) == 150L,
  !any(survey$participant_t2 & survey$control_t3)
)

write_csv(survey, file.path(DERIVED_DIR, "survey.csv"))
write_csv(survey_frame, file.path(DERIVED_DIR, "survey_frame.csv"))
write_csv(sample_counts, file.path(DERIVED_DIR, "sample_counts.csv"))
