assert_columns <- function(data, columns, label) {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0L) {
    stop(label, " is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(data)
}

assert_unique <- function(data, columns, label) {
  duplicates <- data |>
    dplyr::count(dplyr::across(dplyr::all_of(columns)), name = "n") |>
    dplyr::filter(.data$n > 1L)
  if (nrow(duplicates) > 0L) {
    stop(label, " is not unique on ", paste(columns, collapse = " + "), call. = FALSE)
  }
  invisible(data)
}

verify_manifest <- function(path = here::here("data", "manifest.yaml"),
                            dp_data_root = DP_DATA_ROOT) {
  sources <- yaml::read_yaml(path)$sources
  for (name in names(sources)) {
    source <- sources[[name]]
    root <- if (identical(source$repository, "dp-data")) dp_data_root else here::here()
    source_path <- file.path(root, source$path)
    if (!file.exists(source_path)) {
      stop("Missing source file: ", source_path,
        ". See docs/data.md for dp-data setup.",
        call. = FALSE
      )
    }
    actual <- digest::digest(source_path, algo = "sha256", file = TRUE)
    if (!identical(actual, source$sha256)) {
      stop("Source hash mismatch: ", source_path,
        ". Investigate the source change before updating its pin.",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(data, path, na = "")
  message("Created: ", path)
  invisible(path)
}

write_tex <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path, useBytes = TRUE)
  message("Created: ", path)
  invisible(path)
}

write_tex_macros <- function(values, path) {
  if (is.null(names(values)) || any(!grepl("^[A-Za-z]+$", names(values)))) {
    stop("TeX macro names must contain letters only.", call. = FALSE)
  }
  write_tex(paste0("\\newcommand{\\", names(values), "}{", values, "}"), path)
}

tex_escape <- function(x) {
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([#$%&_{}])", "\\\\\\1", x)
  x <- gsub("~", "\\\\textasciitilde{}", x, fixed = TRUE)
  gsub("\\^", "\\\\textasciicircum{}", x)
}

parse_code_set <- function(x) {
  if (length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    return(integer())
  }
  tokens <- stringr::str_extract_all(tolower(x), "[0-9]+")[[1L]]
  sort(unique(as.integer(tokens)))
}

code_signature <- function(x) {
  codes <- parse_code_set(x)
  if (length(codes) == 0L) NA_character_ else paste(codes, collapse = ",")
}

signature_codes <- function(x) {
  if (length(x) != 1L || is.na(x) || !nzchar(x)) {
    return(integer())
  }
  as.integer(strsplit(x, ",", fixed = TRUE)[[1L]])
}

adjudicate_signature <- function(coder_1, coder_2, adjudicator) {
  both <- !is.na(coder_1) && !is.na(coder_2)
  if (both && identical(coder_1, coder_2)) {
    return(coder_1)
  }
  if (both && !is.na(adjudicator)) {
    return(adjudicator)
  }
  if (both) {
    return(NA_character_)
  }
  if (!is.na(coder_1)) {
    return(coder_1)
  }
  if (!is.na(coder_2)) {
    return(coder_2)
  }
  adjudicator
}

discussion_cluster <- function(participant, group_id, respondent_id) {
  ifelse(
    participant & !is.na(group_id),
    paste0("group_", group_id),
    paste0("respondent_", respondent_id)
  )
}

argument_balance <- function(supporting, opposing) {
  total <- supporting + opposing
  dplyr::if_else(
    !is.na(total) & total > 0,
    (supporting - opposing) / total,
    NA_real_
  )
}

cr2_term <- function(fit, term, cluster, conf_level = 0.95) {
  test <- clubSandwich::coef_test(
    fit,
    vcov = "CR2",
    cluster = cluster,
    coefs = term,
    test = "Satterthwaite"
  )
  estimate <- test[["beta"]]
  std_error <- test[["SE"]]
  degrees_freedom <- test[["df_Satt"]]
  critical <- stats::qt((1 + conf_level) / 2, degrees_freedom)
  tibble::tibble(
    estimate = estimate,
    std_error = std_error,
    conf_low = estimate - critical * std_error,
    conf_high = estimate + critical * std_error,
    degrees_freedom = degrees_freedom,
    p_value = test[["p_Satt"]],
    n = stats::nobs(fit),
    clusters = length(unique(cluster))
  )
}

cr2_mean <- function(outcome, cluster) {
  keep <- !is.na(outcome) & !is.na(cluster)
  fit <- stats::lm(outcome[keep] ~ 1)
  cr2_term(fit, "(Intercept)", cluster[keep])
}

format_number <- function(x, digits = 2L) {
  formatC(x, format = "f", digits = digits)
}

format_p <- function(x) {
  ifelse(x < 0.001, "$< .001$", paste0("$= ", sub("^0", "", format_number(x, 3L)), "$"))
}

compare_estimate_reference <- function(path, reference, tolerance = 1e-10) {
  actual <- readr::read_csv(path, show_col_types = FALSE)
  expected <- readr::read_csv(reference, show_col_types = FALSE)
  result <- list(equivalent = FALSE, max_absolute_difference = NA_real_)
  if (!identical(names(actual), names(expected)) || nrow(actual) != nrow(expected)) {
    return(result)
  }
  statistics <- c(
    "estimate", "std_error", "conf_low", "conf_high", "degrees_freedom", "p_value"
  )
  differences <- numeric()
  for (column in names(expected)) {
    x <- actual[[column]]
    y <- expected[[column]]
    if (!column %in% statistics) {
      if (!identical(x, y)) {
        return(result)
      }
    } else {
      compatible <- is.numeric(x) && is.numeric(y) &&
        identical(is.na(x), is.na(y)) &&
        identical(is.finite(x), is.finite(y))
      if (!compatible) {
        return(result)
      }
      finite <- is.finite(y)
      if (!identical(x[!finite], y[!finite])) {
        return(result)
      }
      differences <- c(differences, abs(x[finite] - y[finite]))
    }
  }
  result$max_absolute_difference <- max(c(0, differences))
  result$equivalent <- result$max_absolute_difference <= tolerance
  result
}

verify_numerical_baseline <- function(
  baseline = here::here("audit", "numerical_baseline.csv"),
  root = here::here(),
  report = file.path(AUDIT_DIR, "numerical_comparison.csv")
) {
  expected <- readr::read_csv(baseline, show_col_types = FALSE)
  expected$actual_sha256 <- vapply(expected$path, function(path) {
    target <- file.path(root, path)
    if (!file.exists(target)) {
      return(NA_character_)
    }
    digest::digest(target, algo = "sha256", file = TRUE)
  }, character(1L))
  expected$unchanged <- !is.na(expected$actual_sha256) &
    expected$sha256 == expected$actual_sha256
  expected$equivalent <- expected$unchanged
  expected$max_absolute_difference <- ifelse(expected$unchanged, 0, NA_real_)
  if ("reference_path" %in% names(expected)) {
    for (i in which(!expected$unchanged & !is.na(expected$reference_path))) {
      reference <- file.path(root, expected$reference_path[i])
      target <- file.path(root, expected$path[i])
      if (!file.exists(reference) || !file.exists(target)) next
      reference_hash <- digest::digest(reference, algo = "sha256", file = TRUE)
      if (!identical(reference_hash, expected$sha256[i])) {
        stop("Numerical reference hash mismatch: ", reference, call. = FALSE)
      }
      comparison <- compare_estimate_reference(target, reference)
      expected$equivalent[i] <- comparison$equivalent
      expected$max_absolute_difference[i] <- comparison$max_absolute_difference
    }
  }
  write_csv(expected, report)
  if (!all(expected$equivalent)) {
    stop(
      "Numerical baseline changed: ",
      paste(expected$path[!expected$equivalent], collapse = ", "),
      ". Explain differences before updating audit/numerical_baseline.csv.",
      call. = FALSE
    )
  }
  invisible(expected)
}
