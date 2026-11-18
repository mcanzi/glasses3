#' Insert rows for missing samples
#'
#' The glasses write a line even for samples where they detect no gaze, so
#' the gaze data are usually complete. Samples can still be missing, for
#' example after damaged lines were skipped. `g3_fill_gaps()` inserts a row
#' for each missing sample, so that the data are evenly spaced again, as many
#' preprocessing methods assume. The new rows hold `NA`, and their validity
#' columns are `FALSE`. Values are not interpolated.
#'
#' With several recordings in `x`, each is filled separately. The `recording`
#' column and columns you added yourself, such as a participant column, are
#' copied into the new rows when they have a single value within the
#' recording.
#'
#' @param x Gaze data from [read_g3_gaze()].
#' @param rate Sampling rate in Hz. By default it is worked out from the
#'   median interval between samples and set to 50 or 100 Hz when it is
#'   within 10% of either.
#'
#' @return `x` with the inserted rows, sorted by time, and a logical column
#'   `inserted` that is `TRUE` for the new rows. If `x` is a grouped tibble,
#'   the result has the same groups.
#'
#' @examples
#' gaze <- read_g3_gaze(g3_example())
#' gappy <- dplyr::slice(gaze, -(100:109))
#' filled <- g3_fill_gaps(gappy)
#' nrow(gappy)
#' nrow(filled)
#' filled |>
#'   dplyr::filter(inserted) |>
#'   dplyr::select(time, left_pupil, valid)
#' @export
g3_fill_gaps <- function(x, rate = NULL) {
  check_df(x, "time", "x")
  if (any(c("accel_x", "gyro_x", "mag_x") %in% names(x))) {
    stop("`g3_fill_gaps()` works on gaze data. IMU data mix sensors sampled ",
         "at different rates, so there is no single sample interval.", call. = FALSE)
  }
  if (!is.null(rate) && (!is_number(rate) || rate <= 0)) {
    stop("`rate` must be a single positive number.", call. = FALSE)
  }
  out <- by_recording(x, function(xi, id) fill_one(xi, id, rate))
  out |> restore_groups(x)
}

fill_one <- function(xi, id, rate) {
  xi <- xi |> dplyr::arrange(time)
  if (!"inserted" %in% names(xi)) {
    xi <- xi |> dplyr::mutate(inserted = FALSE)
  }
  if (nrow(xi) < 2L) {
    return(xi)
  }
  dt <- diff(xi$time)
  r <- rate %||% (xi$time |> sampling_rate() |> nominal_rate())
  k <- pmax(round(dt * r) - 1, 0)
  k[is.na(k)] <- 0
  if (!any(k > 0)) {
    return(xi)
  }
  gap <- rep(seq_along(k), k)
  step <- sequence(k[k > 0])
  flags <- c("valid", "valid_left", "valid_right") |>
    intersect(names(xi)) |>
    purrr::set_names() |>
    purrr::map(\(v) FALSE)
  constant <- xi |>
    dplyr::select(!dplyr::any_of(g3_columns())) |>
    dplyr::select(dplyr::where(\(v) is.atomic(v) && length(unique(v)) == 1L)) |>
    dplyr::slice(1)
  new <- tibble::tibble(time = xi$time[gap] + step / (k[gap] + 1) * dt[gap]) |>
    dplyr::cross_join(constant) |>
    dplyr::mutate(
      recording = id,
      !!!flags,
      inserted = TRUE
    )
  xi |>
    dplyr::bind_rows(new |> dplyr::select(dplyr::any_of(names(xi)))) |>
    dplyr::arrange(time)
}

g3_columns <- function() {
  c("recording", names(empty_gaze()), "inserted", "syncport", "pulse",
    "pulse_time", "epoch", "epoch_time", "clock_time", "left_azimuth", "right_azimuth",
    "left_elevation", "right_elevation", "vergence", "left_velocity", "right_velocity")
}

nominal_rate <- function(r) {
  for (nominal in c(50, 100)) {
    if (isTRUE(abs(r - nominal) / nominal < 0.1)) {
      return(nominal)
    }
  }
  r
}

