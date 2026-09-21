# Generate all manuscript exhibits and inline analytical numbers.

results <- readRDS(file.path(DERIVED_DIR, "analysis_results.rds"))
group_means <- results$group_means
estimates <- results$estimates
count_ratio <- results$count_ratio
robustness <- results$robustness
directional_means <- results$directional_means
directional_estimates <- results$directional_estimates
directional_robustness <- results$directional_robustness
item_wave_means <- results$item_wave_means
item_contrasts <- results$item_contrasts
prompt_order <- results$prompt_order
sample_composition <- results$sample_composition
subgroup_means <- results$subgroup_means
subgroup_estimates <- results$subgroup_estimates
coder_audit <- readr::read_csv(file.path(AUDIT_DIR, "coder_agreement.csv"), show_col_types = FALSE)
sample_counts <- readr::read_csv(file.path(AUDIT_DIR, "sample_counts.csv"), show_col_types = FALSE)

dir.create(FIGURE_DIR, recursive = TRUE, showWarnings = FALSE)

format_interval <- function(estimate, low, high, digits = 2L) {
  paste0(
    format_number(estimate, digits),
    " [", format_number(low, digits), ", ", format_number(high, digits), "]"
  )
}

write_kable <- function(data, path, align = NULL) {
  table <- knitr::kable(
    data,
    format = "latex",
    booktabs = TRUE,
    escape = FALSE,
    align = align,
    linesep = ""
  )
  write_tex(as.character(table), path)
}

means_plot <- group_means |>
  dplyr::arrange(.data$order) |>
  dplyr::mutate(sample = factor(.data$sample, levels = rev(.data$sample))) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$estimate, y = .data$sample)) +
  ggplot2::geom_errorbar(
    ggplot2::aes(xmin = .data$conf_low, xmax = .data$conf_high),
    orientation = "y",
    width = 0,
    color = "gray40",
    linewidth = 0.5
  ) +
  ggplot2::geom_point(size = 2.2, color = COLORS[["participant"]]) +
  ggplot2::labs(x = "Mean number of coded reasons (95% confidence interval)", y = NULL) +
  theme_paper()

ggplot2::ggsave(
  file.path(FIGURE_DIR, "mean_reason_counts.pdf"),
  means_plot,
  width = FIGURE_WIDTH,
  height = 2.5,
  device = grDevices::cairo_pdf
)

balance_plot <- directional_estimates |>
  dplyr::filter(.data$outcome %in% c("balance", "absolute_imbalance")) |>
  dplyr::mutate(
    outcome = dplyr::recode(
      .data$outcome,
      balance = "Directional balance",
      absolute_imbalance = "Absolute imbalance"
    ),
    outcome = factor(
      .data$outcome,
      levels = c("Directional balance", "Absolute imbalance")
    ),
    comparison = dplyr::recode(
      .data$comparison,
      `T3 participant minus T3 control` = "T3 participants minus T3 controls",
      `Participant change, T3 minus T2` = "Participants: T3 minus T2"
    )
  ) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$estimate, y = .data$outcome)) +
  ggplot2::geom_vline(xintercept = 0, color = "gray75", linewidth = 0.45) +
  ggplot2::geom_errorbar(
    ggplot2::aes(xmin = .data$conf_low, xmax = .data$conf_high),
    orientation = "y",
    width = 0,
    color = "gray40",
    linewidth = 0.5
  ) +
  ggplot2::geom_point(size = 2.2, color = COLORS[["paired"]]) +
  ggplot2::facet_wrap(~comparison, ncol = 1) +
  ggplot2::labs(x = "Difference (95% confidence interval)", y = NULL) +
  theme_paper() +
  ggplot2::theme(panel.spacing.y = grid::unit(0.7, "lines"))

ggplot2::ggsave(
  file.path(FIGURE_DIR, "argument_balance.pdf"),
  balance_plot,
  width = FIGURE_WIDTH,
  height = 3.7,
  device = grDevices::cairo_pdf
)

