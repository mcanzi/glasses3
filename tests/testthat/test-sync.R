test_that("g3_syncport pairs onsets and offsets", {
  ev <- fake_events(c(1, 2, 5, 6.5, 9), c(1, 0, 1, 0, 1))
  p <- g3_syncport(ev)
  expect_equal(p$onset, c(1, 5, 9))
  expect_equal(p$offset, c(2, 6.5, NA))
  expect_equal(p$duration, c(1, 1.5, NA))
})

test_that("g3_syncport ignores repeated values and other directions", {
  ev <- rbind(
    fake_events(c(1, 1.5, 2), c(1, 1, 0)),
    fake_events(3, 1, direction = "in")
  )
  expect_equal(nrow(g3_syncport(ev)), 1)
  expect_equal(nrow(g3_syncport(ev, "in")), 1)
})

test_that("g3_add_syncport labels samples", {
  ev <- fake_events(c(1, 2, 5, 6), c(1, 0, 1, 0))
  x <- data.frame(time = c(0.5, 1, 1.5, 2, 3, 5.5, 7))
  out <- g3_add_syncport(x, ev)
  expect_equal(out$syncport, c(0, 1, 1, 0, 0, 1, 0))
  expect_equal(out$pulse, c(NA, 1, 1, 1, 1, 2, 2))
  expect_equal(out$pulse_time, c(NA, 0, 0.5, 1, 2, 0.5, 2))
})

test_that("g3_epochs cuts windows around onsets", {
  ev <- fake_events(c(1, 2, 5, 6), c(1, 0, 1, 0))
  x <- data.frame(time = seq(0, 8, by = 0.5))
  ep <- g3_epochs(x, ev, before = 0.5, after = 1)
  expect_equal(as.vector(table(ep$pulse)), c(4, 4))
  expect_equal(ep$epoch_time[ep$pulse == 2], c(-0.5, 0, 0.5, 1))
  expect_equal(nrow(g3_epochs(x, ev, pulses = 2, after = 0)), 1)
  expect_error(g3_epochs(x, ev, before = -1), "non-negative")
})

test_that("example recording has sync pulses", {
  rec <- read_g3(g3_example())
  p <- g3_syncport(rec$events)
  expect_gt(nrow(p), 0)
  gaze <- g3_add_syncport(rec$gaze, rec$events)
  expect_true(all(gaze$syncport %in% c(0L, 1L)))
})

test_that("g3_pupil_long reshapes", {
  gaze <- read_g3_gaze(g3_example())
  long <- g3_pupil_long(gaze)
  expect_equal(nrow(long), 2 * nrow(gaze))
  expect_setequal(unique(long$eye), c("left", "right"))
  expect_false(any(grepl("^left_|^right_", names(long))))
})

test_that("events from several recordings need a recording column in x", {
  root <- two_recordings()
  ev <- read_g3_events(list_g3_recordings(root))
  x <- data.frame(time = seq(0, 5, by = 0.02))
  expect_error(g3_add_syncport(x, ev), "several recordings")
  expect_error(g3_epochs(x, ev), "several recordings")
  gaze <- read_g3_gaze(g3_example())
  gaze$recording <- "other"
  expect_warning(g3_epochs(gaze, ev), "No events for recording")
})

test_that("epoch windows are validated", {
  rec <- read_g3(g3_example())
  expect_error(g3_epochs(rec$gaze, rec$events, before = NA), "non-negative")
  expect_error(g3_epochs(rec$gaze, rec$events, after = c(1, 2)), "non-negative")
})
