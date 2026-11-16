test_that("g3_fill_gaps restores dropped samples", {
  time <- (0:199) / 100 + 0.002
  x <- data.frame(time = time, left_pupil = 4, right_pupil = 4, valid = TRUE,
                  valid_left = TRUE, valid_right = TRUE)
  dropped <- x[-c(20, 50:52, 150), ]
  filled <- g3_fill_gaps(dropped)
  expect_equal(nrow(filled), 200)
  expect_equal(sum(filled$inserted), 5)
  expect_equal(filled$time, time, tolerance = 1e-9)
  expect_true(all(is.na(filled$left_pupil[filled$inserted])))
  expect_false(any(filled$valid[filled$inserted]))
  expect_equal(nrow(g3_fill_gaps(x)), 200)
  expect_equal(g3_fill_gaps(dropped, rate = 100), filled)
  expect_error(g3_fill_gaps(x, rate = -1), "positive")
})

test_that("g3_fill_gaps works per recording and on real data", {
  set.seed(3)
  root <- withr_tempdir()
  for (rate in c(50, 100)) {
    file.rename(synthetic_recording(rate = rate), file.path(root, paste0("rec_", rate)))
  }
  gaze <- read_g3_gaze(list_g3_recordings(root))
  gaze <- gaze[-c(10, 11, 700), ]
  filled <- g3_fill_gaps(gaze)
  expect_equal(as.vector(table(filled$recording)[c("rec_50", "rec_100")]), c(500, 1000))
  expect_false(anyNA(filled$recording))
  ex <- g3_fill_gaps(read_g3_gaze(g3_example()))
  expect_lt(max(diff(ex$time)), 1.5 / 50)
})

test_that("g3_gaze_angles converts directions", {
  a <- 30 * pi / 180
  e <- 10 * pi / 180
  v <- 0.05
  gaze <- data.frame(
    left_direction_x = c(0, -sin(a), 0, v, NA),
    left_direction_y = c(0, 0, sin(e), 0, NA),
    left_direction_z = c(1, cos(a), cos(e), 1, NA),
    right_direction_x = c(0, -sin(a), 0, -v, 0),
    right_direction_y = c(0, 0, sin(e), 0, 0),
    right_direction_z = c(1, cos(a), cos(e), 1, 1)
  )
  out <- g3_gaze_angles(gaze)
  expect_equal(out$left_azimuth, c(0, 30, 0, -atan(v) * 180 / pi, NA))
  expect_equal(out$left_elevation, c(0, 0, 10, 0, NA))
  expect_equal(out$vergence, c(0, 0, 0, 2 * atan(v) * 180 / pi, NA))
  ex <- g3_gaze_angles(read_g3_gaze(g3_example()))
  expect_true(all(abs(ex$left_azimuth) < 60, na.rm = TRUE))
  expect_true(all(ex$vergence >= 0, na.rm = TRUE))
})

test_that("g3_downsample averages within bins", {
  x <- data.frame(time = seq(0.002, 0.998, by = 0.02), left_pupil = rep(c(4, 6), 25),
                  valid = rep(c(TRUE, FALSE), 25))
  out <- g3_downsample(x, bin = 0.1)
  expect_equal(nrow(out), 10)
  expect_equal(out$time, seq(0, 0.9, by = 0.1))
  expect_equal(out$samples, rep(5L, 10))
  expect_equal(out$valid, c(0.6, 0.4, 0.6, 0.4, 0.6, 0.4, 0.6, 0.4, 0.6, 0.4))
  x$left_pupil[1:3] <- NA
  out <- g3_downsample(x, bin = 0.1)
  expect_true(is.na(out$left_pupil[1]))
  expect_equal(g3_downsample(x, bin = 0.1, min_valid = 0)$left_pupil[1], 5)
  expect_error(g3_downsample(x, bin = 0), "positive")
  expect_error(g3_downsample(x, min_valid = 2), "between 0 and 1")
})

test_that("g3_downsample keeps recordings, pulses and eyes apart", {
  rec <- read_g3(g3_example())
  ep <- g3_epochs(rec$gaze, rec$events, before = 0.5, after = 2)
  long <- g3_downsample(g3_pupil_long(ep), bin = 0.1)
  per_epoch <- table(long$pulse, long$eye)
  expect_true(all(per_epoch <= 25))
  expect_equal(long$epoch_time / 0.1, round(long$epoch_time / 0.1), tolerance = 1e-9)
  expect_true(any(abs(long$epoch_time) < 1e-9))
  expect_setequal(unique(long$eye), c("left", "right"))
  root <- two_recordings()
  gaze <- read_g3_gaze(list_g3_recordings(root))
  ds <- g3_downsample(gaze, bin = 1)
  expect_equal(as.vector(table(ds$recording)), c(30, 30))
})

test_that("g3_fill_gaps copies added columns that are constant within a recording", {
  x <- data.frame(recording = rep(c("a", "b"), each = 100), time = (0:199) / 100 + 0.002,
                  left_pupil = 4, valid = TRUE,
                  participant = rep(c("P01", "P02"), each = 100),
                  session = factor(rep(c("s1", "s2"), each = 100)),
                  block = rep(1:4, each = 50))
  filled <- g3_fill_gaps(x[-c(20, 21, 150), ])
  new <- filled[filled$inserted, ]
  expect_equal(nrow(filled), 200)
  expect_equal(new$recording, c("a", "a", "b"))
  expect_equal(new$participant, c("P01", "P01", "P02"))
  expect_s3_class(filled$session, "factor")
  expect_equal(as.character(new$session), c("s1", "s1", "s2"))
  expect_true(all(is.na(new$block)))
  expect_true(all(is.na(new$left_pupil)))
  expect_false(any(new$valid))
})

test_that("g3_fill_gaps refuses IMU data", {
  expect_error(g3_fill_gaps(read_g3_imu(g3_example())), "gaze data")
})

test_that("g3_downsample keeps the columns named in by", {
  x <- data.frame(time = seq(0.002, 0.998, by = 0.02), left_pupil = rep(c(4, 6), 25))
  x <- rbind(cbind(x, condition = "a", trial = 1), cbind(x, condition = "b", trial = 2))
  out <- g3_downsample(x, bin = 0.1, by = c("condition", "trial"))
  expect_equal(nrow(out), 20)
  expect_equal(names(out)[1:4], c("condition", "trial", "time", "samples"))
  expect_equal(out$condition, rep(c("a", "b"), each = 10))
  expect_equal(out$trial, rep(c(1, 2), each = 10))
  expect_equal(out$samples, rep(5L, 20))
  plain <- g3_downsample(x, bin = 0.1)
  expect_equal(nrow(plain), 10)
  expect_false("condition" %in% names(plain))
  expect_error(g3_downsample(x, by = "participant"), "participant")
  expect_error(g3_downsample(x, by = "time"), "time column")
  expect_error(g3_downsample(x, by = 1), "character")
})