mean_table <- group_means |>
  dplyr::arrange(.data$order) |>
  dplyr::transmute(
    Panel = "Means",
    `Sample or contrast` = tex_escape(.data$sample),
    Quantity = "Mean",
    `Estimate [95\\% CI]` = format_interval(
      .data$estimate,
      .data$conf_low,
      .data$conf_high
    ),
    `$N$` = .data$n
  )

contrast_table <- estimates |>
  dplyr::mutate(
    label = dplyr::case_when(
      stringr::str_starts(.data$specification, "Unadjusted") ~
        "T3 participant minus T3 control, unadjusted",
      stringr::str_starts(.data$specification, "Adjusted") ~
        "T3 participant minus T3 control, adjusted",
      stringr::str_starts(.data$specification, "Paired") ~
        "Participant change, T3 minus T2",
      TRUE ~ "T2 participant minus T3 control"
    )
  ) |>
  dplyr::transmute(
    Panel = "Comparisons",
    `Sample or contrast` = tex_escape(.data$label),
    Quantity = "Difference",
    `Estimate [95\\% CI]` = format_interval(
      .data$estimate,
      .data$conf_low,
      .data$conf_high
    ),
    `$N$` = .data$n
  )

ratio_table <- tibble::tibble(
  Panel = "Comparisons",
  `Sample or contrast` = "T3 participant divided by T3 control",
  Quantity = "Mean ratio",
  `Estimate [95\\% CI]` = format_interval(
    count_ratio$estimate,
    count_ratio$conf_low,
    count_ratio$conf_high
  ),
  `$N$` = count_ratio$n
)

write_kable(
  dplyr::bind_rows(mean_table, contrast_table, ratio_table),
  file.path(TABLE_DIR, "main_estimates.tex"),
  align = c("l", "l", "l", "r", "r")
)

directional_labels <- c(
  supporting_total = "Supporting reasons",
  opposing_total = "Opposing reasons",
  balance = "Directional balance ($b$)",
  absolute_imbalance = "Absolute imbalance ($|b|$)"
)

directional_table <- purrr::map_dfr(names(directional_labels), function(outcome) {
  control <- directional_means |>
    dplyr::filter(.data$outcome == .env$outcome, .data$sample == "T3 control")
  participant <- directional_means |>
    dplyr::filter(.data$outcome == .env$outcome, .data$sample == "T3 participant")
  t3_difference <- directional_estimates |>
    dplyr::filter(
      .data$outcome == .env$outcome,
      .data$comparison == "T3 participant minus T3 control"
    )
  paired_difference <- directional_estimates |>
    dplyr::filter(
      .data$outcome == .env$outcome,
      .data$comparison == "Participant change, T3 minus T2"
    )
  tibble::tibble(
    Outcome = directional_labels[[outcome]],
    `T3 control` = format_number(control$estimate),
    `T3 participant` = format_number(participant$estimate),
    `T3 difference [95\\% CI]` = format_interval(
      t3_difference$estimate,
      t3_difference$conf_low,
      t3_difference$conf_high
    ),
    `$N$ (T3)` = t3_difference$n,
    `Paired change [95\\% CI]` = format_interval(
      paired_difference$estimate,
      paired_difference$conf_low,
      paired_difference$conf_high
    ),
    `$N$ (paired)` = paired_difference$n
  )
})

write_kable(
  directional_table,
  file.path(TABLE_DIR, "directional_estimates.tex"),
  align = c("l", "r", "r", "r", "r", "r", "r")
)

composition_order <- c(
  "T1 nonparticipant", "T2 participant", "T3 nonreturning participant",
  "T3 returning participant", "T3 control"
)
composition_table <- sample_composition |>
  dplyr::mutate(sample = factor(.data$sample, levels = composition_order)) |>
  dplyr::arrange(.data$sample) |>
  dplyr::transmute(
    Sample = tex_escape(as.character(.data$sample)),
    `$N$` = .data$n,
    Age = paste0(format_number(.data$age, 1L), " (", .data$age_n, ")"),
    `Women (\\%)` = paste0(
      format_number(100 * .data$female, 1L),
      " (", .data$female_n, ")"
    ),
    `Catholic (\\%)` = paste0(
      format_number(100 * .data$catholic, 1L),
      " (", .data$catholic_n, ")"
    ),
    `Degree (\\%)` = paste0(
      format_number(100 * .data$degree, 1L),
      " (", .data$degree_n, ")"
    )
  )
