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