#' Gaze angles and vergence
#'
#' Converts the gaze direction of each eye to horizontal and vertical angles
#' and adds the vergence angle between the two eyes.
#'
#' The glasses report gaze direction as a unit vector in a coordinate system
#' centred on the scene camera, where x points to the wearer's left, y up
#' and z forward (Tobii Pro Glasses 3 Developer Guide). Angles are relative
#' to the z axis, so (0, 0) is straight ahead of the glasses.
#'
#' @param gaze Gaze data from [read_g3_gaze()].
#'
#' @return `gaze` with these columns added, in degrees:
#' \describe{
#'   \item{left_azimuth, right_azimuth}{Horizontal angle, positive to the
#'     wearer's right.}
#'   \item{left_elevation, right_elevation}{Vertical angle, positive up.}
#'   \item{vergence}{Angle between the left and right gaze directions.
#'     Larger values mean the eyes converge on a closer point.}
#' }
#' Samples without a direction for an eye get `NA`. The result is a tibble,
#' and if `gaze` is a grouped tibble, it has the same groups.
#'
#' @examples
#' gaze <- g3_gaze_angles(read_g3_gaze(g3_example()))
#' gaze |>
#'   dplyr::select(left_azimuth, left_elevation, vergence) |>
#'   summary()
#' @export
g3_gaze_angles <- function(gaze) {
  check_df(gaze, direction_columns(), "gaze")
  gaze |>
    drop_groups() |>
    dplyr::mutate(
      left_azimuth = azimuth(left_direction_x, left_direction_z),
      left_elevation = elevation(left_direction_x, left_direction_y, left_direction_z),
      right_azimuth = azimuth(right_direction_x, right_direction_z),
      right_elevation = elevation(right_direction_x, right_direction_y, right_direction_z),
      vergence = vector_angle(left_direction_x, left_direction_y, left_direction_z,
                              right_direction_x, right_direction_y, right_direction_z)
    ) |>
    restore_groups(gaze)
}

#' Angular gaze velocity
#'
#' Adds the angular velocity of each eye: the angle between the gaze
#' directions of two consecutive samples, divided by the time between them.
#' The directions are relative to the glasses, so the velocity is that of
#' the eye in the head. It is not smoothed, and can be the starting point
#' for detecting fixations and saccades, for example with a velocity
#' threshold.
#'
#' @param gaze Gaze data from [read_g3_gaze()] or [g3_epochs()].
#'
#' @return `gaze` with columns `left_velocity` and `right_velocity` in
#'   degrees per second. Each sample is compared with the previous sample of
#'   the same recording and epoch. The first sample, and samples where either
#'   sample of the pair has no direction, get `NA`. The result is a tibble,
#'   and if `gaze` is a grouped tibble, it has the same groups.
#'
#' @examples
#' gaze <- g3_gaze_velocity(read_g3_gaze(g3_example()))
#' gaze |>
#'   dplyr::select(time, left_velocity, right_velocity) |>
#'   summary()
#' @export
g3_gaze_velocity <- function(gaze) {
  check_df(gaze, c("time", direction_columns()), "gaze")
  gaze |>
    drop_groups() |>
    dplyr::mutate(
      left_velocity = eye_velocity(time, left_direction_x, left_direction_y, left_direction_z),
      right_velocity = eye_velocity(time, right_direction_x, right_direction_y,
                                    right_direction_z),
      .by = dplyr::any_of(c("recording", "epoch"))
    ) |>
    restore_groups(gaze)
}

direction_columns <- function() {
  paste0(rep(c("left", "right"), each = 3), "_direction_", c("x", "y", "z"))
}

eye_velocity <- function(time, x, y, z) {
  previous <- \(v) dplyr::lag(v, order_by = time)
  dt <- time - previous(time)
  v <- vector_angle(previous(x), previous(y), previous(z), x, y, z) / dt
  dplyr::if_else(dt > 0, v, NA_real_)
}

degrees <- function(radians) radians * 180 / pi

azimuth <- function(x, z) degrees(atan2(-x, z))

elevation <- function(x, y, z) degrees(atan2(y, sqrt(x^2 + z^2)))

vector_angle <- function(ax, ay, az, bx, by, bz) {
  cx <- ay * bz - az * by
  cy <- az * bx - ax * bz
  cz <- ax * by - ay * bx
  degrees(atan2(sqrt(cx^2 + cy^2 + cz^2), ax * bx + ay * by + az * bz))
}

