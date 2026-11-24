#' Read a Tobii Pro Glasses 3 recording
#'
#' Reads a recording folder as written to the SD card by the Tobii Pro
#' Glasses 3. The folder contains `recording.g3`, `gazedata.gz`,
#' `imudata.gz`, `eventdata.gz` and a `meta` folder. The scene video is not
#' needed. All readers take the names of the data files from `recording.g3`,
#' and use these usual names if it does not give them.
#'
#' `read_g3()` reads one recording. To read several recordings into one data
#' frame, give their paths to [read_g3_gaze()], [read_g3_imu()] or
#' [read_g3_events()].
#'
#' @param path Path to a recording folder.
#' @param data Which data streams to read. Any of `"gaze"`, `"imu"` and
#'   `"events"`.
#'
#' @return An object of class `g3_recording`: a list with elements `info`
#'   (see [read_g3_info()]), `gaze` (see [read_g3_gaze()]), `imu` (see
#'   [read_g3_imu()]) and `events` (see [read_g3_events()]). Streams not
#'   requested are `NULL`.
#'
#' @seealso [list_g3_recordings()] to find recordings on an SD card.
#'
#' @examples
#' path <- g3_example()
#' rec <- read_g3(path)
#' rec
#' summary(rec)
#' rec$gaze
#' plot(rec, direction = "out")
#' @export
read_g3 <- function(path, data = c("gaze", "imu", "events")) {
  data <- match.arg(data, several.ok = TRUE)
  if (!is.character(path) || anyNA(path)) {
    stop("`path` must be the path to a recording folder.", call. = FALSE)
  }
  if (length(path) != 1L) {
    stop("`read_g3()` reads one recording. Use `read_g3_gaze()` and the other ",
         "readers for several recordings.", call. = FALSE)
  }
  if (!dir.exists(path)) {
    stop("Recording folder not found: ", path, call. = FALSE)
  }
  info <- read_g3_info(path)
  id <- path |> normalizePath() |> basename()
  stream <- function(name, default, parser) {
    if (!name %in% data) return(NULL)
    path |> resolve_file(name, default) |> read_stream(parser, id)
  }
  out <- list(
    info = info,
    gaze = stream("gaze", "gazedata.gz", parse_gaze),
    imu = stream("imu", "imudata.gz", parse_imu),
    events = stream("events", "eventdata.gz", parse_events)
  )
  class(out) <- "g3_recording"
  out
}

#' Read gaze and pupil data
#'
#' Parses `gazedata.gz` into one row per sample. Samples where the glasses
#' detected no gaze are kept, with `NA` values, so that the time series stays
#' complete. Lines that cannot be parsed, such as the cut-off last line of an
#' incomplete file, are skipped with a warning; see [g3_fill_gaps()] to
#' replace them with empty rows. A file whose compressed data are damaged
#' cannot be read and gives an error.
#'
#' @param path Path to a recording folder or directly to a `gazedata.gz`
#'   file. Several paths, or the output of [list_g3_recordings()], read
#'   several recordings into one tibble.
#'
#' @return A tibble with columns:
#' \describe{
#'   \item{recording}{Name of the recording folder. If two recordings in
#'     `path` have folders of the same name, the full path is used instead.}
#'   \item{time}{Seconds since the start of the recording.}
#'   \item{gaze2d_x, gaze2d_y}{Gaze point in normalised scene camera
#'     coordinates, with (0, 0) at the top left of the video frame and (1, 1)
#'     at the bottom right.}
#'   \item{gaze3d_x, gaze3d_y, gaze3d_z}{Point where the gaze of the two eyes
#'     meets, in millimetres from the scene camera.}
#'   \item{left_origin_x, ..., right_direction_z}{Position of each eye in
#'     millimetres from the scene camera, and its gaze direction as a unit
#'     vector.}
#'   \item{left_pupil, right_pupil}{Pupil diameter for each eye in
#'     millimetres, the unit given in the Tobii Pro Glasses 3 Developer
#'     Guide.}
#'   \item{valid_left, valid_right}{Whether the glasses reported data for
#'     that eye.}
#'   \item{valid}{Whether the sample has a gaze point. The glasses can
#'     estimate one from a single eye, so this can be `TRUE` when one eye is
#'     invalid.}
#' }
#' See the Tobii Pro Glasses 3 Developer Guide for the coordinate systems.
#'
#' The glasses record gaze at 50 or 100 Hz, in the same file format. The rate
#' is not stored in the recording, so functions that need it work it out from
#' the timestamps.
#'
#' @examples
#' gaze <- read_g3_gaze(g3_example())
#' gaze
#'
#' recordings <- list_g3_recordings(dirname(g3_example()))
#' read_g3_gaze(recordings)
#' @export
read_g3_gaze <- function(path) {
  read_many(path, "gaze", "gazedata.gz", parse_gaze)
}

#' Read inertial measurement unit data
#'
#' Parses `imudata.gz`. Accelerometer and gyroscope samples and magnetometer
#' samples are stored on separate lines at different rates, so each row has
#' `NA` for the sensors not sampled at that time. Lines that cannot be parsed
#' are skipped with a warning.
#'
#' @param path Path to a recording folder or directly to an `imudata.gz`
#'   file. Several paths, or the output of [list_g3_recordings()], read
#'   several recordings into one tibble.
#'
#' @return A tibble with columns `recording` (see [read_g3_gaze()]), `time`
#'   (seconds since the start of the recording), `accel_x`, `accel_y`,
#'   `accel_z` (accelerometer), `gyro_x`, `gyro_y`, `gyro_z` (gyroscope) and
#'   `mag_x`, `mag_y`, `mag_z` (magnetometer). Following the Tobii Pro
#'   Glasses 3 Developer Guide, acceleration is in metres per second
#'   squared, rotation in degrees per second and the magnetic field in
#'   microtesla.
#'
#' @examples
#' read_g3_imu(g3_example())
#' @export
read_g3_imu <- function(path) {
  read_many(path, "imu", "imudata.gz", parse_imu)
}

