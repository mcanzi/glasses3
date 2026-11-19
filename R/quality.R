#' Data quality per recording or epoch
#'
#' Counts the samples of each recording or epoch and how many of them hold
#' data, for example to find trials with too much missing data before
#' analysis.
#'
#' Rows are grouped by the `recording` and `epoch` columns where these exist,
#' so the function works on the output of [read_g3_gaze()], [g3_epochs()]
#' and [g3_fill_gaps()]. Columns named in `by` are added to these groups, and
#' so are the groups of a grouped tibble. Rows inserted by [g3_fill_gaps()]
#' count as samples without data.
#'
#' @param x Gaze data from [read_g3_gaze()] or [g3_epochs()]. Long pupil
#'   data from [g3_pupil_long()] are not accepted, because each sample is
#'   there twice.
#' @param by Names of further columns to group by, such as a condition
#'   column. They are kept in the result.
#'
#' @return A tibble with one row per group, starting with the grouping
#'   columns, and these columns:
#' \describe{
#'   \item{samples}{Number of samples.}
#'   \item{duration}{Seconds from the first to the last sample.}
#'   \item{valid}{Proportion of samples with a gaze point.}
#'   \item{valid_left, valid_right}{Proportion of samples with data for
#'     each eye, if `x` has these columns.}
#'   \item{max_gap}{Longest time in seconds between two samples with a gaze
#'     point. The first and last samples of the group count as boundaries,
#'     so missing data at the start or end are included. In complete data
#'     it is the sample interval, 0.02 s at 50 Hz. Damaged lines skipped by
#'     the readers also lengthen it.}
#' }
#' Samples without a time count towards `samples` and the proportions, but
#' not towards `duration` and `max_gap`. A grouped tibble keeps its groups.
#'
#' @examples
#' rec <- read_g3(g3_example())
#' g3_quality(rec$gaze)
#'
#' ep <- g3_epochs(rec$gaze, rec$events, before = 0.5, after = 3, direction = "out")
#' quality <- g3_quality(ep)
#' quality
#' dplyr::filter(quality, valid >= 0.8, max_gap < 0.5)
#' @export
g3_quality <- function(x, by = NULL) {
  check_df(x, c("time", "valid"), "x", numeric = "time")
  if ("eye" %in% names(x)) {
    stop("`g3_quality()` works on gaze data with one row per sample. Use it ",
         "before `g3_pupil_long()`.", call. = FALSE)
  }
  flags <- c("valid", "valid_left", "valid_right") |> intersect(names(x))
  wrong <- flags |> purrr::discard(\(col) is.logical(x[[col]]))
  if (length(wrong) > 0L) {
    stop("These columns of `x` must be logical: ", paste(wrong, collapse = ", "),
         call. = FALSE)
  }
  groups <- analysis_groups(x, by, c("recording", "epoch"), "time")
  if (any(flags %in% groups)) {
    stop("`by` and the groups of `x` cannot include ",
         paste(intersect(flags, groups), collapse = ", "), ", which are summarised.",
         call. = FALSE)
  }
  x |>
    drop_groups() |>
    dplyr::summarise(
      samples = dplyr::n(),
      duration = time_span(time),
      max_gap = longest_gap(time, valid),
      dplyr::across(dplyr::all_of(flags), share_true),
      .by = dplyr::all_of(groups)
    ) |>
    dplyr::relocate(max_gap, .after = dplyr::last_col()) |>
    restore_groups(x)
}

share_true <- function(v) {
  if (length(v) == 0L) NA_real_ else mean(v %in% TRUE)
}

time_span <- function(time) {
  time <- time[!is.na(time)]
  if (length(time) == 0L) NA_real_ else max(time) - min(time)
}

longest_gap <- function(time, valid) {
  known <- !is.na(time)
  if (!any(known)) {
    return(NA_real_)
  }
  bounds <- range(time[known])
  c(bounds, time[known & valid %in% TRUE]) |> sort() |> diff() |> max()
}
