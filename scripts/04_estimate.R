# Estimate the descriptive and associational contrasts reported in the paper.

respondent_wave <- readr::read_csv(
  file.path(DERIVED_DIR, "respondent_wave.csv"),
  show_col_types = FALSE
)
side_counts <- readr::read_csv(
  file.path(DERIVED_DIR, "side_counts.csv"),
  show_col_types = FALSE
)
slot_analysis <- readr::read_csv(
  file.path(DERIVED_DIR, "slot_analysis.csv"),
  show_col_types = FALSE
)
survey_frame <- readr::read_csv(
  file.path(DERIVED_DIR, "survey_frame.csv"),
  show_col_types = FALSE
)

clustered_difference <- function(data, outcome) {
  fit_data <- data |>
    dplyr::transmute(
      value = .data[[outcome]],
      participant = as.integer(.data$participant),
      cluster_id = .data$cluster_id
    ) |>
    dplyr::filter(!is.na(.data$value))
  fit <- stats::lm(value ~ participant, data = fit_data)
  cr2_term(fit, "participant", fit_data$cluster_id)
}

clustered_change <- function(data, outcome) {
  change <- data[[paste0("t3_", outcome)]] - data[[paste0("t2_", outcome)]]
  keep <- !is.na(change)
  fit <- stats::lm(change[keep] ~ 1)
  cr2_term(fit, "(Intercept)", data$cluster_id[keep])
}

t3 <- respondent_wave |>
  dplyr::filter(.data$wave == 3L, .data$participant_t3 | .data$control_t3) |>
  dplyr::mutate(
    participant = as.integer(.data$participant_t3),
    cluster_id = discussion_cluster(
      .data$participant_t3,
      .data$group_id,
      .data$respondent_id
    )
  )

t2 <- respondent_wave |>
  dplyr::filter(.data$wave == 2L, .data$participant_t2) |>
  dplyr::mutate(
    participant = 1L,
    cluster_id = discussion_cluster(TRUE, .data$group_id, .data$respondent_id)
  )

paired <- t2 |>
  dplyr::select(
    "respondent_id", "cluster_id",
    t2_primary_total = "primary_total",
    t2_supporting_total = "supporting_total",
    t2_opposing_total = "opposing_total",
    t2_balance = "balance",
    t2_absolute_imbalance = "absolute_imbalance",
    t2_inclusive_balance = "inclusive_balance",
    t2_inclusive_absolute_imbalance = "inclusive_absolute_imbalance",
    t2_coder_1_balance = "coder_1_balance",
    t2_coder_1_absolute_imbalance = "coder_1_absolute_imbalance",
    t2_coder_2_balance = "coder_2_balance",
    t2_coder_2_absolute_imbalance = "coder_2_absolute_imbalance"
  ) |>
  dplyr::inner_join(
    t3 |>
      dplyr::filter(.data$participant_t3) |>
      dplyr::select(
        "respondent_id",
        t3_primary_total = "primary_total",
        t3_supporting_total = "supporting_total",
        t3_opposing_total = "opposing_total",
        t3_balance = "balance",
        t3_absolute_imbalance = "absolute_imbalance",
        t3_inclusive_balance = "inclusive_balance",
        t3_inclusive_absolute_imbalance = "inclusive_absolute_imbalance",
        t3_coder_1_balance = "coder_1_balance",
        t3_coder_1_absolute_imbalance = "coder_1_absolute_imbalance",
        t3_coder_2_balance = "coder_2_balance",
        t3_coder_2_absolute_imbalance = "coder_2_absolute_imbalance"
      ),
    by = "respondent_id",
    relationship = "one-to-one"
  )

group_means <- dplyr::bind_rows(
  cr2_mean(
    t3$primary_total[t3$control_t3],
    t3$cluster_id[t3$control_t3]
  ) |>
    dplyr::mutate(sample = "T3 control", order = 1L),
  cr2_mean(t2$primary_total, t2$cluster_id) |>
    dplyr::mutate(sample = "T2 participant", order = 2L),
  cr2_mean(
    t3$primary_total[t3$participant_t3],
    t3$cluster_id[t3$participant_t3]
  ) |>
    dplyr::mutate(sample = "T3 participant", order = 3L)
)

unadjusted_data <- t3 |>
  dplyr::filter(!is.na(.data$primary_total))
unadjusted_fit <- stats::lm(primary_total ~ participant, data = unadjusted_data)
unadjusted <- cr2_term(
  unadjusted_fit,
  "participant",
  unadjusted_data$cluster_id
) |>
  dplyr::mutate(
    contrast = "T3 participant minus T3 control",
    specification = "Unadjusted, partially clustered CR2"
  )

ratio_fit <- stats::glm(
  primary_total ~ participant,
  family = stats::poisson(link = "log"),
  data = unadjusted_data
)
count_ratio <- cr2_term(
  ratio_fit,
  "participant",
  unadjusted_data$cluster_id
) |>
  dplyr::mutate(
    dplyr::across(c("estimate", "conf_low", "conf_high"), exp),
    contrast = "T3 participant divided by T3 control",
    specification = "Poisson mean ratio, partially clustered CR2"
  )

