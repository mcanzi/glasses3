#' Extract sync port pulses
#'
#' Turns the sync port signal changes in the event data into one row per
#' pulse, where a pulse runs from the signal going high (1) to it going low
#' (0) again. With several recordings, pulses are numbered within each
#' recording.
#'
#' @param events Event data from [read_g3_events()].
#' @param direction `"out"` for the signal sent by the glasses, `"in"` for
#'   the signal received from external equipment.
#'
#' @return A tibble with columns `recording` (if `events` has one), `pulse`
#'   (running number), `onset`, `offset` and `duration` (seconds). `offset`
#'   is `NA` if the recording ended while the signal was high. Groups of a
#'   grouped tibble are kept if their columns are still in the result.
#'
#' @examples
#' events <- read_g3_events(g3_example())
#' g3_syncport(events)
#' @export
g3_syncport <- function(events, direction = c("out", "in")) {
  direction <- match.arg(direction)
  events |> syncport_pulses(direction) |> restore_groups(events)
}

syncport_pulses <- function(events, direction) {
  check_df(events, c("time", "type", "direction", "value"), "events")
  by_recording(events, function(e, id) {
    p <- pulses_one(e, direction)
    if (is.null(id)) p else p |> add_recording(id)
  })
}

pulses_one <- function(events, direction) {
  wanted <- direction
  s <- events |>
    dplyr::filter(type == "syncport", direction %in% wanted) |>
    dplyr::arrange(time) |>
    dplyr::mutate(previous = dplyr::lag(value, default = 0))
  onset <- s$time[s$value == 1 & s$previous != 1]
  offsets <- s$time[s$value == 0 & s$previous == 1]
  offsets <- offsets[!is.na(offsets)]
  offset <- offsets[findInterval(onset, offsets) + 1L]
  tibble::tibble(pulse = seq_along(onset), onset, offset, duration = offset - onset)
}

#' Add sync port information to samples
#'
#' Adds the sync port state and the most recent pulse to each sample of gaze
#' or IMU data. With several recordings, samples are matched to the pulses
#' of their own recording through the `recording` column.
#'
#' @param x A data frame with a `time` column, such as the output of
#'   [read_g3_gaze()] or [read_g3_imu()].
#' @inheritParams g3_syncport
#'
#' @return `x` with three added columns: `syncport` (1 while the signal is
#'   high, 0 otherwise), `pulse` (number of the most recent pulse onset, `NA`
#'   before the first one) and `pulse_time` (seconds since that onset). If
#'   `x` is a grouped tibble, the result has the same groups.
#'
#' @examples
#' rec <- read_g3(g3_example())
#' gaze <- g3_add_syncport(rec$gaze, rec$events)
#' gaze |>
#'   dplyr::filter(syncport == 1) |>
#'   dplyr::select(time, pulse, pulse_time)
#' @export
g3_add_syncport <- function(x, events, direction = c("out", "in")) {
  check_df(x, "time", "x")
  direction <- match.arg(direction)
  pulses <- syncport_pulses(events, direction)
  check_recordings(x, events)
  out <- by_recording(x, function(xi, id) {
    p <- pulses_for(pulses, id)
    idx <- findInterval(xi$time, p$onset)
    idx[idx == 0L] <- NA_integer_
    xi |>
      dplyr::mutate(
        syncport = as.integer(!is.na(idx) & (is.na(p$offset[idx]) | time < p$offset[idx])),
        pulse = p$pulse[idx],
        pulse_time = time - p$onset[idx]
      )
  })
  out |> restore_groups(x)
}

