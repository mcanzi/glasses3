# glasses3 (development version)

## New features

* `g3_quality()` summarises data quality per recording or epoch: the number
  of samples, the proportion with a gaze point and with data for each eye,
  and the longest time without a gaze point. It helps to find trials with
  too much missing data.
* `g3_add_frame()` adds the number of the scene video frame shown at each
  sample, for matching samples to codes made from the video.
  `g3_downsample()` keeps the frame of the first sample in each bin.

## Bug fixes

* `g3_fill_gaps()` no longer fails on data with duplicated rows. The sampling
  rate, also shown by `print()` and `summary()`, is now worked out from the
  intervals between distinct timestamps. An infinite `rate` gives an error.
* `plot_g3_pupil()` and `plot_g3_gaze()` no longer fail when some samples have
  no time, and `summary()` now gives the largest gap for such data.
* A byte order mark at the start of a data file or of `recording.g3` is
  ignored.
* A damaged `recording.g3` gives a clear error in `read_g3_info()` and
  `read_g3()`. `list_g3_recordings()` lists such recordings without metadata,
  with a warning, and the readers use the usual file names for them.
* A data file that is a ZIP archive gives a clear error.
* Columns of the wrong type, such as a `time` column holding text, give an
  error naming the column.
* `g3_add_clock_time()` warns about recordings without a start time instead
  of returning `NA` without a warning.
* `g3_api_events()` gives a clear error when the `data` column holds text that
  is not JSON, and is faster with many events.

# glasses3 0.2.0

## Breaking changes

* The sync port functions `g3_syncport()`, `g3_add_syncport()`, `g3_epochs()`
  and `plot_g3_pupil()` now use `direction = "in"` by default, the pulses the
  glasses receive from other equipment such as a stimulus computer. Use
  `direction = "out"` for the pulses the glasses send.
* `g3_epochs()` numbers the epochs in a new `epoch` column. Epochs cut at sync
  port pulses keep the `pulse` column with the pulse number.
  `plot_g3_pupil()`, `g3_downsample()` and `g3_gaze_velocity()` use `epoch` to
  keep epochs apart.

## New features

* `g3_epochs()` also cuts epochs at the onsets in a data frame with an `onset`
  column, such as the trial onsets of an experiment. Its other columns, such
  as a condition, are copied to the samples of each epoch. Without a
  `recording` column, every recording is cut at all onsets.
* `g3_api_events()` extracts the events sent to the glasses through their API,
  with their tag and object, ready to be passed to `g3_epochs()`.
* `g3_gaze_velocity()` adds the angular velocity of each eye in degrees per
  second.
* `g3_add_clock_time()` adds the date and time of each sample from the start
  time of the recording.
* `summary()` of a recording counts the sync port pulses in both directions.

## Bug fixes

* `g3_downsample()` no longer splits a bin in two where a sync port pulse
  starts in data from `g3_add_syncport()`. The `pulse` column now gets the
  pulse of the first sample in the bin, and `samples` is an integer again.
* A file in the `meta` folder that is not UTF-8 text, as the API can write, no
  longer stops `read_g3_info()`, `read_g3()` and `list_g3_recordings()`. Such
  files are returned as raw vectors, and folders inside `meta` are skipped.
* Sync port signal changes without a value no longer create a pulse without
  an onset.
* `read_g3_gaze()`, `read_g3_imu()` and `read_g3_events()` now take the names
  of the data files from `recording.g3`, as `read_g3()` already did.

## Other changes

* `g3_downsample()` is several times faster, and functions that work per
  recording are faster with many recordings.
* Highlighted terms in the vignette and on the website are now shown with a
  highlighter.
* The help page titles of `g3_pupil_long()` and `list_g3_recordings()` are now
  "Reshape pupil data to long format" and "List recordings".

# glasses3 0.1.0

* Initial release.
* Reads Tobii Pro Glasses 3 recording folders directly from the SD card:
  gaze and pupil data, IMU data, events and metadata. Lines that cannot be
  parsed, such as the cut-off last line of an incomplete file, are skipped
  with a warning. A file whose compressed data are damaged gives an error.
* The readers accept several recording folders, or the output of
  `list_g3_recordings()`, and add a `recording` column. Sync port, epoch and
  plotting functions work per recording.
* `g3_syncport()`, `g3_add_syncport()` and `g3_epochs()` align samples with
  sync port pulses, and `g3_pupil_long()` reshapes pupil data to one row per
  eye.
* `g3_fill_gaps()` inserts empty rows for missing samples. The `recording`
  column and columns you added that have one value per recording, such as a
  participant column, are copied into the new rows.
* `g3_gaze_angles()` adds azimuth, elevation and vergence angles.
* `g3_downsample()` averages samples into fixed time bins, for example
  before fitting generalised additive mixed models. Its `by` argument keeps
  further grouping columns, such as participant or condition.
* `plot_g3_pupil()` and `plot_g3_gaze()` share one style, available as
  `theme_g3()` for other plots. The left eye is always slate blue and the
  right eye always Indian red, a pair checked for colour vision
  deficiencies. Given epochs, `plot_g3_pupil()` plots the time from the pulse
  onset, with one line per pulse and the mean. Its `smooth` argument draws a
  running median over the raw trace.
* Data are returned as tibbles, and grouped tibbles keep their groups. The
  internals use dplyr, tidyr, purrr and stringr.
* Gaze, pupil, IMU and sync port data were checked against Tobii Pro Lab
  exports of seven 50 Hz recordings and agree up to the rounding of the
  exports. 100 Hz data are covered by synthetic test recordings.
* `citation("glasses3")` gives the reference for the package, with the version
  number from DESCRIPTION.
