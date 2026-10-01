# Construct respondent-wave outcomes without converting unadministered waves to zero.

survey <- readr::read_csv(file.path(DERIVED_DIR, "survey.csv"), show_col_types = FALSE)
coding <- readRDS(file.path(DERIVED_DIR, "coding_sets.rds"))

is_valid_code <- function(code, question, include_low_credit = FALSE) {
  valid <- !(code %in% INVALID_CODES) & (code <= 90L | code %in% OTHER_VALID_CODES)
  if (!include_low_credit && question %in% LOW_CREDIT_QUESTIONS) {
    valid <- valid & code != 3L
  }
  valid
}

count_slot <- function(codes, question, include_low_credit = FALSE) {
  as.integer(any(is_valid_code(codes, question, include_low_credit)))
}

count_mentions <- function(codes, question, include_low_credit = FALSE) {
  sum(is_valid_code(codes, question, include_low_credit))
}

administered_sum <- function(x, administered, na_rm = FALSE) {
  if (dplyr::first(administered)) sum(x, na.rm = na_rm) else NA_real_
}

administered_relation_sum <- function(x, relation, target, administered) {
  if (!dplyr::first(administered)) {
    return(NA_real_)
  }
  selected <- x[!is.na(relation) & relation == target]
  if (length(selected) == 0L) NA_real_ else sum(selected)
}

slot_scores <- coding |>
  dplyr::mutate(
    question = paste0(.data$topic, .data$side),
    primary = purrr::map2_int(.data$codes, .data$question, count_slot),
    inclusive = purrr::map2_int(
      .data$codes,
      .data$question,
      ~ count_slot(.x, .y, include_low_credit = TRUE)
    ),
    mentions = purrr::map2_int(.data$codes, .data$question, count_mentions),
    coder_1 = purrr::map2_int(.data$coder_1_codes, .data$question, count_slot),
    coder_2 = purrr::map2_int(.data$coder_2_codes, .data$question, count_slot)
  )

slot_analysis <- slot_scores |>
  dplyr::select(
    "respondent_id", "wave", "topic", "side", "slot", "primary", "inclusive",
    "mentions", "coder_1", "coder_2", "unresolved"
  ) |>
  dplyr::left_join(survey, by = "respondent_id", relationship = "many-to-one") |>
  dplyr::mutate(
    administered = dplyr::case_when(
      .data$wave == 2L ~ .data$participant_t2,
      .data$wave == 3L ~ .data$participant_t3 | .data$control_t3,
      TRUE ~ FALSE
    ),
    participant = dplyr::case_when(
      .data$wave == 2L ~ .data$participant_t2,
      .data$wave == 3L ~ .data$participant_t3,
      TRUE ~ FALSE
    ),
    cluster_id = discussion_cluster(
      .data$participant,
      .data$group_id,
      .data$respondent_id
    )
  )

side_counts <- slot_scores |>
  dplyr::group_by(.data$respondent_id, .data$wave, .data$topic, .data$side) |>
  dplyr::summarise(
    primary = if (any(.data$unresolved)) NA_integer_ else sum(.data$primary),
    inclusive = if (any(.data$unresolved)) NA_integer_ else sum(.data$inclusive),
    mentions = if (any(.data$unresolved)) NA_integer_ else sum(.data$mentions),
    coder_1 = sum(.data$coder_1),
    coder_2 = sum(.data$coder_2),
    unresolved_slots = sum(.data$unresolved),
    .groups = "drop"
  ) |>
  dplyr::left_join(survey, by = "respondent_id", relationship = "many-to-one") |>
  dplyr::mutate(
    administered = dplyr::case_when(
      .data$wave == 2L ~ .data$participant_t2,
      .data$wave == 3L ~ .data$participant_t3 | .data$control_t3,
      TRUE ~ FALSE
    ),
    dplyr::across(
      c("primary", "inclusive", "mentions", "coder_1", "coder_2"),
      ~ dplyr::if_else(.data$administered, as.numeric(.x), NA_real_)
    ),
    pro_policy = .data$side == unname(PRO_POLICY_SIDE[.data$topic]),
    attitude_variable = paste0("t", .data$wave, ATTITUDE_VARIABLES[.data$topic]),
    attitude = purrr::map2_dbl(
      .data$respondent_id,
      .data$attitude_variable,
      function(id, variable) survey[[variable]][match(id, survey$respondent_id)]
    ),
    initial_attitude = dplyr::if_else(
      .data$participant_t2,
      purrr::map2_dbl(
        .data$respondent_id,
        ATTITUDE_VARIABLES[.data$topic],
        function(id, suffix) survey[[paste0("t2", suffix)]][match(id, survey$respondent_id)]
      ),
      .data$attitude
    ),
    supports_policy = dplyr::case_when(
      .data$initial_attitude > 0.5 ~ TRUE,
      .data$initial_attitude < 0.5 ~ FALSE,
      TRUE ~ NA
    ),
    relation = dplyr::case_when(
      is.na(.data$supports_policy) ~ NA_character_,
      .data$pro_policy == .data$supports_policy ~ "supporting",
      TRUE ~ "opposing"
    )
  )

