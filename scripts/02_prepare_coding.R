# Reshape, normalize, and adjudicate the open-ended coding.

coding_source <- arrow::read_parquet(SOURCE_CODING)
assert_columns(
  coding_source,
  c("respondent_id", "wave", "topic", "side", "slot", "coder", "raw_code"),
  "Argument coding"
)
assert_unique(
  coding_source, c("respondent_id", "wave", "topic", "side", "slot", "coder"),
  "Argument coding"
)

coding_long <- coding_source |>
  dplyr::mutate(
    topic = as.character(.data$topic),
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

coder_agreement <- coding_long |>
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
coder_agreement$krippendorff_alpha <- 1 - observed_disagreement / expected_disagreement

coding_sets <- coding_long |>
  dplyr::mutate(
    codes = purrr::map(.data$final_signature, signature_codes),
    coder_1_codes = purrr::map(.data$ch, signature_codes),
    coder_2_codes = purrr::map(.data$la, signature_codes)
  )

write_csv(coding_long, file.path(DERIVED_DIR, "coding_slots.csv"))
write_csv(coder_agreement, file.path(DERIVED_DIR, "coder_agreement.csv"))
saveRDS(coding_sets, file.path(DERIVED_DIR, "coding_sets.rds"))
