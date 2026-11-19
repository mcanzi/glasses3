test_that("g3_quality counts samples and valid data", {
  gaze <- read_g3_gaze(g3_example())
  q <- g3_quality(gaze)
  expect_equal(nrow(q), 1)
  expect_equal(names(q), c("recording", "samples", "duration", "valid", "valid_left",
                           "valid_right", "max_gap"))
  expect_equal(q$samples, nrow(gaze))
  expect_equal(q$valid, mean(gaze$valid))
  expect_equal(q$valid_left, mean(gaze$valid_left))
  expect_equal(q$duration, max(gaze$time) - min(gaze$time))
  valid_times <- gaze$time[gaze$valid]
  expected_gap <- c(min(gaze$time), valid_times, max(gaze$time)) |> diff() |> max()
  expect_equal(q$max_gap, expected_gap)
})

test_that("g3_quality gives the sample interval for complete data and finds gaps", {
  x <- data.frame(time = (0:499) / 50, valid = TRUE)
  expect_equal(g3_quality(x)$max_gap, 0.02)
  x$valid[101:150] <- FALSE
  expect_equal(g3_quality(x)$max_gap, 1.02)
  expect_equal(g3_quality(x[-(101:150), ])$max_gap, 1.02)
  x$valid[1:10] <- FALSE
  x$valid[491:500] <- FALSE
  q <- g3_quality(x[c(1:20, 481:500), ])
  expect_equal(q$max_gap, 9.22)
  x$valid <- FALSE
  expect_equal(g3_quality(x)$max_gap, g3_quality(x)$duration)
  expect_equal(g3_quality(x)$valid, 0)
})

test_that("g3_quality works per recording, epoch and group", {
  recs <- list_g3_recordings(two_recordings())
  gaze <- read_g3_gaze(recs)
  events <- read_g3_events(recs)
  q <- g3_quality(gaze)
  expect_equal(q$recording, c("rec_a", "rec_b"))
  expect_equal(q$samples[1], q$samples[2])
  ep <- g3_epochs(gaze, events, before = 0.5, after = 2, direction = "out")
  qe <- g3_quality(ep)
  expect_equal(nrow(qe), nrow(dplyr::distinct(ep, recording, epoch)))
  expect_equal(qe$samples, dplyr::count(ep, recording, epoch)$n)
  ep$condition <- ifelse(ep$epoch %% 2 == 0, "even", "odd")
  qc <- g3_quality(ep, by = "condition")
  expect_true("condition" %in% names(qc))
  qg <- g3_quality(dplyr::group_by(ep, condition))
  expect_equal(dplyr::group_vars(qg), "condition")
  expect_equal(nrow(qg), nrow(qc))
})

test_that("g3_quality counts inserted rows and rows without a time", {
  gaze <- read_g3_gaze(g3_example())
  filled <- g3_fill_gaps(gaze[-(100:109), ])
  q <- g3_quality(filled)
  expect_equal(q$samples, nrow(gaze))
  expect_lt(q$valid, mean(gaze$valid))
  gaze$time[1] <- NA
  q <- g3_quality(gaze)
  expect_equal(q$samples, nrow(gaze))
  expect_false(is.na(q$max_gap))
})

test_that("g3_quality handles empty data and gives clear errors", {
  gaze <- read_g3_gaze(g3_example())
  expect_equal(nrow(g3_quality(gaze[0, ])), 0)
  one <- g3_quality(data.frame(time = numeric(0), valid = logical(0)))
  expect_equal(one$samples, 0)
  expect_true(is.na(one$valid))
  expect_equal(g3_quality(gaze[1, ])$max_gap, 0)
  expect_error(g3_quality(g3_pupil_long(gaze)), "before `g3_pupil_long")
  expect_error(g3_quality(dplyr::mutate(gaze, valid = as.numeric(valid))), "must be logical")
  expect_error(g3_quality(dplyr::select(gaze, -valid)), "columns: time, valid")
  expect_error(g3_quality(gaze, by = "nope"), "not in `x`")
  expect_error(g3_quality(gaze, by = "valid_left"), "cannot include valid_left")
  expect_error(g3_quality(dplyr::group_by(gaze, valid)), "cannot include valid")
})

test_that("g3_add_frame numbers the scene video frames", {
  x <- data.frame(time = c(-0.01, 0, 0.039, 0.04, 0.08, 1, NA))
  expect_equal(g3_add_frame(x)$frame, c(NA, 0L, 0L, 1L, 2L, 25L, NA))
  expect_equal(g3_add_frame(x, start = 0.02)$frame, c(NA, NA, 0L, 0L, 1L, 24L, NA))
  expect_equal(g3_add_frame(x, fps = 30)$frame[6], 30L)
  gaze <- read_g3_gaze(g3_example())
  framed <- g3_add_frame(dplyr::group_by(gaze, recording))
  expect_equal(names(framed)[1:3], c("recording", "time", "frame"))
  expect_equal(dplyr::group_vars(framed), "recording")
  expect_equal(max(framed$frame), floor(max(gaze$time) * 25))
  expect_error(g3_add_frame(gaze, fps = 0), "fps")
  expect_error(g3_add_frame(gaze, start = NA), "start")
  expect_error(g3_add_frame(dplyr::mutate(gaze, time = as.character(time))), "numeric: time")
})

test_that("frames survive other functions", {
  rec <- read_g3(g3_example())
  gaze <- g3_add_frame(rec$gaze)
  ds <- g3_downsample(gaze, bin = 0.1)
  expect_equal(ds$frame[1:4], c(0L, 2L, 5L, 7L))
  filled <- g3_fill_gaps(gaze[-(100:109), ])
  expect_true(all(is.na(filled$frame[filled$inserted])))
  ep <- g3_epochs(gaze, rec$events, before = 0.5, after = 1, direction = "out")
  expect_true("frame" %in% names(ep))
})
