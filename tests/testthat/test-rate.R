for (rate in c(50, 100)) {
  set.seed(rate)
  path <- synthetic_recording(rate = rate)
  rec <- read_g3(path)
  n <- 10 * rate
  missing <- seq_len(n) %% 37L == 0L
  left_only <- seq_len(n) %% 23L == 0L & !missing

  test_that(sprintf("a %d Hz recording is read completely", rate), {
    expect_equal(nrow(rec$gaze), n)
    expect_equal(nrow(rec$gaze), rec$info$gaze_samples)
    expect_equal(sum(rec$gaze$valid), rec$info$gaze_valid_samples)
    expect_false(is.unsorted(rec$gaze$time))
    expect_equal(sum(rec$gaze$valid_left & !rec$gaze$valid_right), sum(left_only))
    expect_true(all(is.na(rec$gaze$right_pupil[left_only])))
    expect_true(all(!is.na(rec$gaze$left_pupil[left_only])))
  })

  test_that(sprintf("the sampling rate of a %d Hz recording is reported", rate), {
    s <- summary(rec)
    expect_equal(s$sampling_rate, rate, tolerance = 0.02)
    expect_lt(s$max_gap, 2.5 / rate)
    expect_output(print(rec), sprintf("%d Hz", rate))
    expect_output(print(s), sprintf("%d Hz", rate))
  })

  test_that(sprintf("epochs of a %d Hz recording have the expected length", rate), {
    ep <- g3_epochs(rec$gaze, rec$events, before = 0.2, after = 0.5)
    expect_equal(length(unique(ep$pulse)), 10)
    expect_true(all(table(ep$pulse) == 0.7 * rate))
    expect_true(all(ep$epoch_time >= -0.2 & ep$epoch_time <= 0.5))
    expect_equal(nrow(g3_pupil_long(ep)), 2 * nrow(ep))
  })

  test_that(sprintf("sync port states of a %d Hz recording are labelled", rate), {
    gaze <- g3_add_syncport(rec$gaze, rec$events)
    after_first <- gaze$time >= 0.5 & gaze$time < 9.5
    expect_equal(mean(gaze$syncport[after_first]), 0.5, tolerance = 0.02)
  })

  test_that(sprintf("a %d Hz recording can be plotted", rate), {
    expect_s3_class(plot_g3_pupil(rec), "ggplot")
    expect_s3_class(plot_g3_gaze(rec), "ggplot")
  })
}

test_that("50 Hz and 100 Hz recordings can be read together", {
  set.seed(1)
  root <- withr_tempdir()
  for (rate in c(50, 100)) {
    file.rename(synthetic_recording(rate = rate), file.path(root, paste0("rec_", rate)))
  }
  recs <- list_g3_recordings(root)
  gaze <- read_g3_gaze(recs)
  expect_equal(as.vector(table(gaze$recording)[c("rec_50", "rec_100")]), c(500, 1000))
  ev <- read_g3_events(recs)
  ep <- g3_epochs(gaze, ev, before = 0, after = 0.5)
  per_epoch <- tapply(ep$pulse, ep$recording, function(p) unique(table(p)))
  expect_equal(as.vector(per_epoch[c("rec_50", "rec_100")]), c(25, 50))
})