adjusted_data <- t3 |>
  dplyr::filter(
    !is.na(.data$primary_total),
    !is.na(.data$age),
    !is.na(.data$female),
    !is.na(.data$catholic),
    !is.na(.data$degree)
  )
adjusted_fit <- stats::lm(
  primary_total ~ participant + age + female + catholic + degree,
  data = adjusted_data
)
adjusted <- cr2_term(adjusted_fit, "participant", adjusted_data$cluster_id) |>
  dplyr::mutate(
    contrast = "T3 participant minus T3 control",
    specification = paste(
      "Adjusted for age, sex, religion, and degree;",
      "partially clustered CR2"
    )
  )

paired_change <- clustered_change(paired, "primary_total") |>
  dplyr::mutate(
    contrast = "T3 minus T2 among participants",
    specification = "Paired, group-clustered CR2"
  )

t2_control <- dplyr::bind_rows(
  t2 |>
    dplyr::transmute(
      value = .data$primary_total,
      participant = 1L,
      cluster_id = .data$cluster_id
    ),
  t3 |>
    dplyr::filter(.data$control_t3) |>
    dplyr::transmute(
      value = .data$primary_total,
      participant = 0L,
      cluster_id = .data$cluster_id
    )
) |>
  dplyr::filter(!is.na(.data$value))
secondary_fit <- stats::lm(value ~ participant, data = t2_control)
secondary <- cr2_term(
  secondary_fit,
  "participant",
  t2_control$cluster_id
) |>
  dplyr::mutate(
    contrast = "T2 participant minus T3 control",
    specification = "Noncontemporaneous, partially clustered CR2"
  )

robustness <- purrr::map_dfr(
  c("inclusive_total", "mention_total", "coder_1_total", "coder_2_total"),
  function(outcome) {
    clustered_difference(t3, outcome) |>
      dplyr::mutate(outcome = outcome)
  }
)

directional_outcomes <- c(
  "supporting_total", "opposing_total", "balance", "absolute_imbalance"
)

directional_means <- purrr::map_dfr(
  directional_outcomes,
  function(outcome) {
    dplyr::bind_rows(
      cr2_mean(
        t3[[outcome]][t3$control_t3],
        t3$cluster_id[t3$control_t3]
      ) |>
        dplyr::mutate(sample = "T3 control"),
      cr2_mean(
        t3[[outcome]][t3$participant_t3],
        t3$cluster_id[t3$participant_t3]
      ) |>
        dplyr::mutate(sample = "T3 participant"),
      cr2_mean(t2[[outcome]], t2$cluster_id) |>
        dplyr::mutate(sample = "T2 participant")
    ) |>
      dplyr::mutate(outcome = outcome)
  }
)

directional_estimates <- purrr::map_dfr(
  directional_outcomes,
  function(outcome) {
    dplyr::bind_rows(
      clustered_difference(t3, outcome) |>
        dplyr::mutate(comparison = "T3 participant minus T3 control"),
      clustered_change(paired, outcome) |>
        dplyr::mutate(comparison = "Participant change, T3 minus T2")
    ) |>
      dplyr::mutate(outcome = outcome)
  }
)

directional_robustness <- purrr::map_dfr(
  c(
    "inclusive_balance", "inclusive_absolute_imbalance",
    "coder_1_balance", "coder_1_absolute_imbalance",
    "coder_2_balance", "coder_2_absolute_imbalance"
  ),
  function(outcome) {
    dplyr::bind_rows(
      clustered_difference(t3, outcome) |>
        dplyr::mutate(comparison = "T3 participant minus T3 control"),
      clustered_change(paired, outcome) |>
        dplyr::mutate(comparison = "Participant change, T3 minus T2")
    ) |>
      dplyr::mutate(outcome = outcome)
  }
)

item_data <- side_counts |>
  dplyr::filter(.data$administered) |>
  dplyr::mutate(
    sample = dplyr::case_when(
      .data$wave == 2L ~ "T2 participant",
      .data$participant_t3 ~ "T3 participant",
      TRUE ~ "T3 control"
    ),
    participant = as.integer(dplyr::if_else(
      .data$wave == 2L,
      .data$participant_t2,
      .data$participant_t3
    )),
    cluster_id = discussion_cluster(
      .data$participant == 1L,
      .data$group_id,
      .data$respondent_id
    )
  )

item_wave_means <- item_data |>
  dplyr::group_by(.data$topic, .data$side, .data$sample) |>
  dplyr::group_modify(~ cr2_mean(.x$primary, .x$cluster_id)) |>
  dplyr::ungroup()

item_t3_contrasts <- item_data |>
  dplyr::filter(.data$wave == 3L) |>
  dplyr::group_by(.data$topic, .data$side) |>
  dplyr::group_modify(~ clustered_difference(.x, "primary")) |>
  dplyr::ungroup() |>
  dplyr::mutate(comparison = "T3 participant minus T3 control")