#' Read event data
#'
#' Parses `eventdata.gz`, which holds sync port signals and any events sent
#' to the glasses through the API during the recording. Lines that cannot be
#' parsed are skipped with a warning.
#'
#' @param path Path to a recording folder or directly to an `eventdata.gz`
#'   file. Several paths, or the output of [list_g3_recordings()], read
#'   several recordings into one tibble.
#'
#' @return A tibble with columns `recording` (see [read_g3_gaze()]), `time`
#'   (seconds since the start of the recording), `type` (for example
#'   `"syncport"`), `direction` and `value` (for sync port events; `NA`
#'   otherwise), and `data`, the event payload as a JSON string, so that other
#'   event types are kept unchanged.
#'
#' @examples
#' read_g3_events(g3_example())
#' @export
read_g3_events <- function(path) {
  read_many(path, "events", "eventdata.gz", parse_events)
}

read_many <- function(path, stream, default, parser) {
  files <- path |>
    g3_paths() |>
    purrr::map_chr(\(p) resolve_file(p, stream, default))
  missing <- files[!file.exists(files)]
  if (length(missing) > 0L) {
    stop("File not found: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  files |>
    purrr::map2(recording_ids(files), \(f, id) read_stream(f, parser, id)) |>
    purrr::list_rbind()
}

read_stream <- function(file, parser, id) {
  out <- parser(file)
  n <- sum(is.na(out$time))
  if (n > 0L) {
    warning(sprintf("%s: %d line%s no valid timestamp. `time` is `NA` for %s.",
                    file, n, if (n == 1L) " has" else "s have", if (n == 1L) "it" else "them"),
            call. = FALSE)
  }
  add_recording(out, id)
}

g3_paths <- function(path) {
  if (is.data.frame(path)) {
    if (!"path" %in% names(path)) {
      stop("A data frame passed as `path` needs a `path` column, as returned ",
           "by `list_g3_recordings()`.", call. = FALSE)
    }
    path <- path$path
  }
  if (!is.character(path) || length(path) == 0L || anyNA(path)) {
    stop("`path` must be one or more paths to recordings.", call. = FALSE)
  }
  path
}

recording_ids <- function(files) {
  dirs <- files |> dirname() |> normalizePath(mustWork = FALSE)
  ids <- basename(dirs)
  if (anyDuplicated(ids)) {
    ids <- dirs
  }
  ids
}

add_recording <- function(x, id) {
  x |> tibble::as_tibble() |> dplyr::mutate(recording = id, .before = 1)
}

of_type <- function(recs, type) {
  recs[pluck_chr(recs, "type") %in% type]
}

sorted <- function(...) {
  dplyr::bind_cols(...) |> dplyr::arrange(time)
}

parse_gaze <- function(file) {
  recs <- file |> read_records() |> of_type("gaze")
  if (length(recs) == 0L) {
    return(empty_gaze())
  }
  d <- field(recs, "data")
  eye <- function(side) {
    e <- field(d, paste0("eye", side))
    dplyr::bind_cols(
      pluck_vec(e, "gazeorigin", paste0(side, "_origin")),
      pluck_vec(e, "gazedirection", paste0(side, "_direction")),
      list(pluck_num(e, "pupildiameter")) |>
        stats::setNames(paste0(side, "_pupil")) |>
        tibble::as_tibble()
    )
  }
  sorted(
    time = pluck_num(recs, "timestamp"),
    pluck_vec(d, "gaze2d", "gaze2d", c("x", "y")),
    pluck_vec(d, "gaze3d", "gaze3d"),
    eye("left"),
    eye("right")
  ) |>
    dplyr::mutate(
      valid_left = !is.na(left_pupil) | !is.na(left_origin_x),
      valid_right = !is.na(right_pupil) | !is.na(right_origin_x),
      valid = !is.na(gaze2d_x)
    )
}

empty_gaze <- function() {
  eye_cols <- c("origin_x", "origin_y", "origin_z",
                "direction_x", "direction_y", "direction_z", "pupil")
  cols <- c("time", "gaze2d_x", "gaze2d_y", "gaze3d_x", "gaze3d_y", "gaze3d_z",
            paste0("left_", eye_cols), paste0("right_", eye_cols))
  cols |>
    purrr::set_names() |>
    purrr::map(\(col) numeric(0)) |>
    tibble::as_tibble() |>
    dplyr::mutate(valid_left = logical(0), valid_right = logical(0), valid = logical(0))
}

parse_imu <- function(file) {
  recs <- file |> read_records() |> of_type("imu")
  d <- field(recs, "data")
  sorted(
    time = pluck_num(recs, "timestamp"),
    pluck_vec(d, "accelerometer", "accel"),
    pluck_vec(d, "gyroscope", "gyro"),
    pluck_vec(d, "magnetometer", "mag")
  )
}

parse_events <- function(file) {
  recs <- read_records(file)
  d <- field(recs, "data")
  sorted(
    time = pluck_num(recs, "timestamp"),
    type = pluck_chr(recs, "type"),
    direction = pluck_chr(d, "direction"),
    value = pluck_num(d, "value"),
    data = d |>
      purrr::map(\(x) x %||% stats::setNames(list(), character(0))) |>
      purrr::map_chr(\(x) x |> jsonlite::toJSON(auto_unbox = TRUE, digits = NA) |> as.character())
  )
}
