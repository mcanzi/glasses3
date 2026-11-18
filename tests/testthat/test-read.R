test_that("read_g3 reads all streams of the example recording", {
  rec <- read_g3(g3_example())
  expect_s3_class(rec, "g3_recording")
  expect_equal(nrow(rec$gaze), rec$info$gaze_samples)
  expect_equal(sum(rec$gaze$valid), rec$info$gaze_valid_samples)
  expect_false(is.unsorted(rec$gaze$time))
  expect_true(all(c("accel_x", "gyro_z", "mag_y") %in% names(rec$imu)))
  expect_true(all(rec$events$type == "syncport"))
})

test_that("read_g3 can skip streams", {
  rec <- read_g3(g3_example(), data = "gaze")
  expect_null(rec$imu)
  expect_null(rec$events)
})

test_that("invalid samples are kept as NA", {
  gaze <- read_g3_gaze(g3_example())
  invalid <- gaze[!gaze$valid, ]
  expect_gt(nrow(invalid), 0)
  expect_true(all(is.na(invalid$gaze2d_x)))
  one_eye <- gaze[gaze$valid_left & !gaze$valid_right, ]
  expect_true(all(!is.na(one_eye$left_pupil)))
  expect_true(all(is.na(one_eye$right_pupil)))
})

test_that("pupil values are plausible", {
  gaze <- read_g3_gaze(g3_example())
  expect_true(all(gaze$left_pupil > 1 & gaze$left_pupil < 10, na.rm = TRUE))
})

test_that("files can be read directly", {
  f <- file.path(g3_example(), "gazedata.gz")
  expect_equal(read_g3_gaze(f), read_g3_gaze(g3_example()))
})

test_that("info is parsed", {
  info <- read_g3_info(g3_example())
  expect_s3_class(info, "g3_info")
  expect_s3_class(info$created, "POSIXct")
  expect_equal(info$participant, "example")
  expect_match(info$firmware, "^1\\.")
})

test_that("missing folders give clear errors", {
  expect_error(read_g3(tempfile()), "not found")
  expect_error(read_g3_info(tempdir()), "recording.g3")
})

test_that("list_g3_recordings finds the example", {
  recs <- list_g3_recordings(dirname(g3_example()))
  expect_equal(nrow(recs), 1)
  expect_equal(normalizePath(recs$path), normalizePath(g3_example()))
})

test_that("empty and partial lines are handled", {
  dir <- withr_tempdir()
  writeLines(c(
    '{"type":"gaze","timestamp":0.02,"data":{}}',
    '{"type":"gaze","timestamp":0.04,"data":{"eyeleft":{"pupildiameter":4.2},"eyeright":{}}}',
    ''
  ), gz <- gzfile(file.path(dir, "gazedata.gz"), "w"))
  close(gz)
  gaze <- read_g3_gaze(file.path(dir, "gazedata.gz"))
  expect_equal(nrow(gaze), 2)
  expect_equal(gaze$left_pupil, c(NA, 4.2))
  expect_equal(gaze$valid_left, c(FALSE, TRUE))
  expect_true(all(is.na(gaze$right_pupil)))
})

test_that("a cut-off file returns the intact samples with a warning", {
  dir <- withr_tempdir()
  src <- readLines(gzfile(file.path(g3_example(), "gazedata.gz")))
  partial <- c(src[1:100], substr(src[101], 1, 60))
  con <- gzfile(file.path(dir, "gazedata.gz"), "w")
  writeLines(partial, con, sep = "\n")
  close(con)
  expect_warning(gaze <- read_g3_gaze(file.path(dir, "gazedata.gz")), "skipped 1 damaged line")
  expect_equal(nrow(gaze), 100)
  expect_equal(gaze[-1], read_g3_gaze(g3_example())[1:100, -1], ignore_attr = TRUE)
})

test_that("damaged lines in the middle are skipped", {
  dir <- withr_tempdir()
  src <- readLines(gzfile(file.path(g3_example(), "imudata.gz")))
  src[c(10, 20)] <- "{\"type\":\"imu\",\"timestamp\":"
  con <- gzfile(file.path(dir, "imudata.gz"), "w")
  writeLines(src, con)
  close(con)
  expect_warning(imu <- read_g3_imu(file.path(dir, "imudata.gz")), "skipped 2 damaged lines")
  expect_equal(nrow(imu), length(src) - 2)
})

test_that("a truncated gzip stream is read up to the cut", {
  dir <- withr_tempdir()
  raw <- readBin(file.path(g3_example(), "gazedata.gz"), "raw", 1e7)
  writeBin(raw[seq_len(length(raw) %/% 2)], file.path(dir, "gazedata.gz"))
  gaze <- suppressWarnings(read_g3_gaze(file.path(dir, "gazedata.gz")))
  expect_gt(nrow(gaze), 0)
  expect_lt(nrow(gaze), read_g3_info(g3_example())$gaze_samples)
})

test_that("missing streams and folders give clear errors", {
  rec <- read_g3(g3_example(), data = "imu")
  expect_error(summary(rec), "without gaze data")
  expect_error(plot_g3_pupil(rec), "without gaze data")
  expect_error(list_g3_recordings(tempfile()), "Folder not found")
})

test_that("lines that are not JSON objects are ignored", {
  dir <- withr_tempdir()
  con <- gzfile(file.path(dir, "gazedata.gz"), "w")
  writeLines(c("1", "[2]", '{"type":"gaze","timestamp":1,"data":{}}'), con)
  close(con)
  expect_equal(nrow(read_g3_gaze(file.path(dir, "gazedata.gz"))), 1)
})

test_that("binary meta files are kept as raw vectors", {
  root <- withr_tempdir()
  dir <- file.path(root, "rec")
  dir.create(dir)
  file.copy(list.files(g3_example(), full.names = TRUE), dir, recursive = TRUE)
  writeBin(as.raw(c(0xff, 0xfe, 0x00, 0x41)), file.path(dir, "meta", "custom"))
  dir.create(file.path(dir, "meta", "subfolder"))
  info <- read_g3_info(dir)
  expect_type(info$meta$custom, "raw")
  expect_false("subfolder" %in% names(info$meta))
  expect_equal(info$participant, "example")
  expect_equal(nrow(list_g3_recordings(root)), 1)
})

test_that("readers use the file names in recording.g3", {
  r <- synthetic_recording(duration = 2)
  file.rename(file.path(r, "gazedata.gz"), file.path(r, "gaze_renamed.gz"))
  rec_file <- file.path(r, "recording.g3")
  writeLines(sub('"file":"gazedata.gz"', '"file":"gaze_renamed.gz"', readLines(rec_file)),
             rec_file)
  expect_equal(nrow(read_g3_gaze(r)), 200)
  expect_equal(read_g3(r)$gaze, read_g3_gaze(r))
})
