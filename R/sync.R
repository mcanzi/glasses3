#' Extract sync port pulses
#'
#' Turns the sync port signal changes in the event data into one row per
#' pulse, where a pulse runs from the signal going high (1) to it going low
#' (0) again. With several recordings, pulses are numbered within each
#' recording. Signal changes without a time or value are ignored.
#'
#' @param events Event data from [read_g3_events()].
#' @param direction `"in"` for the signal received from external equipment,
#'   such as stimulus onsets sent by a stimulus computer, or `"out"` for the
#'   signal sent by the glasses.
#'
#' @return A tibble with columns `recording` (if `events` has one), `pulse`
#'   (running number), `onset`, `offset` and `duration` (seconds). `offset`
#'   is `NA` if the recording ended while the signal was high. Groups of a
#'   grouped tibble are kept if their columns are still in the result.
#'
#' @examples
#' events <- read_g3_events(g3_example())
#' g3_syncport(events, direction = "out")
#' @export
g3_syncport <- function(events, direction = c("in", "out")) {
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
    dplyr::filter(type == "syncport", direction %in% wanted, !is.na(time), !is.na(value)) |>
    dplyr::arrange(time) |>
    dplyr::mutate(previous = dplyr::lag(value, default = 0))
  onset <- s$time[s$value == 1 & s$previous != 1]
  offsets <- s$time[s$value == 0 & s$previous == 1]
  offset <- offsets[findInterval(onset, offsets) + 1L]
  tibble::tibble(pulse = seq_along(onset), onset, offset, duration = offset - onset)
}

#' Extract API events
#'
#' Returns the events sent to the glasses through their API during the
#' recording, for example with the `send-event` call from an experiment
#' script. Each event has a tag and an object, which can hold any JSON value.
#'
#' @param events Event data from [read_g3_events()].
#'
#' @return A tibble with columns `recording` (if `events` has one), `onset`
#'   (seconds since the start of the recording), `tag` and `object` (the
#'   object as a JSON string, or `NA` if the event has none). Pass it to
#'   [g3_epochs()] to cut epochs at the events. Groups of a grouped tibble
#'   are kept if their columns are still in the result.
#'
#' @examples
#' events <- read_g3_events(g3_example())
#' g3_api_events(events)
#' @export
g3_api_events <- function(events) {
  check_df(events, c("time", "type", "data"), "events")
  e <- events |> drop_groups() |> dplyr::filter(type == "event")
  d <- e$data |> purrr::map(\(s) if (is.na(s)) list() else jsonlite::parse_json(s))
  e |>
    dplyr::select(dplyr::any_of("recording"), onset = time) |>
    dplyr::mutate(
      tag = pluck_chr(d, "tag"),
      object = d |> purrr::map_chr(json_object)
    ) |>
    restore_groups(events)
}