write_kable(
  composition_table,
  file.path(TABLE_DIR, "sample_composition.tex"),
  align = c("l", "r", "r", "r", "r", "r")
)

item_means_wide <- item_wave_means |>
  dplyr::select("topic", "side", "sample", "estimate", "n") |>
  tidyr::pivot_wider(
    names_from = "sample",
    values_from = c("estimate", "n"),
    names_glue = "{.value}_{sample}"
  )
item_contrasts_wide <- item_contrasts |>
  dplyr::select(
    "topic", "side", "comparison", "estimate", "conf_low", "conf_high", "n"
  ) |>
  tidyr::pivot_wider(
    names_from = "comparison",
    values_from = c("estimate", "conf_low", "conf_high", "n"),
    names_glue = "{.value}_{comparison}"
  )
item_table <- dplyr::left_join(
  item_means_wide,
  item_contrasts_wide,
  by = c("topic", "side"),
  relationship = "one-to-one"
) |>
  dplyr::arrange(.data$topic, .data$side)

item_display <- purrr::pmap_dfr(item_table, function(...) {
  row <- list(...)
  topic <- as.character(row$topic)
  side_label <- if (row$side == unname(PRO_POLICY_SIDE[[topic]])) {
    "Pro-policy"
  } else {
    "Anti-policy"
  }
  tibble::tibble(
    Policy = tex_escape(unname(TOPIC_LABELS[[topic]])),
    Prompt = side_label,
    `T2 P` = paste0(
      format_number(row[["estimate_T2 participant"]]),
      " (", row[["n_T2 participant"]], ")"
    ),
    `T3 P` = paste0(
      format_number(row[["estimate_T3 participant"]]),
      " (", row[["n_T3 participant"]], ")"
    ),
    `T3 C` = paste0(
      format_number(row[["estimate_T3 control"]]),
      " (", row[["n_T3 control"]], ")"
    ),
    `T2 P $-$ T3 C` = paste0(
      format_interval(
        row[["estimate_T2 participant minus T3 control"]],
        row[["conf_low_T2 participant minus T3 control"]],
        row[["conf_high_T2 participant minus T3 control"]]
      ),
      " (", row[["n_T2 participant minus T3 control"]], ")"
    ),
    `T3 P $-$ T3 C` = paste0(
      format_interval(
        row[["estimate_T3 participant minus T3 control"]],
        row[["conf_low_T3 participant minus T3 control"]],
        row[["conf_high_T3 participant minus T3 control"]]
      ),
      " (", row[["n_T3 participant minus T3 control"]], ")"
    ),
    `T3 $-$ T2` = paste0(
      format_interval(
        row[["estimate_Participant change, T3 minus T2"]],
        row[["conf_low_Participant change, T3 minus T2"]],
        row[["conf_high_Participant change, T3 minus T2"]]
      ),
      " (", row[["n_Participant change, T3 minus T2"]], ")"
    )
  )
})
write_kable(
  item_display,
  file.path(TABLE_DIR, "item_results.tex"),
  align = c("l", "l", rep("r", 6L))
)

prompt_labels <- c(
  participant = "T3 participant",
  slot_order = "Response-slot order",
  `participant:slot_order` = "Participant $\\times$ response-slot order"
)
prompt_table <- prompt_order |>
  dplyr::transmute(
    Term = prompt_labels[.data$term],
    Estimate = format_number(.data$estimate, 3L),
    `CR2 SE` = format_number(.data$std_error, 3L),
    `CI low` = format_number(.data$conf_low, 3L),
    `CI high` = format_number(.data$conf_high, 3L),
    Rows = .data$n,
    Clusters = .data$clusters
  )
