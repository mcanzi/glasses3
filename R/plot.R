#' Plot pupil diameter over time
#'
#' Draws pupil diameter for each eye over time, with sync port pulses as
#' shaded areas. With several recordings in `x`, each gets its own panel,
#' with its own time axis.
#'
#' If `x` comes from [g3_epochs()], the time axis is the time from the onset
#' instead. Each eye gets its own panel, with a thin line for every epoch and
#' a thick line for the mean across epochs.
#'
#' The eye colours and the theme are described in [theme_g3()].
#'
#' @param x Gaze data from [read_g3_gaze()] or [g3_epochs()], or a
#'   `g3_recording` from [read_g3()].
#' @param events Optional event data from [read_g3_events()]. Sync port
#'   pulses are drawn as shaded areas. Taken from `x` if `x` is a
#'   `g3_recording`. Not used for epochs.
#' @param eyes Which eyes to plot.
#' @param from,to Time window in seconds. Defaults to all the data. For
#'   epochs, the window is in seconds from the onset.
#' @param direction Sync port direction to show; see [g3_syncport()].
#' @param smooth Width in seconds of a running median drawn over the raw
#'   trace, or `NULL` (the default) for none. Missing samples are ignored,
#'   and the line is left out where more than half of the window is missing.
#'   For epochs, each epoch is smoothed before the mean is taken. Only the
#'   plot is smoothed.
#'
#' @return A ggplot object. The `plot()` method for recordings from
#'   [read_g3()] draws this plot and returns the recording invisibly.
#'
#' @examples
#' rec <- read_g3(g3_example())
#' plot_g3_pupil(rec, direction = "out")
#' plot_g3_pupil(rec$gaze, eyes = "left", from = 5, to = 15)
#' plot_g3_pupil(rec, direction = "out", smooth = 1)
#'
#' epochs <- g3_epochs(rec$gaze, rec$events, before = 0.2, after = 1, direction = "out")
#' plot_g3_pupil(epochs)
#' @export
plot_g3_pupil <- function(x, events = NULL, eyes = c("left", "right"),
                          from = NULL, to = NULL, direction = c("in", "out"),
                          smooth = NULL) {
  if (inherits(x, "g3_recording")) {
    if (is.null(events)) events <- x$events
    x <- get_gaze(x)
  }
  x <- x |> drop_groups()
  if (!is.null(smooth) && (!is_number(smooth) || smooth <= 0)) {
    stop("`smooth` must be NULL or a single positive number of seconds.", call. = FALSE)
  }
  eyes <- match.arg(eyes, several.ok = TRUE)
  direction <- match.arg(direction)
  check_df(x, c("time", "left_pupil", "right_pupil"), "x")
  if (nrow(x) < 2L) {
    stop("`x` needs at least two samples to plot.", call. = FALSE)
  }
  if (all(c("epoch_time", "epoch") %in% names(x))) {
    return(plot_pupil_epochs(x, eyes, from, to, smooth))
  }
  from <- if (is.null(from)) min(x$time) else from
  to <- if (is.null(to)) max(x$time) else to
  check_window(from, to)
  d <- x |>
    dplyr::filter(time >= from, time <= to) |>
    dplyr::select(dplyr::any_of(c("recording", "time", "left_pupil", "right_pupil"))) |>
    g3_pupil_long() |>
    dplyr::filter(eye %in% eyes)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$time, y = .data$pupil, colour = .data$eye))
  if (!is.null(events)) {
    pulses <- events |> syncport_pulses(direction)
    check_recordings(x, events)
    pulses <- pulses |> pulse_spans(d, from, to)
    if (nrow(pulses) > 0L) {
      p <- p +
        ggplot2::geom_rect(
          data = pulses,
          ggplot2::aes(xmin = .data$onset, xmax = .data$offset, ymin = -Inf, ymax = Inf,
                       fill = .data$label),
          inherit.aes = FALSE
        ) +
        ggplot2::scale_fill_manual(values = c("Sync pulse" = g3_ink[["pulse"]]), name = NULL,
                                   guide = ggplot2::guide_legend(order = 2))
    }
  }
  if (is.null(smooth)) {
    p <- p + ggplot2::geom_line(linewidth = 0.45, na.rm = TRUE)
  } else {
    d <- d |> dplyr::mutate(smoothed = running_median(time, pupil, smooth),
                            .by = dplyr::any_of(c("recording", "eye")))
    p <- p +
      ggplot2::geom_line(linewidth = 0.3, alpha = 0.25, na.rm = TRUE) +
      ggplot2::geom_line(data = d, ggplot2::aes(y = .data$smoothed), linewidth = 0.6,
                         na.rm = TRUE)
  }
  p <- p +
    scale_colour_eyes(guide = ggplot2::guide_legend(order = 1)) +
    ggplot2::labs(x = "Time (s)", y = "Pupil diameter (mm)") +
    theme_g3()
  facet_recordings(p, d, scales = "free_x")
}