json_object <- function(data) {
  object <- data[["object"]]
  if (is.null(object)) {
    return(NA_character_)
  }
  object |> jsonlite::toJSON(auto_unbox = TRUE, digits = NA) |> as.character()
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
#' gaze <- g3_add_syncport(rec$gaze, rec$events, direction = "out")
#' gaze |>
#'   dplyr::filter(syncport == 1) |>
#'   dplyr::select(time, pulse, pulse_time)
#' @export
g3_add_syncport <- function(x, events, direction = c("in", "out")) {
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

#' Cut samples into epochs
#'
#' Returns the samples from `before` seconds before to `after` seconds after
#' each onset, for example to analyse pupil responses to stimuli. The onsets
#' are the sync port pulses in the event data, or any table of onsets, such
#' as the API events from [g3_api_events()] or the trial onsets of an
#' experiment. With several recordings, each recording is cut at its own
#' onsets.
#'
#' @inheritParams g3_add_syncport
#' @param events Event data from [read_g3_events()], to cut at the sync port
#'   pulses, or a data frame with an `onset` column in seconds since the
#'   start of the recording. With a `recording` column, each recording is
#'   cut at its own onsets; without one, every recording is cut at all
#'   onsets. The other columns of the data frame, such as a condition or the
#'   `tag` of an API event, are copied to the samples of each epoch, except
#'   `time`, `epoch` and `epoch_time`.
#' @param before,after Seconds to keep before and after each onset.
#' @param direction Sync port direction, used with event data; see
#'   [g3_syncport()].
#' @param pulses Which sync port pulses to use, as pulse numbers. Defaults
#'   to all. To use some rows of a table of onsets, filter the table instead.
#'
#' @return The selected rows of `x`, sorted by time within each epoch, with
#'   added columns `epoch` (running number of the onset within the
#'   recording) and `epoch_time` (seconds relative to the onset). Epochs cut
#'   at sync port pulses also get `pulse`, the pulse number. Columns copied
#'   from a table of onsets replace columns of `x` with the same name.
#'   Samples can appear in more than one epoch if epochs overlap. If `x` is
#'   a grouped tibble, the result has the same groups.
#'
#' @examples
#' rec <- read_g3(g3_example())
#' ep <- g3_epochs(rec$gaze, rec$events, before = 1, after = 5, direction = "out")
#' dplyr::count(ep, epoch)
#'
#' trials <- data.frame(onset = c(2, 12, 22), condition = c("a", "b", "a"))
#' ep <- g3_epochs(rec$gaze, trials, before = 0.5, after = 3)
#' dplyr::count(ep, epoch, condition)
#' @export
g3_epochs <- function(x, events, before = 0, after = 1,
                      direction = c("in", "out"), pulses = NULL) {
  check_df(x, "time", "x")
  check_seconds(before, "before")
  check_seconds(after, "after")
  direction <- match.arg(direction)
  onsets <- epoch_onsets(events, direction, pulses)
  check_recordings(x, events)
  extra <- setdiff(names(onsets), c("recording", "onset", "time", "epoch", "epoch_time"))
  out <- by_recording(x, function(xi, id) {
    p <- pulses_for(onsets, id) |> dplyr::arrange(onset)
    xi <- xi |>
      dplyr::filter(!is.na(time)) |>
      dplyr::arrange(time) |>
      dplyr::select(!dplyr::any_of(c(extra, "epoch", "epoch_time")))
    lo <- findInterval(p$onset - before, xi$time, left.open = TRUE) + 1L
    hi <- findInterval(p$onset + after, xi$time)
    n <- pmax(hi - lo + 1L, 0L)
    idx <- rep(seq_len(nrow(p)), n)
    xi |>
      dplyr::slice(sequence(n, from = lo)) |>
      dplyr::mutate(epoch = idx, epoch_time = time - p$onset[idx]) |>
      dplyr::bind_cols(p |> dplyr::slice(idx) |> dplyr::select(dplyr::all_of(extra)))
  })
  out |> restore_groups(x)
}

epoch_onsets <- function(events, direction, pulses) {
  if (is.data.frame(events) && "onset" %in% names(events)) {
    if (!is.null(pulses)) {
      stop("`pulses` selects sync port pulses. Filter the table of onsets instead.",
           call. = FALSE)
    }
    if (!is.numeric(events$onset)) {
      stop("The `onset` column of `events` must be numeric.", call. = FALSE)
    }
    return(events |> drop_groups() |> dplyr::filter(!is.na(onset)))
  }
  p <- syncport_pulses(events, direction)
  if (!is.null(pulses)) {
    keep <- pulses
    p <- p |> dplyr::filter(pulse %in% keep)
  }
  p |> dplyr::select(dplyr::any_of(c("recording", "pulse", "onset")))
}

#' Reshape pupil data to long format
#'
#' Reshapes the pupil columns of gaze data to one row per sample and eye,
#' which suits plotting and mixed-effects models.
#'
#' @param gaze Gaze data from [read_g3_gaze()], possibly with added columns.
#'
#' @return A tibble with the non-eye columns of `gaze` (such as `recording`,
#'   `time`, `epoch` or `epoch_time`, if present), plus `eye` (`"left"` or
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
  if (!"recording" %in% names(x) || nrow(x) == 0L) {
    return(fun(x, NULL) |> tibble::as_tibble())
  }
  grouped <- x |> dplyr::group_by(recording)
  ids <- dplyr::group_keys(grouped)$recording
  parts <- dplyr::group_split(grouped)
  seen <- match(unique(x$recording), ids)
  purrr::map2(parts[seen], ids[seen], fun) |>
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