item_t2_control_contrasts <- item_data |>
  dplyr::filter(.data$wave == 2L | .data$control_t3) |>
  dplyr::group_by(.data$topic, .data$side) |>
  dplyr::group_modify(~ clustered_difference(.x, "primary")) |>
  dplyr::ungroup() |>
  dplyr::mutate(comparison = "T2 participant minus T3 control")

item_paired <- item_data |>
  dplyr::filter(.data$participant_t3) |>
  dplyr::select(
    "respondent_id", "cluster_id", "topic", "side", "wave", "primary"
  ) |>
  tidyr::pivot_wider(names_from = "wave", names_prefix = "t", values_from = "primary") |>
  dplyr::filter(!is.na(.data$t2), !is.na(.data$t3)) |>
  dplyr::mutate(change = .data$t3 - .data$t2)
item_paired_contrasts <- item_paired |>
  dplyr::group_by(.data$topic, .data$side) |>
  dplyr::group_modify(function(.x, .y) {
    fit <- stats::lm(change ~ 1, data = .x)
    cr2_term(fit, "(Intercept)", .x$cluster_id)
  }) |>
  dplyr::ungroup() |>
  dplyr::mutate(comparison = "Participant change, T3 minus T2")

item_contrasts <- dplyr::bind_rows(
  item_t3_contrasts,
  item_t2_control_contrasts,
  item_paired_contrasts
)

prompt_data <- slot_analysis |>
  dplyr::filter(.data$wave == 3L, .data$administered, !.data$unresolved) |>
  dplyr::transmute(
    primary = .data$primary,
    participant = as.integer(.data$participant),
    slot_order = .data$slot - 1L,
    topic = factor(.data$topic),
    side = factor(.data$side),
    cluster_id = .data$cluster_id
  )
prompt_fit <- stats::lm(
  primary ~ participant * slot_order + topic + side,
  data = prompt_data
)
prompt_order <- purrr::map_dfr(
  c("participant", "slot_order", "participant:slot_order"),
  function(term) {
    cr2_term(prompt_fit, term, prompt_data$cluster_id) |>
      dplyr::mutate(term = term)
  }
)

composition_long <- dplyr::bind_rows(
  survey_frame |>
    dplyr::filter(.data$initial_interview, !.data$participant_t2) |>
    dplyr::mutate(sample = "T1 nonparticipant"),
  survey_frame |>
    dplyr::filter(.data$participant_t2) |>
    dplyr::mutate(sample = "T2 participant"),
  survey_frame |>
    dplyr::filter(.data$participant_t2, !.data$participant_t3) |>
    dplyr::mutate(sample = "T3 nonreturning participant"),
  survey_frame |>
    dplyr::filter(.data$participant_t3) |>
    dplyr::mutate(sample = "T3 returning participant"),
  survey_frame |>
    dplyr::filter(.data$control_t3) |>
    dplyr::mutate(sample = "T3 control")
)

sample_composition <- composition_long |>
  dplyr::group_by(.data$sample) |>
  dplyr::summarise(
    n = dplyr::n(),
    age_n = sum(!is.na(.data$age)),
    female_n = sum(!is.na(.data$female)),
    catholic_n = sum(!is.na(.data$catholic)),
    degree_n = sum(!is.na(.data$degree)),
    age = mean(.data$age, na.rm = TRUE),
    female = mean(.data$female, na.rm = TRUE),
    catholic = mean(.data$catholic, na.rm = TRUE),
    degree = mean(.data$degree, na.rm = TRUE),
    .groups = "drop"
  )

subgroup_data <- t3 |>
  dplyr::filter(!is.na(.data$catholic)) |>
  dplyr::mutate(
    community = dplyr::if_else(.data$catholic == 1L, "Catholic", "Protestant")
  )
subgroup_means <- subgroup_data |>
  dplyr::mutate(sample = dplyr::if_else(
    .data$participant_t3,
    "T3 participant",
    "T3 control"
  )) |>
  dplyr::group_by(.data$community, .data$sample) |>
  dplyr::group_modify(~ cr2_mean(.x$primary_total, .x$cluster_id)) |>
  dplyr::ungroup()
subgroup_estimates <- subgroup_data |>
  dplyr::group_by(.data$community) |>
  dplyr::group_modify(~ clustered_difference(.x, "primary_total")) |>
  dplyr::ungroup()

estimates <- dplyr::bind_rows(unadjusted, adjusted, paired_change, secondary)

analysis_results <- list(
  group_means = group_means,
  estimates = estimates,
  count_ratio = count_ratio,
  robustness = robustness,
  directional_means = directional_means,
  directional_estimates = directional_estimates,
  directional_robustness = directional_robustness,
  item_wave_means = item_wave_means,
  item_contrasts = item_contrasts,
  prompt_order = prompt_order,
  sample_composition = sample_composition,
  subgroup_means = subgroup_means,
  subgroup_estimates = subgroup_estimates
)

saveRDS(analysis_results, file.path(DERIVED_DIR, "analysis_results.rds"))
write_csv(estimates, file.path(TABLE_DIR, "main_estimates.csv"))
write_csv(directional_estimates, file.path(TABLE_DIR, "directional_estimates.csv"))