plot_pupil_epochs <- function(x, eyes, from, to, smooth = NULL) {
  from <- if (is.null(from)) min(x$epoch_time) else from
  to <- if (is.null(to)) max(x$epoch_time) else to
  check_window(from, to)
  if (!"recording" %in% names(x)) {
    x <- x |> dplyr::mutate(recording = "")
  }
  d <- x |>
    dplyr::filter(epoch_time >= from, epoch_time <= to) |>
    dplyr::select(recording, epoch, time, epoch_time, left_pupil, right_pupil) |>
    g3_pupil_long() |>
    dplyr::filter(eye %in% eyes) |>
    dplyr::mutate(trace = paste(recording, epoch, eye))
  if (!is.null(smooth)) {
    d <- d |>
      dplyr::arrange(trace, epoch_time) |>
      dplyr::mutate(pupil = running_median(epoch_time, pupil, smooth), .by = trace)
  }
  step <- d |>
    dplyr::distinct(trace, epoch_time) |>
    dplyr::arrange(trace, epoch_time) |>
    dplyr::mutate(step = epoch_time - dplyr::lag(epoch_time), .by = trace) |>
    dplyr::pull(step) |>
    stats::median(na.rm = TRUE)
  if (is.na(step)) step <- 1
  mean_d <- d |>
    dplyr::filter(!is.na(pupil)) |>
    dplyr::mutate(bin = round(epoch_time / step) * step) |>
    dplyr::summarise(pupil = mean(pupil), .by = c(recording, eye, bin))
  n_epochs <- d |>
    dplyr::summarise(n = dplyr::n_distinct(epoch), .by = c(recording, eye)) |>
    dplyr::pull(n) |>
    c(1L) |>
    max()
  alpha <- max(0.1, min(0.45, 3 / n_epochs))
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$epoch_time, y = .data$pupil,
                                       colour = .data$eye)) +
    ggplot2::geom_vline(xintercept = 0, colour = g3_ink[["secondary"]], linewidth = 0.35) +
    ggplot2::geom_line(ggplot2::aes(group = .data$trace), linewidth = 0.3, alpha = alpha,
                       na.rm = TRUE) +
    purrr::map(names(g3_eye_means), \(e) {
      ggplot2::geom_line(data = mean_d |> dplyr::filter(eye == e),
                         ggplot2::aes(x = .data$bin, y = .data$pupil),
                         colour = g3_eye_means[[e]], linewidth = 0.9, na.rm = TRUE)
    }) +
    scale_colour_eyes(guide = "none") +
    ggplot2::labs(x = "Time from onset (s)", y = "Pupil diameter (mm)",
                  caption = "Thin lines: single epochs. Thick line: mean across epochs.") +
    theme_g3()
  eye_labels <- ggplot2::as_labeller(c(left = "Left eye", right = "Right eye"))
  if (d$recording |> unique() |> length() > 1L) {
    p + ggplot2::facet_grid(rows = ggplot2::vars(.data$recording),
                            cols = ggplot2::vars(.data$eye),
                            labeller = ggplot2::labeller(.cols = eye_labels))
  } else {
    p + ggplot2::facet_wrap(ggplot2::vars(.data$eye), labeller = eye_labels)
  }
}

running_median <- function(time, y, width) {
  o <- order(time)
  time <- time[o]
  y <- y[o]
  lo <- findInterval(time - width / 2, time, left.open = TRUE) + 1L
  size <- findInterval(time + width / 2, time) - lo + 1L
  out <- seq_along(y) |>
    split(cumsum(size) %/% 1e6) |>
    purrr::map(\(i) window_medians(y, lo[i], size[i])) |>
    unlist(use.names = FALSE)
  out[o] <- out
  out
}

