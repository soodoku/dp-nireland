# Reshape, normalize, and adjudicate the open-ended coding.

coding_wide <- readr::read_csv(
  SOURCE_CODING,
  na = c("", "NA"),
  show_col_types = FALSE,
  name_repair = "minimal"
)
names(coding_wide)[names(coding_wide) == "Participant ID"] <- "respondent_id"

coder_columns <- grep(
  "^t[23]\\.q(18|19|20|21)\\.[ab][1-5]\\.(ch|la|monty)$",
  names(coding_wide),
  value = TRUE
)
if (length(coder_columns) != 240L) stop("Expected 240 coder columns.", call. = FALSE)

coding_long <- coding_wide |>
  dplyr::select("respondent_id", dplyr::all_of(coder_columns)) |>
  tidyr::pivot_longer(
    -"respondent_id",
    names_to = c("wave", "topic", "side", "slot", "coder"),
    names_pattern = "^t([23])\\.q(18|19|20|21)\\.([ab])([1-5])\\.(ch|la|monty)$",
    values_to = "raw_code",
    values_transform = as.character
  ) |>
  dplyr::mutate(
    respondent_id = as.integer(.data$respondent_id),
    wave = as.integer(.data$wave),
    slot = as.integer(.data$slot),
    signature = vapply(.data$raw_code, code_signature, character(1L))
  ) |>
  dplyr::select(-"raw_code") |>
  tidyr::pivot_wider(names_from = "coder", values_from = "signature") |>
  dplyr::mutate(
    both_coded = !is.na(.data$ch) & !is.na(.data$la),
    coder_agreement = .data$both_coded & .data$ch == .data$la,
    adjudication_required = .data$both_coded & .data$ch != .data$la,
    unresolved = .data$adjudication_required & is.na(.data$monty),
    final_signature = purrr::pmap_chr(
      list(.data$ch, .data$la, .data$monty),
      ~ adjudicate_signature(..1, ..2, ..3)
    )
  )

agreement_audit <- coding_long |>
  dplyr::summarise(
    slots = dplyr::n(),
    n_both_coded = sum(.data$both_coded),
    normalized_agreements = sum(.data$coder_agreement),
    normalized_disagreements = sum(.data$adjudication_required),
    unresolved_disagreements = sum(.data$unresolved),
    agreement_rate = mean(.data$coder_agreement[.data$both_coded])
  )

pooled_labels <- c(
  coding_long$ch[coding_long$both_coded],
  coding_long$la[coding_long$both_coded]
)
label_counts <- table(pooled_labels)
n_labels <- sum(label_counts)
expected_disagreement <- sum(label_counts * (n_labels - label_counts)) /
  (n_labels * (n_labels - 1L))
observed_disagreement <- mean(!coding_long$coder_agreement[coding_long$both_coded])
agreement_audit$krippendorff_alpha <- 1 - observed_disagreement / expected_disagreement

coding_sets <- coding_long |>
  dplyr::mutate(
    codes = purrr::map(.data$final_signature, signature_codes),
    coder_1_codes = purrr::map(.data$ch, signature_codes),
    coder_2_codes = purrr::map(.data$la, signature_codes)
  )

write_csv(coding_long, file.path(DERIVED_DIR, "coding_slots.csv"))
write_csv(agreement_audit, file.path(AUDIT_DIR, "coder_agreement.csv"))
saveRDS(coding_sets, file.path(DERIVED_DIR, "coding_sets.rds"))
