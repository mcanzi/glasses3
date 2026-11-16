read_records <- function(file) {
  if (!file.exists(file)) {
    stop("File not found: ", file, call. = FALSE)
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
  warning(sprintf(
    "%s: skipped %d damaged line%s (line %s). The file may be incomplete.",
    file, length(bad), if (length(bad) == 1L) "" else "s", shown
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
  lapply(x, `[[`, name)
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

resolve_file <- function(path, file) {
  if (dir.exists(path)) {
    return(file.path(path, file))
  }
  path
}

is_number <- function(x) {
  is.numeric(x) && length(x) == 1L && !is.na(x)
}

sampling_rate <- function(time) {
  if (length(time) < 2L) {
    return(NA_real_)
  }
  1 / (time |> diff() |> stats::median(na.rm = TRUE))
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

get_gaze <- function(x) {
  if (is.null(x$gaze)) {
    stop("This recording was read without gaze data. Use `read_g3()` with ",
         "\"gaze\" in `data`.", call. = FALSE)
  }
  x$gaze
}

check_df <- function(x, cols, what) {
  if (!is.data.frame(x) || !all(cols %in% names(x))) {
    stop("`", what, "` must be a data frame with columns: ",
         paste(cols, collapse = ", "), call. = FALSE)
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