window_medians <- function(y, lo, size) {
  w <- max(size)
  idx <- outer(lo, seq_len(w) - 1L, `+`)
  idx[col(idx) > size] <- NA_integer_
  v <- matrix(y[idx], ncol = w)
  s <- matrix(v[order(row(v), v, method = "radix")], ncol = w, byrow = TRUE)
  m <- rowSums(!is.na(v))
  r <- seq_along(m)
  med <- (s[cbind(r, pmax((m + 1L) %/% 2L, 1L))] + s[cbind(r, m %/% 2L + 1L)]) / 2
  med[m == 0L | m * 2L < size] <- NA_real_
  med
}

pulse_spans <- function(pulses, d, from, to) {
  if ("recording" %in% names(pulses) && "recording" %in% names(d)) {
    ends <- d |> dplyr::summarise(end = max(time), .by = recording)
    pulses <- pulses |>
      dplyr::filter(recording %in% d$recording) |>
      dplyr::left_join(ends, by = "recording")
  } else {
    pulses <- pulses |> dplyr::mutate(end = max(d$time))
  }
  pulses |>
    dplyr::mutate(offset = dplyr::coalesce(offset, pmin(end, to))) |>
    dplyr::filter(offset >= from, onset <= to) |>
    dplyr::mutate(onset = pmax(onset, from), offset = pmin(offset, to), label = "Sync pulse")
}

facet_recordings <- function(p, d, scales = "fixed") {
  if ("recording" %in% names(d) && d$recording |> unique() |> length() > 1L) {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.data$recording), scales = scales)
  }
  p
}

#' Plot gaze position
#'
#' Plots the 2D gaze point in scene camera coordinates, with the top of the
#' video frame at the top of the plot. The frame shows the edges of the scene
#' video, and gaze points outside it are left out. With several recordings in
#' `x`, each gets its own panel.
#'
#' @inheritParams plot_g3_pupil
#' @param type `"points"` for individual samples, shaded from light (early)
#'   to dark (late), or `"density"` for a 2D histogram.
#' @param bins Number of bins along the horizontal axis when
#'   `type = "density"`. The vertical axis gets 9/16 as many, so that the bins
#'   are square in the video.
#'
#' @return A ggplot object.
#'
#' @examples
#' rec <- read_g3(g3_example())
#' plot_g3_gaze(rec)
#' plot_g3_gaze(rec, type = "density")
#' @export
plot_g3_gaze <- function(x, type = c("points", "density"), from = NULL, to = NULL,
                         bins = 40) {
  if (inherits(x, "g3_recording")) {
    x <- get_gaze(x)
  }
  x <- x |> drop_groups()
  type <- match.arg(type)
  check_df(x, c("time", "gaze2d_x", "gaze2d_y"), "x")
  if (nrow(x) < 2L) {
    stop("`x` needs at least two samples to plot.", call. = FALSE)
  }
  from <- if (is.null(from)) min(x$time) else from
  to <- if (is.null(to)) max(x$time) else to
  check_window(from, to)
  d <- x |>
    dplyr::filter(time >= from, time <= to, gaze2d_x >= 0, gaze2d_x <= 1, gaze2d_y >= 0,
                  gaze2d_y <= 1)
  if (type == "points") {
    p <- ggplot2::ggplot(d, ggplot2::aes(x = .data$gaze2d_x, y = .data$gaze2d_y)) +
      ggplot2::geom_point(ggplot2::aes(colour = .data$time), size = 0.9, alpha = 0.7,
                          shape = 16) +
      ggplot2::scale_colour_gradient(low = g3_ramp[["light"]], high = g3_ramp[["dark"]],
                                     name = "Time (s)")
  } else {
    p <- d |>
      gaze_bins(bins) |>
      ggplot2::ggplot(ggplot2::aes(x = .data$x, y = .data$y, fill = .data$samples)) +
      ggplot2::geom_tile(ggplot2::aes(width = .data$width, height = .data$height),
                         colour = "white", linewidth = 0.15) +
      ggplot2::scale_fill_gradient(low = g3_ramp[["light"]], high = g3_ramp[["dark"]],
                                   name = "Samples")
  }
  breaks <- c(0.25, 0.5, 0.75)
  p <- p +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = breaks, expand = c(0, 0)) +
    ggplot2::scale_y_reverse(limits = c(1, 0), breaks = breaks, expand = c(0, 0)) +
    ggplot2::coord_fixed(ratio = 9 / 16) +
    ggplot2::labs(x = "Horizontal position (scene)", y = "Vertical position (scene)") +
    theme_g3() +
    ggplot2::theme(
      panel.border = ggplot2::element_rect(colour = g3_ink[["frame"]], fill = NA,
                                           linewidth = 0.5),
      legend.key.width = ggplot2::unit(1.6, "cm"),
      legend.key.height = ggplot2::unit(0.25, "cm")
    )
  facet_recordings(p, d)
}

