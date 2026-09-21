SOURCE_SURVEY <- here::here("data", "orig_data", "nireland.csv")
SOURCE_GROUPS <- here::here("data", "groups.csv")
SOURCE_CODING <- here::here("data", "open_ended", "fin.csv")

DERIVED_DIR <- here::here("data", "derived")
FIGURE_DIR <- here::here("figs")
TABLE_DIR <- here::here("tabs")
AUDIT_DIR <- here::here("audit")

TOPIC_LABELS <- c(
  "18" = "All-ability schools",
  "19" = "Balanced enrolment",
  "20" = "Inclusive classrooms",
  "21" = "Combined primary and post-primary schools"
)

PRO_POLICY_SIDE <- c("18" = "a", "19" = "b", "20" = "a", "21" = "a")
ATTITUDE_VARIABLES <- c(
  "18" = "q1cr",
  "19" = "q2ar",
  "20" = "q4cr",
  "21" = "q5gr"
)

INVALID_CODES <- 91:93
OTHER_VALID_CODES <- c(90L, 94L)
LOW_CREDIT_QUESTIONS <- c("18b", "19a", "20b")

COLORS <- c(
  participant = "#1B4965",
  control = "#707070",
  paired = "#B23A48"
)

theme_paper <- function(base_size = 10, base_family = "") {
  ggplot2::theme_classic(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      axis.text = ggplot2::element_text(color = "gray20"),
      axis.title = ggplot2::element_text(color = "gray10"),
      legend.position = "none",
      plot.title.position = "plot",
      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0)
    )
}

FIGURE_WIDTH <- 6.5
FIGURE_HEIGHT <- 3.8