write_kable(
  prompt_table,
  file.path(TABLE_DIR, "prompt_order.tex"),
  align = c("l", rep("r", 6L))
)

robustness_labels <- c(
  inclusive_total = "Inclusive low-credit coding",
  mention_total = "Count every coded mention",
  coder_1_total = "Coder 1",
  coder_2_total = "Coder 2"
)
robustness_table <- robustness |>
  dplyr::transmute(
    `Outcome construction` = robustness_labels[.data$outcome],
    `T3 difference [95\\% CI]` = format_interval(
      .data$estimate,
      .data$conf_low,
      .data$conf_high
    ),
    `$N$` = .data$n,
    Clusters = .data$clusters
  )
write_kable(
  robustness_table,
  file.path(TABLE_DIR, "coding_sensitivity.tex"),
  align = c("l", "r", "r", "r")
)

directional_robustness_labels <- c(
  inclusive_balance = "Inclusive coding: $b$",
  inclusive_absolute_imbalance = "Inclusive coding: $|b|$",
  coder_1_balance = "Coder 1: $b$",
  coder_1_absolute_imbalance = "Coder 1: $|b|$",
  coder_2_balance = "Coder 2: $b$",
  coder_2_absolute_imbalance = "Coder 2: $|b|$"
)
directional_robustness_wide <- directional_robustness |>
  dplyr::mutate(value = format_interval(.data$estimate, .data$conf_low, .data$conf_high)) |>
  dplyr::select("outcome", "comparison", "value", "n") |>
  tidyr::pivot_wider(
    names_from = "comparison",
    values_from = c("value", "n"),
    names_glue = "{.value}_{comparison}"
  )
directional_robustness_table <- directional_robustness_wide |>
  dplyr::transmute(
    Construction = directional_robustness_labels[.data$outcome],
    `T3 difference [95\\% CI]` =
      .data[["value_T3 participant minus T3 control"]],
    `$N$ (T3)` = .data[["n_T3 participant minus T3 control"]],
    `Paired change [95\\% CI]` =
      .data[["value_Participant change, T3 minus T2"]],
    `$N$ (paired)` = .data[["n_Participant change, T3 minus T2"]]
  )
write_kable(
  directional_robustness_table,
  file.path(TABLE_DIR, "directional_robustness.tex"),
  align = c("l", "r", "r", "r", "r")
)

subgroup_means_wide <- subgroup_means |>
  dplyr::select("community", "sample", "estimate", "n") |>
  tidyr::pivot_wider(
    names_from = "sample",
    values_from = c("estimate", "n"),
    names_glue = "{.value}_{sample}"
  )
subgroup_table <- dplyr::left_join(
  subgroup_means_wide,
  subgroup_estimates,
  by = "community",
  relationship = "one-to-one"
)
subgroup_display <- subgroup_table |>
  dplyr::transmute(
    Community = .data$community,
    `Control mean` = format_number(.data[["estimate_T3 control"]]),
    `$N$ control` = .data[["n_T3 control"]],
    `Participant mean` = format_number(.data[["estimate_T3 participant"]]),
    `$N$ participant` = .data[["n_T3 participant"]],
    `Difference [95\\% CI]` = format_interval(
      .data$estimate,
      .data$conf_low,
      .data$conf_high
    ),
    `$N$ difference` = .data$n
  )
write_kable(
  subgroup_display,
  file.path(TABLE_DIR, "subgroup_results.tex"),
  align = c("l", rep("r", 6L))
)

unadjusted <- estimates |>
  dplyr::filter(stringr::str_starts(.data$specification, "Unadjusted"))
adjusted <- estimates |>
  dplyr::filter(stringr::str_starts(.data$specification, "Adjusted"))
paired_total <- estimates |>
  dplyr::filter(stringr::str_starts(.data$specification, "Paired"))
secondary <- estimates |>
  dplyr::filter(stringr::str_starts(.data$specification, "Noncontemporaneous"))
t3_balance <- directional_estimates |>
  dplyr::filter(
    .data$outcome == "balance",
    .data$comparison == "T3 participant minus T3 control"
  )