#' Add clock time to samples
#'
#' Adds the date and time of each sample: the start time of the recording,
#' as stored in `recording.g3`, plus `time`. The clock time helps to align
#' the samples with other devices that log the time of day.
#'
#' @param x A data frame with a `time` column, such as the output of
#'   [read_g3_gaze()], [read_g3_imu()] or [read_g3_events()].
#' @param recordings The start time of the recordings: a recording from
#'   [read_g3()], metadata from [read_g3_info()] or the output of
#'   [list_g3_recordings()]. With several recordings in `x`, use the output
#'   of [list_g3_recordings()], which is matched to `x` through the
#'   `recording` column.
#'
#' @return `x` with a POSIXct column `clock_time` after `time`, in UTC. Use
#'   [format()] with the `timezone` from [read_g3_info()] to show local time.
#'   If `x` is a grouped tibble, the result has the same groups.
#'
#' @examples
#' rec <- read_g3(g3_example())
#' g3_add_clock_time(rec$gaze, rec)
#'
#' recordings <- list_g3_recordings(dirname(g3_example()))
#' g3_add_clock_time(read_g3_gaze(recordings), recordings)
#' @export
g3_add_clock_time <- function(x, recordings) {
  check_df(x, "time", "x")
  starts <- recording_starts(recordings)
  d <- x |> drop_groups()
  n_x <- if ("recording" %in% names(d)) d$recording |> unique() |> length() else 1L
  if ("recording" %in% names(starts) && "recording" %in% names(d)) {
    missing <- d$recording |> unique() |> setdiff(starts$recording)
    if (length(missing) > 0L) {
      warning("No start time for recording", if (length(missing) > 1L) "s", ": ",
              paste(missing, collapse = ", "), call. = FALSE)
    }
    d <- d |>
      dplyr::left_join(starts |> dplyr::select(recording, .start = created),
                       by = "recording", relationship = "many-to-one") |>
      dplyr::mutate(clock_time = .start + time, .after = time) |>
      dplyr::select(!.start)
  } else if (nrow(starts) == 1L && n_x <= 1L) {
    d <- d |> dplyr::mutate(clock_time = starts$created + time, .after = time)
  } else {
    stop("`recordings` and `x` must both have a `recording` column when they ",
         "hold several recordings.", call. = FALSE)
  }
  d |> restore_groups(x)
}

recording_starts <- function(recordings) {
  if (inherits(recordings, "g3_recording")) {
    recordings <- recordings$info
  }
  if (inherits(recordings, "g3_info")) {
    return(tibble::tibble(created = recordings$created))
  }
  check_df(recordings, "created", "recordings")
  if (!inherits(recordings$created, "POSIXct")) {
    stop("The `created` column of `recordings` must be POSIXct.", call. = FALSE)
  }
  recordings |> drop_groups() |> dplyr::select(dplyr::any_of("recording"), created)
}

