read_records <- function(file) {
  if (!file.exists(file)) {
    stop("File not found: ", file, call. = FALSE)
  }
  if (identical(readBin(file, "raw", 4L), as.raw(c(0x50, 0x4b, 0x03, 0x04)))) {
    stop(file, " is a ZIP archive. Unzip it and read the files inside.", call. = FALSE)
  }
  con <- gzfile(file, open = "rt")
  on.exit(close(con))
  warned <- NULL
  lines <- tryCatch(
    withCallingHandlers(readLines(con, warn = FALSE), warning = function(w) {
      warned <<- conditionMessage(w)
    }),
    error = function(e) {
      stop("Could not read ", file, ": ", warned %||% conditionMessage(e),
           ". The file may be damaged.", call. = FALSE)
    }
  )
  lines[!validUTF8(lines)] <- "invalid UTF-8"
  if (length(lines) > 0L) {
    lines[1] <- drop_bom(lines[1])
  }
  lines <- lines[stringr::str_detect(lines, "\\S")]
  if (length(lines) == 0L) {
    return(list())
  }
  parsed <- parse_lines(lines)
  if (!is.null(parsed)) {
    return(parsed[purrr::map_lgl(parsed, is.list)])
  }
  bad <- length(lines)
  parsed <- parse_lines(lines[-bad])
  if (is.null(parsed)) {
    ok <- lines |> purrr::map_lgl(\(l) isTRUE(jsonlite::validate(l)))
    bad <- which(!ok)
    parsed <- parse_lines(lines[ok])
  }
  shown <- bad |> utils::head(5L) |> paste(collapse = ", ")
  if (length(bad) > 5L) shown <- paste0(shown, ", ...")
  hint <- if (length(bad) == length(lines)) {
    "No line could be read. Is this a Glasses 3 data file in UTF-8?"
  } else {
    "The file may be incomplete."
  }
  warning(sprintf(
    "%s: skipped %d damaged line%s (line %s). %s",
    file, length(bad), if (length(bad) == 1L) "" else "s", shown, hint
  ), call. = FALSE)
  parsed[purrr::map_lgl(parsed, is.list)]
}

parse_lines <- function(lines) {
  if (length(lines) == 0L) {
    return(list())
  }
  tryCatch(
    paste0("[", paste(lines, collapse = ","), "]") |> jsonlite::parse_json(),
    error = function(e) NULL
  )
}

field <- function(x, name) {
  lapply(x, \(e) if (is.list(e)) e[[name]] else NULL)
}

pluck_num <- function(x, name) {
  v <- field(x, name)
  out <- rep(NA_real_, length(v))
  ok <- lengths(v) == 1L
  out[ok] <- v[ok] |> unlist(use.names = FALSE) |> as.numeric() |> suppressWarnings()
  out
}

pluck_chr <- function(x, name) {
  v <- field(x, name)
  out <- rep(NA_character_, length(v))
  ok <- lengths(v) == 1L
  out[ok] <- v[ok] |> unlist(use.names = FALSE) |> as.character()
  out
}

pluck_vec <- function(x, name, prefix, suffix = c("x", "y", "z")) {
  k <- length(suffix)
  v <- field(x, name)
  ok <- lengths(v) == k
  values <- unlist(v[ok], use.names = FALSE)
  if (length(values) != k * sum(ok)) {
    ok <- ok & purrr::map_int(v, \(e) length(unlist(e))) == k
    values <- unlist(v[ok], use.names = FALSE)
  }
  out <- matrix(NA_real_, nrow = length(x), ncol = k)
  if (any(ok)) {
    out[ok, ] <- values |> as.numeric() |> suppressWarnings() |> matrix(ncol = k, byrow = TRUE)
  }
  colnames(out) <- paste(prefix, suffix, sep = "_")
  tibble::as_tibble(out)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

resolve_file <- function(path, stream, default) {
  if (!dir.exists(path)) {
    return(path)
  }
  rec <- tryCatch(read_recording_file(path, simplify = FALSE), error = function(e) NULL)
  name <- purrr::pluck(rec, stream, "file")
  if (!is.character(name) || length(name) != 1L) {
    name <- default
  }
  file.path(path, name)
}

scalar_chr <- function(x) {
  if (is.atomic(x) && length(x) == 1L && !is.na(x)) as.character(x) else NA_character_
}

scalar_num <- function(x) {
  if (is.numeric(x) && length(x) == 1L) as.numeric(x) else NA_real_
}

is_number <- function(x) {
  is.numeric(x) && length(x) == 1L && !is.na(x)
}

read_recording_file <- function(path, simplify = TRUE) {
  file <- file.path(path, "recording.g3")
  if (!file.exists(file)) {
    stop("No recording.g3 in ", path, ". Is this a Glasses 3 recording folder?",
         call. = FALSE)
  }
  text <- readLines(file, warn = FALSE) |>
    paste(collapse = "\n") |>
    drop_bom()
  Encoding(text) <- "UTF-8"
  rec <- tryCatch(
    jsonlite::fromJSON(text, simplifyVector = simplify),
    error = function(e) NULL
  )
  if (!is.list(rec) || is.null(names(rec))) {
    stop("Could not read ", file, ". The file may be damaged.", call. = FALSE)
  }
  rec
}

drop_bom <- function(line) {
  bytes <- charToRaw(line)
  if (length(bytes) < 3L || !identical(bytes[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) {
    return(line)
  }
  rawToChar(bytes[-(1:3)])
}

sampling_rate <- function(time) {
  steps <- time |> sort() |> diff()
  steps <- steps[steps > 0]
  if (length(steps) == 0L) {
    return(NA_real_)
  }
  1 / stats::median(steps)
}

check_seconds <- function(x, what) {
  if (!is_number(x) || x < 0) {
    stop("`", what, "` must be a single non-negative number.", call. = FALSE)
  }
}

check_window <- function(from, to) {
  if (!is_number(from) || !is_number(to) || from >= to) {
    stop("`from` and `to` must be single numbers with `from` before `to`.",
         call. = FALSE)
  }
}

check_samples_in <- function(time, from, to) {
  if (!any(time >= from & time <= to, na.rm = TRUE)) {
    stop("`x` has no samples between `from` and `to`.", call. = FALSE)
  }
}

get_gaze <- function(x) {
  if (is.null(x$gaze)) {
    stop("This recording was read without gaze data. Use `read_g3()` with ",
         "\"gaze\" in `data`.", call. = FALSE)
  }
  x$gaze
}

check_df <- function(x, cols, what,
                     numeric = setdiff(cols, c("recording", "type", "direction", "data"))) {
  if (!is.data.frame(x) || !all(cols %in% names(x))) {
    stop("`", what, "` must be a data frame with columns: ",
         paste(cols, collapse = ", "), call. = FALSE)
  }
  wrong <- numeric |> purrr::discard(\(col) is.numeric(x[[col]]) || all(is.na(x[[col]])))
  if (length(wrong) > 0L) {
    stop("These columns of `", what, "` must be numeric: ",
         paste(wrong, collapse = ", "), call. = FALSE)
  }
}

restore_groups <- function(out, x) {
  vars <- x |> dplyr::group_vars() |> intersect(names(out))
  if (length(vars) == 0L) {
    return(out)
  }
  out |>
    dplyr::group_by(dplyr::across(dplyr::all_of(vars)), .drop = dplyr::group_by_drop_default(x))
}

drop_groups <- function(x) {
  x |> dplyr::ungroup() |> tibble::as_tibble()
}