#' Cut samples into epochs around sync port pulses
#'
#' Returns the samples from `before` seconds before to `after` seconds after
#' the onset of each sync port pulse, for example to analyse pupil responses
#' to stimuli whose onset was marked with a sync pulse. With several
#' recordings, each recording is cut at its own pulses.
#'
#' @inheritParams g3_add_syncport
#' @param before,after Seconds to keep before and after each onset.
#' @param pulses Which pulses to use, as pulse numbers. Defaults to all.
#'
#' @return The selected rows of `x`, sorted by time within each epoch, with
#'   added columns `pulse` and `epoch_time` (seconds relative to the pulse
#'   onset). Samples can appear in more than one epoch if epochs overlap. If
#'   `x` is a grouped tibble, the result has the same groups.
#'
#' @examples
#' rec <- read_g3(g3_example())
#' ep <- g3_epochs(rec$gaze, rec$events, before = 1, after = 5)
#' dplyr::count(ep, pulse)
#' @export
g3_epochs <- function(x, events, before = 0, after = 1,
                      direction = c("out", "in"), pulses = NULL) {
  check_df(x, "time", "x")
  check_seconds(before, "before")
  check_seconds(after, "after")
  direction <- match.arg(direction)
  all_pulses <- syncport_pulses(events, direction)
  check_recordings(x, events)
  out <- by_recording(x, function(xi, id) {
    p <- pulses_for(all_pulses, id)
    if (!is.null(pulses)) {
      keep <- pulses
      p <- p |> dplyr::filter(pulse %in% keep)
    }
    xi <- xi |> dplyr::filter(!is.na(time)) |> dplyr::arrange(time)
    lo <- findInterval(p$onset - before, xi$time, left.open = TRUE) + 1L
    hi <- findInterval(p$onset + after, xi$time)
    n <- pmax(hi - lo + 1L, 0L)
    xi |>
      dplyr::slice(sequence(n, from = lo)) |>
      dplyr::mutate(pulse = rep(p$pulse, n), epoch_time = time - rep(p$onset, n))
  })
  out |> restore_groups(x)
}

#' Pupil data in long format
#'
#' Reshapes the pupil columns of gaze data to one row per sample and eye,
#' which suits plotting and mixed-effects models.
#'
#' @param gaze Gaze data from [read_g3_gaze()], possibly with added columns.
#'
#' @return A tibble with the non-eye columns of `gaze` (such as `recording`,
#'   `time`, `pulse` or `epoch_time`, if present), plus `eye` (`"left"` or
#'   `"right"`) and `pupil`. Groups of a grouped tibble are kept if their
#'   columns are still in the result.
#'
#' @examples
#' gaze <- read_g3_gaze(g3_example())
#' g3_pupil_long(gaze)
#' @export
g3_pupil_long <- function(gaze) {
  check_df(gaze, c("time", "left_pupil", "right_pupil"), "gaze")
  gaze |>
    drop_groups() |>
    dplyr::select(
      !(dplyr::matches("^(left|right)_") | dplyr::any_of(c("valid_left", "valid_right"))),
      left_pupil,
      right_pupil
    ) |>
    tidyr::pivot_longer(c(left_pupil, right_pupil), names_to = "eye", values_to = "pupil",
                        names_pattern = "(.*)_pupil") |>
    restore_groups(gaze)
}

by_recording <- function(x, fun) {
  x <- drop_groups(x)
  ids <- if ("recording" %in% names(x)) unique(x$recording)
  if (length(ids) == 0L) {
    return(fun(x, NULL) |> tibble::as_tibble())
  }
  ids |>
    purrr::map(\(id) x |> dplyr::filter(recording %in% id) |> fun(id)) |>
    purrr::list_rbind() |>
    tibble::as_tibble()
}

check_recordings <- function(x, events) {
  ev_ids <- if ("recording" %in% names(events)) unique(events$recording) else NULL
  if (!"recording" %in% names(x)) {
    if (length(ev_ids) > 1L) {
      stop("`events` holds several recordings, but `x` has no `recording` ",
           "column to match them to.", call. = FALSE)
    }
    return(invisible())
  }
  if (!is.null(ev_ids)) {
    missing <- x$recording |> unique() |> setdiff(ev_ids)
    if (length(missing) > 0L) {
      warning("No events for recording", if (length(missing) > 1L) "s", ": ",
              paste(missing, collapse = ", "), call. = FALSE)
    }
  }
  invisible()
}

pulses_for <- function(pulses, id) {
  if (is.null(id) || !"recording" %in% names(pulses)) {
    return(pulses)
  }
  pulses |> dplyr::filter(recording %in% id)
}
