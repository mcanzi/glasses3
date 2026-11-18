test_that("NA in the recording column is kept as its own recording", {
  recs <- list_g3_recordings(two_recordings())
  gaze <- read_g3_gaze(recs)
  events <- read_g3_events(recs)
  gaze$recording[gaze$recording == "rec_b"] <- NA
  events$recording[events$recording == "rec_b"] <- NA
  one_gaze <- read_g3_gaze(g3_example())
  one_events <- read_g3_events(g3_example())
  filled <- g3_fill_gaps(gaze)
  expect_equal(sum(!filled$inserted), nrow(gaze))
  expect_equal(sum(is.na(filled$recording)), sum(filled$recording %in% "rec_a"))
  p <- g3_syncport(events, "out")
  expect_equal(nrow(p), 2 * nrow(g3_syncport(one_events, "out")))
  expect_equal(sum(is.na(p$recording)), nrow(p) / 2)
  tagged <- g3_add_syncport(gaze, events, "out")
  expect_equal(nrow(tagged), nrow(gaze))
  expect_equal(tagged$pulse[is.na(tagged$recording)], tagged$pulse[tagged$recording %in% "rec_a"])
  ep <- g3_epochs(gaze, events, after = 1, direction = "out")
  expect_equal(nrow(ep), 2 * nrow(g3_epochs(one_gaze, one_events, after = 1, direction = "out")))
})

test_that("g3_epochs keeps the samples within the window of each pulse", {
  rec <- read_g3(g3_example())
  ep <- g3_epochs(rec$gaze, rec$events, before = 0.5, after = 2, direction = "out")
  p <- g3_syncport(rec$events, "out")
  manual <- vapply(p$onset, function(o) {
    sum(rec$gaze$time >= o - 0.5 & rec$gaze$time <= o + 2)
  }, integer(1))
  expect_equal(as.vector(table(factor(ep$pulse, levels = p$pulse))), manual)
  expect_true(all(ep$epoch_time >= -0.5 - 1e-9 & ep$epoch_time <= 2 + 1e-9))
  shuffled <- rec$gaze[sample(nrow(rec$gaze)), ]
  expect_equal(g3_epochs(shuffled, rec$events, before = 0.5, after = 2, direction = "out"), ep)
  some <- g3_epochs(rec$gaze, rec$events, before = 0.5, after = 2, direction = "out",
                    pulses = c(2, 4))
  expect_equal(unique(some$pulse), c(2L, 4L))
})

test_that("functions accept data without rows", {
  gaze <- read_g3_gaze(g3_example())
  events <- read_g3_events(g3_example())
  g0 <- gaze[0, ]
  e0 <- events[0, ]
  expect_equal(nrow(g3_fill_gaps(g0)), 0)
  expect_equal(nrow(g3_fill_gaps(gaze[1, ])), 1)
  expect_equal(nrow(g3_gaze_angles(g0)), 0)
  expect_equal(nrow(g3_pupil_long(g0)), 0)
  expect_equal(nrow(g3_syncport(e0)), 0)
  expect_equal(nrow(g3_epochs(g0, events)), 0)
  ds <- g3_downsample(g0)
  expect_equal(nrow(ds), 0)
  expect_true(all(c("time", "samples", "left_pupil") %in% names(ds)))
  expect_warning(ep <- g3_epochs(gaze, e0), "No events")
  expect_equal(nrow(ep), 0)
  expect_true(all(c("epoch", "epoch_time", "pulse") %in% names(ep)))
})

test_that("missing timestamps do not break the processing functions", {
  gaze <- read_g3_gaze(g3_example())
  gaze$time[5] <- NA
  filled <- g3_fill_gaps(gaze)
  expect_equal(sum(!filled$inserted), nrow(gaze))
  expect_true(is.na(utils::tail(filled$time, 1)))
  ep <- g3_epochs(gaze, read_g3_events(g3_example()), after = 1, direction = "out")
  expect_gt(nrow(ep), 0)
  expect_false(anyNA(ep$time))
  expect_true(is.na(glasses3:::sampling_rate(1)))
})

test_that("g3_fill_gaps uses the measured rate when it is not 50 or 100 Hz", {
  x <- data.frame(time = (0:119) / 60, left_pupil = 4, valid = TRUE)
  filled <- g3_fill_gaps(x[-30, ])
  expect_equal(sum(filled$inserted), 1)
  expect_equal(nrow(filled), 120)
})