gaze_bins <- function(d, bins) {
  nx <- max(1L, as.integer(bins))
  ny <- max(1L, as.integer(round(nx * 9 / 16)))
  if (!"recording" %in% names(d)) {
    d <- d |> dplyr::mutate(recording = "")
  }
  d |>
    dplyr::mutate(
      ix = pmin(floor(gaze2d_x * nx), nx - 1L),
      iy = pmin(floor(gaze2d_y * ny), ny - 1L)
    ) |>
    dplyr::count(recording, ix, iy, name = "samples") |>
    dplyr::mutate(x = (ix + 0.5) / nx, y = (iy + 0.5) / ny, width = 1 / nx, height = 1 / ny) |>
    dplyr::select(recording, x, y, width, height, samples)
}

g3_eye_colours <- c(left = "#2A568C", right = "#EE6363")

g3_eye_means <- c(left = "#1D4371", right = "#CD5555")

g3_ink <- c(primary = "#1f1f1d", secondary = "#52514e", grid = "#ebeae6",
            pulse = "#e0dfda", frame = "#8a8984")

g3_ramp <- c(light = "#C6D9F2", dark = "#13335A")

scale_colour_eyes <- function(...) {
  ggplot2::scale_colour_manual(values = g3_eye_colours,
                               labels = c(left = "Left", right = "Right"),
                               name = "Eye", ...)
}

#' Theme for glasses3 plots
#'
#' The ggplot2 theme used by all plots in the package, for giving your own
#' plots the same look. It builds on [ggplot2::theme_minimal()] with light
#' grey gridlines, grey axis text, the legend at the top left and bold
#' left-aligned panel titles on a white background.
#'
#' In the package plots, the left eye is drawn in slate blue (`#2A568C`) and
#' the right eye in Indian red (`#EE6363`, R's `indianred2`). The pair passes
#' checks for lightness, chroma, contrast against white and separation under
#' simulated protanopia, deuteranopia and tritanopia. Means use darker steps
#' of the same hues (`#1D4371` and `indianred3`).
#'
#' @param base_size Base font size in points.
#'
#' @return A ggplot2 theme.
#'
#' @examples
#' library(ggplot2)
#' gaze <- read_g3_gaze(g3_example())
#' ggplot(gaze, aes(time, left_pupil)) +
#'   geom_line(colour = "#2A568C", na.rm = TRUE) +
#'   theme_g3()
#' @export
theme_g3 <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      text = ggplot2::element_text(colour = g3_ink[["primary"]]),
      axis.text = ggplot2::element_text(colour = g3_ink[["secondary"]]),
      axis.title = ggplot2::element_text(colour = g3_ink[["secondary"]]),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = g3_ink[["grid"]], linewidth = 0.3),
      panel.spacing = ggplot2::unit(1, "lines"),
      legend.position = "top",
      legend.justification = "left",
      legend.title = ggplot2::element_text(colour = g3_ink[["secondary"]]),
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      strip.text = ggplot2::element_text(colour = g3_ink[["primary"]], face = "bold",
                                         hjust = 0),
      plot.caption = ggplot2::element_text(colour = g3_ink[["secondary"]], hjust = 0,
                                           size = ggplot2::rel(0.85)),
      plot.caption.position = "plot",
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin = ggplot2::margin(6, 14, 6, 6)
    )
}

#' @rdname plot_g3_pupil
#' @param ... Passed to [plot_g3_pupil()].
#' @export
plot.g3_recording <- function(x, ...) {
  plot_g3_pupil(x, ...) |> print()
  invisible(x)
}