#' Downsample to fixed time bins
#'
#' Averages samples within bins of fixed width, for example to reduce 50 Hz
#' data to 100 ms bins before fitting a generalised additive mixed model. Fewer
#' samples make models faster to fit and reduce the autocorrelation the model
#' has to account for.
#'
#' Bins are counted from time 0, or from the onset for epochs from
#' [g3_epochs()], so that the onset falls on a bin boundary. Each bin is
#' labelled with its start time. Rows are grouped by the `recording`,
#' `epoch` and `eye` columns where these exist, so the function works on the
#' output of [read_g3_gaze()], [g3_add_syncport()], [g3_epochs()] and
#' [g3_pupil_long()]. Columns named in `by` are added to these groups, and so
#' are the groups of a grouped tibble.
#'
#' @param x Gaze data from [read_g3_gaze()], epochs from [g3_epochs()] or
#'   long pupil data from [g3_pupil_long()].
#' @param bin Bin width in seconds.
#' @param min_valid Proportion of samples in a bin that must have a value.
#'   A numeric column is `NA` in bins where fewer of its samples are
#'   available, so that bins mostly lost to a blink do not get a value from
#'   the few samples left.
#' @param by Names of further columns to group by, such as a participant or
#'   condition column. They are kept in the result.
#'
#' @return A tibble with one row per bin and group, starting with the
#'   grouping columns. `samples` gives the number of samples in the bin. A
#'   `pulse` column gets the pulse of the first sample in the bin. Other
#'   numeric columns hold the mean of the available samples, and logical
#'   columns, such as `valid`, the proportion of `TRUE` samples. All other
#'   columns are dropped. A grouped tibble keeps its groups.
#'
#' @examples
#' gaze <- read_g3_gaze(g3_example())
#' g3_downsample(gaze, bin = 0.1)
#'
#' rec <- read_g3(g3_example())
#' ep <- g3_epochs(rec$gaze, rec$events, before = 0.5, after = 3, direction = "out")
#' g3_downsample(g3_pupil_long(ep), bin = 0.1)
#'
#' gaze |>
#'   dplyr::mutate(participant = "P01") |>
#'   g3_downsample(bin = 0.1, by = "participant")
#' @export
g3_downsample <- function(x, bin = 0.1, min_valid = 0.5, by = NULL) {
  check_df(x, "time", "x")
  if (!is_number(bin) || bin <= 0) {
    stop("`bin` must be a single positive number of seconds.", call. = FALSE)
  }
  if (!is_number(min_valid) || min_valid < 0 || min_valid > 1) {
    stop("`min_valid` must be a single number between 0 and 1.", call. = FALSE)
  }
  if (!is.null(by) && (!is.character(by) || anyNA(by))) {
    stop("`by` must be a character vector of column names.", call. = FALSE)
  }
  unknown <- setdiff(by, names(x))
  if (length(unknown) > 0L) {
    stop("`by` names columns that are not in `x`: ",
         paste(unknown, collapse = ", "), call. = FALSE)
  }
  tcol <- if ("epoch_time" %in% names(x)) "epoch_time" else "time"
  if (tcol %in% by) {
    stop("`by` cannot include the time column `", tcol, "`.", call. = FALSE)
  }
  groups <- c("recording", "epoch", "eye") |>
    intersect(names(x)) |>
    c(by, x |> dplyr::group_vars() |> setdiff(tcol)) |>
    unique()
  firsts <- "pulse" |> intersect(names(x)) |> setdiff(groups)
  d <- x |>
    drop_groups() |>
    dplyr::arrange(.data[[tcol]]) |>
    dplyr::mutate(.bin = floor(.data[[tcol]] / bin + 1e-9) * bin) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(groups, ".bin"))))
  id <- dplyr::group_indices(d)
  keys <- dplyr::group_keys(d)
  samples <- tabulate(id, nbins = nrow(keys))
  d <- d |> dplyr::ungroup()
  values <- d |>
    dplyr::select(!dplyr::any_of(c(groups, ".bin", tcol, firsts, "samples"))) |>
    dplyr::select(dplyr::where(\(v) is.numeric(v) || is.logical(v)))
  keys |>
    dplyr::rename(dplyr::all_of(stats::setNames(".bin", tcol))) |>
    dplyr::mutate(samples = samples) |>
    dplyr::bind_cols(
      d |> dplyr::select(dplyr::all_of(firsts)) |> dplyr::slice(match(seq_along(samples), id)),
      bin_means(values, id, samples, min_valid)
    ) |>
    dplyr::select(dplyr::all_of(c(groups, tcol)), samples, dplyr::any_of(names(x))) |>
    restore_groups(x)
}

bin_means <- function(values, id, samples, min_valid) {
  if (length(samples) == 0L) {
    return(values |> dplyr::mutate(dplyr::across(dplyr::everything(), as.numeric)))
  }
  if (ncol(values) == 0L) {
    return(tibble::new_tibble(list(), nrow = length(samples)))
  }
  m <- values |> dplyr::mutate(dplyr::across(dplyr::everything(), as.numeric)) |> as.matrix()
  ok <- !is.na(m)
  m[!ok] <- 0
  counts <- rowsum(ok + 0, id, reorder = TRUE)
  means <- rowsum(m, id, reorder = TRUE) / counts
  means[counts == 0 | counts < min_valid * samples] <- NA_real_
  dimnames(means) <- list(NULL, names(values))
  tibble::as_tibble(means)
}
