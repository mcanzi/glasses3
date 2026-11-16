withr_tempdir <- function() {
  d <- tempfile("g3test")
  dir.create(d)
  d
}

fake_events <- function(times, values, direction = "out") {
  data.frame(time = times, type = "syncport", direction = direction,
             value = values, data = "{}")
}

synthetic_recording <- function(rate = 100, duration = 10, pulse_every = 1,
                                pulse_width = 0.5) {
  dir <- withr_tempdir()
  dir.create(file.path(dir, "meta"))
  n <- round(duration * rate)
  time <- (seq_len(n) - 1) / rate + 0.002 + stats::runif(n, -0.0005, 0.0005)
  missing <- seq_len(n) %% 37L == 0L
  left_only <- seq_len(n) %% 23L == 0L & !missing
  pupil_l <- 4 + 0.5 * sin(2 * pi * 0.2 * time)
  pupil_r <- pupil_l + 0.2
  eye <- function(origin, pupil) {
    sprintf('{"gazeorigin":[%s],"gazedirection":[0.01,-0.3,0.95],"pupildiameter":%.4f}',
            origin, pupil)
  }
  gaze <- ifelse(
    missing,
    sprintf('{"type":"gaze","timestamp":%.6f,"data":{}}', time),
    sprintf(paste0('{"type":"gaze","timestamp":%.6f,"data":{"gaze2d":[0.5,0.5],',
                   '"gaze3d":[0.0,-200.0,600.0],"eyeleft":%s,"eyeright":%s}}'),
            time,
            eye("32.1,-12.8,-31.7", pupil_l),
            ifelse(left_only, "{}", eye("-28.9,-11.5,-29.9", pupil_r)))
  )
  imu_time <- seq(0.005, duration, by = 0.01)
  imu <- sprintf(paste0('{"type":"imu","timestamp":%.6f,"data":{"accelerometer":',
                        '[0.1,-9.8,0.5],"gyroscope":[1.0,2.0,3.0]}}'), imu_time)
  onsets <- seq(0.5, duration - pulse_width, by = pulse_every)
  ev_time <- sort(c(onsets, onsets + pulse_width))
  ev_value <- rep(c(1, 0), length(onsets))
  events <- sprintf('{"type":"syncport","timestamp":%.6f,"data":{"direction":"out","value":%d}}',
                    ev_time, as.integer(ev_value))
  write_gz <- function(lines, file) {
    con <- gzfile(file.path(dir, file), "w")
    writeLines(lines, con)
    close(con)
  }
  write_gz(gaze, "gazedata.gz")
  write_gz(imu, "imudata.gz")
  write_gz(events, "eventdata.gz")
  writeLines(sprintf(paste0(
    '{"uuid":"00000000-0000-4000-8000-000000000001","name":"Synthetic %d Hz",',
    '"meta-folder":"meta","version":2,"duration":%.1f,',
    '"created":"2025-01-01T12:00:00Z","timezone":"UTC",',
    '"gaze":{"file":"gazedata.gz","samples":%d,"valid-samples":%d},',
    '"events":{"file":"eventdata.gz"},"imu":{"file":"imudata.gz"}}'),
    as.integer(rate), duration, n, sum(!missing)), file.path(dir, "recording.g3"))
  writeLines('{"name":"synthetic"}', file.path(dir, "meta", "participant"))
  writeLines("1.0.0", file.path(dir, "meta", "RuVersion"))
  dir
}

two_recordings <- function() {
  root <- withr_tempdir()
  for (id in c("rec_a", "rec_b")) {
    dir.create(file.path(root, id))
    file.copy(list.files(g3_example(), full.names = TRUE), file.path(root, id),
              recursive = TRUE)
  }
  root
}
