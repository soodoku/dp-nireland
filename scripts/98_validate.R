# Permanent gates for the rebuilt analysis and manuscript inputs.

survey <- readr::read_csv(file.path(DERIVED_DIR, "survey.csv"), show_col_types = FALSE)
respondent_wave <- readr::read_csv(
  file.path(DERIVED_DIR, "respondent_wave.csv"),
  show_col_types = FALSE
)
estimates <- readr::read_csv(file.path(TABLE_DIR, "main_estimates.csv"), show_col_types = FALSE)
directional_estimates <- readr::read_csv(
  file.path(TABLE_DIR, "directional_estimates.csv"),
  show_col_types = FALSE
)
results <- readRDS(file.path(DERIVED_DIR, "analysis_results.rds"))
count_ratio <- results$count_ratio
agreement <- readr::read_csv(file.path(AUDIT_DIR, "coder_agreement.csv"), show_col_types = FALSE)

t3 <- respondent_wave |>
  dplyr::filter(.data$wave == 3L, .data$participant_t3 | .data$control_t3)
participant_complete <- mean(!is.na(t3$primary_total[t3$participant_t3]))
control_complete <- mean(!is.na(t3$primary_total[t3$control_t3]))

assert_unique(survey, "respondent_id", "Survey")
assert_unique(respondent_wave, c("respondent_id", "wave"), "Respondent-wave data")

stopifnot(
  nrow(survey) == 274L,
  sum(survey$participant_t2) == 124L,
  sum(survey$participant_t3) == 93L,
  sum(survey$control_t3) == 150L,
  length(unique(stats::na.omit(survey$group_id[survey$participant_t2]))) == 20L,
  sum(survey$participant_t2 & is.na(survey$group_id)) == 1L,
  all(is.na(respondent_wave$primary_total[!respondent_wave$administered])),
  all(respondent_wave$primary_total[respondent_wave$administered] >= 0, na.rm = TRUE),
  all(respondent_wave$primary_total[respondent_wave$administered] <= 40, na.rm = TRUE),
  all(abs(respondent_wave$balance) <= 1, na.rm = TRUE),
  all(
    is.na(respondent_wave$balance[
      respondent_wave$supporting_total + respondent_wave$opposing_total == 0
    ])
  ),
  nrow(estimates) == 4L,
  nrow(count_ratio) == 1L,
  nrow(directional_estimates) == 8L,
  all(estimates$n > 0L),
  all(estimates$clusters >= 20L),
  all(estimates$degrees_freedom > 2),
  dplyr::between(count_ratio$estimate, 1.1, 1.2),
  all(directional_estimates$degrees_freedom > 2),
  nrow(results$directional_robustness) == 12L,
  nrow(results$item_wave_means) == 24L,
  nrow(results$item_contrasts) == 24L,
  sum(results$sample_composition$n[results$sample_composition$sample == "T2 participant"]) ==
    124L,
  agreement$slots == 21920L,
  agreement$normalized_disagreements >= agreement$unresolved_disagreements,
  agreement$agreement_rate > 0.9,
  dplyr::between(agreement$krippendorff_alpha, 0, 1),
  abs(participant_complete - control_complete) < 0.05
)

required <- c(
  file.path(TABLE_DIR, "numbers.tex"),
  file.path(TABLE_DIR, "main_estimates.tex"),
  file.path(TABLE_DIR, "directional_estimates.tex"),
  file.path(TABLE_DIR, "sample_composition.tex"),
  file.path(TABLE_DIR, "item_results.tex"),
  file.path(TABLE_DIR, "prompt_order.tex"),
  file.path(TABLE_DIR, "coding_sensitivity.tex"),
  file.path(TABLE_DIR, "directional_robustness.tex"),
  file.path(TABLE_DIR, "subgroup_results.tex"),
  file.path(FIGURE_DIR, "mean_reason_counts.pdf"),
  file.path(FIGURE_DIR, "argument_balance.pdf")
)
if (any(!file.exists(required))) stop("Missing generated artifacts.", call. = FALSE)

message("All analysis validation gates passed.")
