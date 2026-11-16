test_that("plots are ggplot objects", {
  rec <- read_g3(g3_example())
  expect_s3_class(plot_g3_pupil(rec), "ggplot")
  expect_s3_class(plot_g3_pupil(rec$gaze, eyes = "left", from = 5, to = 10), "ggplot")
  expect_s3_class(plot_g3_gaze(rec), "ggplot")
  expect_s3_class(plot_g3_gaze(rec, type = "density"), "ggplot")
})

test_that("print and summary work", {
  rec <- read_g3(g3_example())
  expect_output(print(rec), "Glasses 3")
  expect_output(print(summary(rec)), "50 Hz")
})

test_that("epochs are plotted against time from the pulse onset", {
  rec <- read_g3(g3_example())
  ep <- g3_epochs(rec$gaze, rec$events, before = 0.2, after = 1)
  p <- plot_g3_pupil(ep)
  expect_s3_class(p, "ggplot")
  expect_match(deparse(p$mapping$x), "epoch_time")
  expect_s3_class(plot_g3_pupil(ep, eyes = "left"), "ggplot")
})

test_that("gaze density bins are square in the video", {
  rec <- read_g3(g3_example())
  b <- glasses3:::gaze_bins(rec$gaze[rec$gaze$valid, ], 32)
  expect_equal(unique(b$width) * 1920, unique(b$height) * 1080)
  expect_equal(sum(b$samples), sum(rec$gaze$valid & rec$gaze$gaze2d_x >= 0 &
    rec$gaze$gaze2d_x <= 1 & rec$gaze$gaze2d_y >= 0 & rec$gaze$gaze2d_y <= 1))
})

test_that("an open pulse is shaded to the end of its own recording", {
  set.seed(5)
  root <- withr_tempdir()
  short <- synthetic_recording(rate = 50, duration = 4)
  long <- synthetic_recording(rate = 50, duration = 10)
  con <- gzfile(file.path(short, "eventdata.gz"), "w")
  writeLines('{"type":"syncport","timestamp":3.000000,"data":{"direction":"out","value":1}}', con)
  close(con)
  file.rename(short, file.path(root, "short"))
  file.rename(long, file.path(root, "long"))
  recs <- list_g3_recordings(root)
  gaze <- read_g3_gaze(recs)
  p <- plot_g3_pupil(gaze, read_g3_events(recs))
  rects <- ggplot2::layer_data(p, 1)
  end_short <- max(gaze$time[gaze$recording == "short"])
  expect_equal(max(rects$xmax[rects$xmin == 3]), end_short)
})

test_that("running median ignores short dips and keeps long gaps", {
  time <- seq(0, 10, by = 0.02)
  y <- rep(5, length(time))
  y[100:104] <- 2
  y[300:360] <- NA
  s <- glasses3:::running_median(time, y, 1)
  expect_equal(s[100:104], rep(5, 5))
  expect_true(all(is.na(s[320:340])))
  expect_equal(s[1], 5)
})

test_that("plot_g3_pupil draws a smoothed line", {
  rec <- read_g3(g3_example())
  p <- plot_g3_pupil(rec, smooth = 1)
  expect_s3_class(p, "ggplot")
  expect_equal(sum(vapply(p$layers, function(l) inherits(l$geom, "GeomLine"), logical(1))), 2)
  ep <- g3_epochs(rec$gaze, rec$events, before = 0.2, after = 1)
  expect_s3_class(plot_g3_pupil(ep, smooth = 0.2), "ggplot")
  expect_error(plot_g3_pupil(rec, smooth = 0), "positive")
  expect_error(plot_g3_pupil(rec, smooth = c(1, 2)), "positive")
})

test_that("time windows are validated", {
  rec <- read_g3(g3_example())
  expect_error(plot_g3_pupil(rec, from = 10, to = 5), "before `to`")
  expect_error(plot_g3_gaze(rec, from = "a"), "single numbers")
  ep <- g3_epochs(rec$gaze, rec$events, before = 0.2, after = 1)
  expect_error(plot_g3_pupil(ep, from = 1, to = 0), "before `to`")
})