test_that("input checks give clear errors", {
  rec <- read_g3(g3_example())
  expect_error(g3_fill_gaps(data.frame(x = 1)), "data frame with columns")
  expect_error(plot_g3_pupil(rec, smooth = -1), "smooth")
  expect_error(plot_g3_pupil(rec$gaze[1, ]), "at least two samples")
  expect_error(plot_g3_gaze(rec$gaze[1, ]), "at least two samples")
  expect_error(read_g3(file.path(tempdir(), "no_such_folder")), "not found")
  expect_error(read_g3_gaze(1), "paths to recordings")
})

test_that("an empty folder lists no recordings", {
  recs <- list_g3_recordings(withr_tempdir())
  expect_equal(nrow(recs), 0)
  expect_equal(names(recs), c("recording", "path", "name", "participant", "created", "duration"))
})

test_that("empty, damaged and missing data files are handled", {
  full <- read_g3_gaze(g3_example())
  r1 <- synthetic_recording(duration = 2)
  con <- gzfile(file.path(r1, "gazedata.gz"), "w")
  close(con)
  empty <- read_g3_gaze(r1)
  expect_equal(nrow(empty), 0)
  expect_equal(names(empty), names(full))
  r2 <- synthetic_recording(duration = 2)
  con <- gzfile(file.path(r2, "gazedata.gz"), "w")
  writeLines(c("not json", "{broken"), con)
  close(con)
  expect_warning(damaged <- read_g3_gaze(r2), "skipped 2 damaged lines")
  expect_equal(nrow(damaged), 0)
  r3 <- synthetic_recording(duration = 2)
  file.remove(file.path(r3, "gazedata.gz"))
  expect_error(read_g3(r3), "File not found")
  expect_null(read_g3(r3, data = "events")$gaze)
})

test_that("events without a payload are kept", {
  r <- synthetic_recording(duration = 2)
  con <- gzfile(file.path(r, "eventdata.gz"), "w")
  writeLines(c('{"type":"syncport","timestamp":0.5,"data":{"direction":"out","value":1}}',
               '{"type":"custom","timestamp":1.0}'), con)
  close(con)
  ev <- read_g3_events(r)
  expect_equal(ev$type, c("syncport", "custom"))
  expect_equal(ev$data[2], "{}")
  expect_true(is.na(ev$value[2]))
})

test_that("plots work without a recording column and with missing data", {
  rec <- read_g3(g3_example())
  gaze <- rec$gaze
  gaze$recording <- NULL
  events <- rec$events
  events$recording <- NULL
  expect_s3_class(plot_g3_pupil(gaze, events), "ggplot")
  ep <- g3_epochs(gaze, events, before = 0.2, after = 1, direction = "out")
  expect_s3_class(plot_g3_pupil(ep), "ggplot")
  ep$left_pupil <- NA_real_
  ep$right_pupil <- NA_real_
  expect_s3_class(plot_g3_pupil(ep), "ggplot")
  off <- rec$gaze
  off$gaze2d_x <- 2
  expect_s3_class(plot_g3_gaze(off, type = "density"), "ggplot")
  grDevices::pdf(NULL)
  shown <- withVisible(plot(rec))
  grDevices::dev.off()
  expect_false(shown$visible)
  expect_identical(shown$value, rec)
})

test_that("read_g3 falls back to the default file names", {
  r <- synthetic_recording(duration = 2)
  writeLines('{"name":"Minimal","duration":2.0}', file.path(r, "recording.g3"))
  rec <- read_g3(r)
  expect_equal(nrow(rec$gaze), 200)
  expect_true(is.na(rec$info$files$gaze))
  expect_true(is.na(rec$info$gaze_samples))
})

test_that("damaged compressed data give a clear error", {
  r <- synthetic_recording(duration = 20)
  f <- file.path(r, "gazedata.gz")
  bytes <- readBin(f, "raw", file.size(f))
  mid <- seq(length(bytes) %/% 2, length.out = 40)
  bytes[mid] <- as.raw(255 - as.integer(bytes[mid]))
  writeBin(bytes, f)
  expect_error(suppressWarnings(read_g3_gaze(r)), "invalid or incomplete compressed data")
})

test_that("a data file that is not gzip is read as damaged lines", {
  r <- synthetic_recording(duration = 2)
  junk <- as.raw(c(sample(128:255, 3000, TRUE), 10, sample(128:255, 3000, TRUE), 10))
  writeBin(junk, file.path(r, "gazedata.gz"))
  expect_warning(gaze <- read_g3_gaze(r), "damaged line")
  expect_equal(nrow(gaze), 0)
})
