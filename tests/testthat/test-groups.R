test_that("grouped tibbles keep their groups", {
  recs <- list_g3_recordings(two_recordings())
  gaze <- dplyr::group_by(read_g3_gaze(recs), recording)
  events <- read_g3_events(recs)
  expect_equal(dplyr::group_vars(g3_fill_gaps(gaze)), "recording")
  expect_equal(dplyr::group_vars(g3_gaze_angles(gaze)), "recording")
  expect_equal(dplyr::group_vars(g3_add_syncport(gaze, events, "out")), "recording")
  ep <- g3_epochs(gaze, events, before = 0.5, after = 2, direction = "out")
  expect_equal(dplyr::group_vars(ep), "recording")
  long <- g3_pupil_long(ep)
  expect_equal(dplyr::group_vars(long), "recording")
  expect_equal(dplyr::group_vars(g3_downsample(long, bin = 0.1)), "recording")
  pulses <- g3_syncport(dplyr::group_by(events, recording), "out")
  expect_equal(dplyr::group_vars(pulses), "recording")
  expect_equal(dplyr::ungroup(pulses), g3_syncport(events, "out"))
  expect_false(inherits(g3_fill_gaps(dplyr::ungroup(gaze)), "grouped_df"))
  expect_false(inherits(g3_gaze_angles(dplyr::ungroup(gaze)), "grouped_df"))
})

test_that("groups that lose their column are dropped", {
  gaze <- dplyr::group_by(read_g3_gaze(g3_example()), valid_left)
  long <- g3_pupil_long(gaze)
  expect_false(inherits(long, "grouped_df"))
  expect_s3_class(long, "tbl_df")
})

test_that("g3_downsample bins within dplyr groups", {
  x <- data.frame(time = rep(seq(0.002, 0.998, by = 0.02), 2),
                  left_pupil = rep(c(4, 6), each = 50),
                  condition = rep(c("a", "b"), each = 50))
  grouped <- g3_downsample(dplyr::group_by(x, condition), bin = 0.1)
  expect_equal(dplyr::group_vars(grouped), "condition")
  expect_equal(nrow(grouped), 20)
  expect_equal(grouped$left_pupil, rep(c(4, 6), each = 10))
  expect_equal(dplyr::ungroup(grouped), g3_downsample(x, bin = 0.1, by = "condition"))
})

test_that("grouped data plot like ungrouped data", {
  recs <- list_g3_recordings(two_recordings())
  gaze <- dplyr::group_by(read_g3_gaze(recs), recording)
  events <- dplyr::group_by(read_g3_events(recs), recording)
  expect_s3_class(plot_g3_pupil(gaze, events), "ggplot")
  expect_s3_class(plot_g3_pupil(gaze, smooth = 1), "ggplot")
  expect_s3_class(plot_g3_gaze(gaze), "ggplot")
  ep <- g3_epochs(gaze, events, before = 0.2, after = 1, direction = "out")
  expect_s3_class(plot_g3_pupil(ep), "ggplot")
})

test_that("rows from g3_fill_gaps stay in their group", {
  gaze <- read_g3_gaze(g3_example())
  gaze$participant <- "P01"
  filled <- g3_fill_gaps(dplyr::group_by(gaze[-(100:109), ], participant))
  expect_gte(sum(filled$inserted), 10)
  expect_equal(dplyr::group_vars(filled), "participant")
  expect_equal(dplyr::n_groups(filled), 1L)
  expect_false(anyNA(filled$participant))
})