respondent_wave <- side_counts |>
  dplyr::group_by(.data$respondent_id, .data$wave) |>
  dplyr::summarise(
    administered = dplyr::first(.data$administered),
    participant_t2 = dplyr::first(.data$participant_t2),
    participant_t3 = dplyr::first(.data$participant_t3),
    control_t3 = dplyr::first(.data$control_t3),
    group_id = dplyr::first(.data$group_id),
    age = dplyr::first(.data$age),
    female = dplyr::first(.data$female),
    catholic = dplyr::first(.data$catholic),
    degree = dplyr::first(.data$degree),
    primary_total = administered_sum(.data$primary, .data$administered),
    inclusive_total = administered_sum(.data$inclusive, .data$administered),
    mention_total = administered_sum(.data$mentions, .data$administered),
    coder_1_total = administered_sum(.data$coder_1, .data$administered, na_rm = TRUE),
    coder_2_total = administered_sum(.data$coder_2, .data$administered, na_rm = TRUE),
    supporting_total = administered_relation_sum(
      .data$primary, .data$relation, "supporting", .data$administered
    ),
    opposing_total = administered_relation_sum(
      .data$primary, .data$relation, "opposing", .data$administered
    ),
    supporting_inclusive_total = administered_relation_sum(
      .data$inclusive, .data$relation, "supporting", .data$administered
    ),
    opposing_inclusive_total = administered_relation_sum(
      .data$inclusive, .data$relation, "opposing", .data$administered
    ),
    supporting_coder_1_total = administered_relation_sum(
      .data$coder_1, .data$relation, "supporting", .data$administered
    ),
    opposing_coder_1_total = administered_relation_sum(
      .data$coder_1, .data$relation, "opposing", .data$administered
    ),
    supporting_coder_2_total = administered_relation_sum(
      .data$coder_2, .data$relation, "supporting", .data$administered
    ),
    opposing_coder_2_total = administered_relation_sum(
      .data$coder_2, .data$relation, "opposing", .data$administered
    ),
    classified_topics = if (dplyr::first(.data$administered)) {
      sum(.data$relation == "supporting", na.rm = TRUE)
    } else {
      NA_integer_
    },
    unresolved_slots = sum(.data$unresolved_slots),
    .groups = "drop"
  )

respondent_wave <- respondent_wave |>
  dplyr::mutate(
    supporting_mean = .data$supporting_total / .data$classified_topics,
    opposing_mean = .data$opposing_total / .data$classified_topics,
    balance = argument_balance(.data$supporting_total, .data$opposing_total),
    absolute_imbalance = abs(.data$balance),
    inclusive_balance = argument_balance(
      .data$supporting_inclusive_total,
      .data$opposing_inclusive_total
    ),
    inclusive_absolute_imbalance = abs(.data$inclusive_balance),
    coder_1_balance = argument_balance(
      .data$supporting_coder_1_total,
      .data$opposing_coder_1_total
    ),
    coder_1_absolute_imbalance = abs(.data$coder_1_balance),
    coder_2_balance = argument_balance(
      .data$supporting_coder_2_total,
      .data$opposing_coder_2_total
    ),
    coder_2_absolute_imbalance = abs(.data$coder_2_balance)
  )

stopifnot(
  sum(respondent_wave$administered & respondent_wave$wave == 2L) == 124L,
  sum(respondent_wave$administered & respondent_wave$wave == 3L) == 243L,
  all(is.na(respondent_wave$primary_total[!respondent_wave$administered]))
)

write_csv(side_counts, file.path(DERIVED_DIR, "side_counts.csv"))
write_csv(slot_analysis, file.path(DERIVED_DIR, "slot_analysis.csv"))
write_csv(respondent_wave, file.path(DERIVED_DIR, "respondent_wave.csv"))