paired_balance <- directional_estimates |>
  dplyr::filter(
    .data$outcome == "balance",
    .data$comparison == "Participant change, T3 minus T2"
  )
t3_absolute <- directional_estimates |>
  dplyr::filter(
    .data$outcome == "absolute_imbalance",
    .data$comparison == "T3 participant minus T3 control"
  )
paired_absolute <- directional_estimates |>
  dplyr::filter(
    .data$outcome == "absolute_imbalance",
    .data$comparison == "Participant change, T3 minus T2"
  )

mean_lookup <- stats::setNames(group_means$estimate, group_means$sample)
n_lookup <- stats::setNames(group_means$n, group_means$sample)
full_n_lookup <- stats::setNames(sample_counts$n, sample_counts$sample)

write_tex_macros(
  c(
    ConfidenceLevel = "95",
    ControlMean = format_number(mean_lookup[["T3 control"]]),
    ParticipantTtwoMean = format_number(mean_lookup[["T2 participant"]]),
    ParticipantTthreeMean = format_number(mean_lookup[["T3 participant"]]),
    ControlN = as.character(n_lookup[["T3 control"]]),
    ParticipantTtwoN = as.character(n_lookup[["T2 participant"]]),
    ParticipantTthreeN = as.character(n_lookup[["T3 participant"]]),
    RecruitmentN = as.character(full_n_lookup[["initial_interview"]]),
    ParticipantTtwoFullN = as.character(full_n_lookup[["participant_t2"]]),
    ParticipantTthreeFullN = as.character(full_n_lookup[["participant_t3"]]),
    ControlFullN = as.character(full_n_lookup[["control_t3"]]),
    MainDifference = format_number(unadjusted$estimate),
    MainLow = format_number(unadjusted$conf_low),
    MainHigh = format_number(unadjusted$conf_high),
    MainP = format_p(unadjusted$p_value),
    MainRatio = format_number(count_ratio$estimate),
    MainRatioLow = format_number(count_ratio$conf_low),
    MainRatioHigh = format_number(count_ratio$conf_high),
    MainPercent = format_number(100 * (count_ratio$estimate - 1), 1L),
    AdjustedDifference = format_number(adjusted$estimate),
    AdjustedLow = format_number(adjusted$conf_low),
    AdjustedHigh = format_number(adjusted$conf_high),
    AdjustedN = as.character(adjusted$n),
    PairedDifference = format_number(paired_total$estimate),
    PairedLow = format_number(paired_total$conf_low),
    PairedHigh = format_number(paired_total$conf_high),
    SecondaryDifference = format_number(secondary$estimate),
    SecondaryLow = format_number(secondary$conf_low),
    SecondaryHigh = format_number(secondary$conf_high),
    BalanceDifference = format_number(t3_balance$estimate),
    BalanceLow = format_number(t3_balance$conf_low),
    BalanceHigh = format_number(t3_balance$conf_high),
    BalanceP = format_p(t3_balance$p_value),
    PairedBalanceDifference = format_number(paired_balance$estimate),
    PairedBalanceLow = format_number(paired_balance$conf_low),
    PairedBalanceHigh = format_number(paired_balance$conf_high),
    PairedBalanceP = format_p(paired_balance$p_value),
    AbsoluteDifference = format_number(t3_absolute$estimate),
    AbsoluteLow = format_number(t3_absolute$conf_low),
    AbsoluteHigh = format_number(t3_absolute$conf_high),
    PairedAbsoluteDifference = format_number(paired_absolute$estimate),
    PairedAbsoluteLow = format_number(paired_absolute$conf_low),
    PairedAbsoluteHigh = format_number(paired_absolute$conf_high),
    CoderAgreement = format_number(100 * coder_audit$agreement_rate, 1L),
    CoderAlpha = format_number(coder_audit$krippendorff_alpha, 2L),
    UnresolvedSlots = as.character(coder_audit$unresolved_disagreements)
  ),
  file.path(TABLE_DIR, "numbers.tex")
)
