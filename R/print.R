#' @export
print.g3_info <- function(x, ...) {
  cat("Tobii Pro Glasses 3 recording\n")
  cat("  Name:        ", x$name, "\n", sep = "")
  cat("  Participant: ", x$participant, "\n", sep = "")
  created <- format(x$created, tz = if (is.na(x$timezone)) "UTC" else x$timezone,
                    usetz = TRUE)
  cat("  Created:     ", created, "\n", sep = "")
  cat("  Duration:    ", sprintf("%.1f s", x$duration), "\n", sep = "")
  if (!is.na(x$gaze_samples)) {
    cat("  Gaze:        ", x$gaze_samples, " samples, ",
        sprintf("%.1f%%", 100 * x$gaze_valid_samples / x$gaze_samples), " valid\n",
        sep = "")
  }
  cat("  Firmware:    ", x$firmware, "\n", sep = "")
  invisible(x)
}

#' @export
print.g3_recording <- function(x, ...) {
  print(x$info)
  if (!is.null(x$gaze) && nrow(x$gaze) > 1L) {
    rate <- x$gaze$time |> sampling_rate() |> sprintf(fmt = "%.0f Hz")
    cat("  Sampling:    ", rate, "\n", sep = "")
  }
  for (s in c("gaze", "imu", "events")) {
    if (!is.null(x[[s]])) {
      cat("  $", s, strrep(" ", 10 - nchar(s)), nrow(x[[s]]), " rows\n", sep = "")
    }
  }
  invisible(x)
}

#' @export
summary.g3_recording <- function(object, ...) {
  g <- get_gaze(object)
  out <- list(
    duration = object$info$duration,
    samples = nrow(g),
    sampling_rate = sampling_rate(g$time),
    valid = mean(g$valid),
    valid_left = mean(g$valid_left),
    valid_right = mean(g$valid_right),
    pupil_left = summary(g$left_pupil),
    pupil_right = summary(g$right_pupil),
    max_gap = if (nrow(g) > 1L) g$time |> diff() |> max() else NA_real_,
    syncport_pulses = if (is.null(object$events)) NA_integer_ else
      object$events |> g3_syncport() |> nrow()
  )
  class(out) <- "summary.g3_recording"
  out
}

#' @export
print.summary.g3_recording <- function(x, ...) {
  cat(sprintf("Duration: %.1f s, %d samples at %.0f Hz (largest gap %.3f s)\n",
              x$duration, x$samples, x$sampling_rate, x$max_gap))
  cat(sprintf("Valid: %.1f%% gaze point, %.1f%% left, %.1f%% right\n",
              100 * x$valid, 100 * x$valid_left, 100 * x$valid_right))
  cat("Left pupil (mm):\n")
  print(x$pupil_left)
  cat("Right pupil (mm):\n")
  print(x$pupil_right)
  cat("Sync port pulses (out): ", x$syncport_pulses, "\n", sep = "")
  invisible(x)
}
