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
    fake_events(3, 1, direction = "out")
  )
  expect_equal(nrow(g3_syncport(ev)), 1)
  expect_equal(nrow(g3_syncport(ev, "out")), 1)
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
  expect_equal(as.vector(table(ep$epoch)), c(4, 4))
  expect_equal(ep$epoch_time[ep$epoch == 2], c(-0.5, 0, 0.5, 1))
  expect_equal(nrow(g3_epochs(x, ev, pulses = 2, after = 0)), 1)
  expect_error(g3_epochs(x, ev, before = -1), "non-negative")
})

test_that("example recording has sync pulses", {
  rec <- read_g3(g3_example())
  p <- g3_syncport(rec$events, "out")
  expect_gt(nrow(p), 0)
  gaze <- g3_add_syncport(rec$gaze, rec$events, "out")
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

test_that("sync port events without a value are ignored", {
  ev <- fake_events(c(1, 2, 3, 4), c(1, NA, 1, 0))
  p <- g3_syncport(ev)
  expect_equal(p$onset, 1)
  expect_equal(p$offset, 4)
})

test_that("the default direction is in", {
  ev <- rbind(fake_events(c(1, 2), c(1, 0), direction = "out"), fake_events(c(5, 6), c(1, 0)))
  expect_equal(g3_syncport(ev)$onset, 5)
  expect_equal(g3_syncport(ev, "out")$onset, 1)
})

test_that("g3_epochs cuts at the onsets of a table", {
  x <- data.frame(time = seq(0, 8, by = 0.5), participant = "P01")
  onsets <- data.frame(onset = c(6, 2, NA), condition = c("b", "a", "c"))
  ep <- g3_epochs(x, onsets, before = 0.5, after = 1)
  expect_equal(as.vector(table(ep$epoch)), c(4, 4))
  expect_equal(ep$condition[ep$epoch == 1], rep("a", 4))
  expect_equal(ep$epoch_time[ep$epoch == 2], c(-0.5, 0, 0.5, 1))
  expect_false("onset" %in% names(ep))
  expect_equal(unique(ep$participant), "P01")
  expect_error(g3_epochs(x, onsets, pulses = 1), "Filter the table")
  expect_error(g3_epochs(x, data.frame(onset = "a")), "numeric")
})

test_that("g3_epochs matches a table of onsets to each recording", {
  recs <- list_g3_recordings(two_recordings())
  gaze <- read_g3_gaze(recs)
  onsets <- data.frame(recording = c("rec_a", "rec_b", "rec_b"), onset = c(5, 5, 10),
                       condition = c("x", "y", "z"))
  ep <- g3_epochs(gaze, onsets, after = 1)
  expect_equal(dplyr::n_distinct(ep$epoch[ep$recording == "rec_b"]), 2)
  expect_equal(unique(ep$condition[ep$recording == "rec_a"]), "x")
  expect_error(g3_epochs(data.frame(time = 1:10), onsets), "several recordings")
  shared <- g3_epochs(gaze, data.frame(onset = 5, time = 99), after = 1)
  expect_equal(dplyr::n_distinct(shared$recording), 2)
  expect_false(any(shared$time == 99))
})

test_that("columns from the onsets replace columns of x", {
  rec <- read_g3(g3_example())
  tagged <- g3_add_syncport(rec$gaze, rec$events, "out")
  ep <- g3_epochs(tagged, rec$events, before = 0.5, after = 1, direction = "out")
  expect_equal(sum(names(ep) == "pulse"), 1)
  expect_true(all(ep$pulse == ep$epoch))
  again <- g3_epochs(ep, data.frame(onset = 5), after = 1)
  expect_equal(sum(names(again) == "epoch"), 1)
})

test_that("g3_api_events reads tags and objects", {
  ev <- tibble::tibble(
    recording = "r",
    time = c(2, 1, 3),
    type = c("event", "event", "syncport"),
    direction = c(NA, NA, "in"),
    value = c(NA, NA, 1),
    data = c('{"tag":"stim","object":{"id":3,"name":"cat"}}', '{"tag":"start"}',
             '{"direction":"in","value":1}')
  )
  api <- g3_api_events(ev)
  expect_equal(names(api), c("recording", "onset", "tag", "object"))
  expect_equal(api$tag, c("stim", "start"))
  expect_equal(api$object, c('{"id":3,"name":"cat"}', NA))
  expect_equal(nrow(g3_api_events(read_g3_events(g3_example()))), 0)
  ep <- g3_epochs(data.frame(recording = "r", time = seq(0, 4, by = 0.5)), api, after = 0.5)
  expect_equal(unique(ep$tag), c("start", "stim"))
})

test_that("by_recording keeps the order in which recordings appear", {
  x <- data.frame(recording = c("b", "b", "a", NA), time = 1:4)
  out <- glasses3:::by_recording(x, function(xi, id) xi)
  expect_equal(out$recording, c("b", "b", "a", NA))
})
