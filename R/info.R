#' Read recording metadata
#'
#' Reads `recording.g3` and the files in the `meta` folder.
#'
#' @param path Path to a recording folder.
#'
#' @return A list of class `g3_info` with these elements:
#'   * `name` and `uuid` of the recording
#'   * `created`, the start time (POSIXct, UTC), and `timezone`
#'   * `duration` in seconds
#'   * `gaze_samples` and `gaze_valid_samples`, as counted by the glasses
#'   * `participant`, as entered when recording
#'   * `firmware` version
#'   * `recording_unit` and `head_unit` serial numbers
#'   * `files`, the names of the data files
#'   * `scene_camera`, the camera calibration
#'   * `meta`, all files in the `meta` folder as character strings, or as
#'     raw vectors for files that are not UTF-8 text
#'
#' @examples
#' read_g3_info(g3_example())
#' @export
read_g3_info <- function(path) {
  rec <- read_recording_file(path)
  pick <- function(...) purrr::pluck(rec, ...)
  meta_name <- scalar_chr(pick("meta-folder"))
  if (is.na(meta_name)) meta_name <- "meta"
  meta_dir <- file.path(path, meta_name)
  meta <- list()
  if (dir.exists(meta_dir)) {
    meta_files <- list.files(meta_dir) |>
      purrr::discard(\(f) dir.exists(file.path(meta_dir, f)))
    meta <- file.path(meta_dir, meta_files) |>
      purrr::map(read_meta_file) |>
      purrr::set_names(meta_files)
  }
  participant <- meta_text(meta, "participant")
  if (!is.na(participant) && jsonlite::validate(participant)) {
    p <- jsonlite::fromJSON(participant)
    if (is.list(p) && is.character(p[["name"]]) && length(p[["name"]]) == 1L) {
      participant <- stringr::str_trim(p[["name"]])
    }
  }
  out <- list(
    name = scalar_chr(pick("name")),
    uuid = scalar_chr(pick("uuid")),
    created = start_time(pick("created"), path),
    timezone = scalar_chr(pick("timezone")),
    duration = scalar_num(pick("duration")),
    gaze_samples = pick("gaze", "samples") |> scalar_num() |> as.integer(),
    gaze_valid_samples = pick("gaze", "valid-samples") |> scalar_num() |> as.integer(),
    participant = participant,
    firmware = meta_text(meta, "RuVersion"),
    recording_unit = meta_text(meta, "RuSerial"),
    head_unit = meta_text(meta, "HuSerial"),
    files = list(
      gaze = scalar_chr(pick("gaze", "file")),
      imu = scalar_chr(pick("imu", "file")),
      events = scalar_chr(pick("events", "file")),
      scene_video = scalar_chr(pick("scenecamera", "file"))
    ),
    scene_camera = pick("scenecamera", "camera-calibration"),
    meta = meta
  )
  class(out) <- "g3_info"
  out
}

start_time <- function(created, path) {
  text <- scalar_chr(created)
  out <- as.POSIXct(text, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  if (!is.na(text) && is.na(out)) {
    warning("Could not read the start time \"", text, "\" in ",
            file.path(path, "recording.g3"), ". `created` is `NA`.", call. = FALSE)
  }
  out
}

read_meta_file <- function(file) {
  bytes <- readBin(file, "raw", file.size(file))
  if (any(bytes == as.raw(0L))) {
    return(bytes)
  }
  text <- rawToChar(bytes)
  if (!validUTF8(text)) {
    return(bytes)
  }
  Encoding(text) <- "UTF-8"
  stringr::str_trim(text)
}

meta_text <- function(meta, key) {
  value <- meta[[key]]
  if (is.character(value) && length(value) == 1L) value else NA_character_
}

#' List recordings
#'
#' Searches a folder, such as the root of the Glasses 3 SD card, for
#' recording folders.
#'
#' @param path Folder to search.
#' @param recursive Search subfolders.
#'
#' @return A tibble with one row per recording: `recording` (the folder
#'   name, as used in the `recording` column by the readers), `path`, `name`,
#'   `participant`, `created` and `duration`. A recording whose
#'   `recording.g3` cannot be read is listed with `NA` metadata and a
#'   warning. Pass it to [read_g3_gaze()],
#'   [read_g3_imu()] or [read_g3_events()] to read all recordings at once.
#'
#' @examples
#' recordings <- list_g3_recordings(dirname(g3_example()))
#' recordings
#' read_g3_gaze(recordings)
#' @export
list_g3_recordings <- function(path, recursive = TRUE) {
  if (!is.character(path) || length(path) != 1L || !dir.exists(path)) {
    stop("Folder not found: ", paste(path, collapse = ", "), call. = FALSE)
  }
  files <- list.files(path, pattern = "^recording\\.g3$", recursive = recursive,
                      full.names = TRUE)
  dirs <- dirname(files)
  if (length(dirs) == 0L) {
    return(tibble::tibble(recording = character(0), path = character(0),
                          name = character(0), participant = character(0),
                          created = as.POSIXct(character(0), tz = "UTC"),
                          duration = numeric(0)))
  }
  infos <- dirs |> purrr::map(\(d) tryCatch(read_g3_info(d), error = function(e) NULL))
  damaged <- dirs[purrr::map_lgl(infos, is.null)]
  if (length(damaged) > 0L) {
    warning("Could not read recording.g3 in ", paste(damaged, collapse = ", "),
            ". These recordings are listed without metadata.", call. = FALSE)
  }
  infos <- infos |>
    purrr::map(\(i) i %||% list(name = NA_character_, participant = NA_character_,
                                created = as.POSIXct(NA, tz = "UTC"), duration = NA_real_))
  tibble::tibble(
    recording = file.path(dirs, "recording.g3") |> recording_ids(),
    path = dirs,
    name = infos |> purrr::map_chr(\(i) as.character(i$name)),
    participant = infos |> purrr::map_chr(\(i) as.character(i$participant)),
    created = infos |> purrr::map("created") |> purrr::list_c(),
    duration = infos |> purrr::map_dbl(\(i) as.numeric(i$duration))
  ) |>
    dplyr::arrange(created)
}

#' Path to the example recording
#'
#' The package includes the first 30 seconds of a Glasses 3 recording at
#' 50 Hz. The scene video is left out, and the participant name, serial
#' numbers, recording ID and start time are replaced with placeholders.
#'
#' @return Path to the example recording folder.
#'
#' @examples
#' g3_example()
#' @export
g3_example <- function() {
  system.file("extdata", "recording", package = "glasses3", mustWork = TRUE)
}
