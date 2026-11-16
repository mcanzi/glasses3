# Read gaze and pupil data

Parses `gazedata.gz` into one row per sample. Samples where the glasses
detected no gaze are kept, with `NA` values, so that the time series
stays complete. Lines that cannot be parsed, such as the cut-off last
line of an incomplete file, are skipped with a warning; see
[`g3_fill_gaps()`](https://mcanzi.de/glasses3/reference/g3_fill_gaps.md)
to replace them with empty rows. A file whose compressed data are
damaged cannot be read and gives an error.

## Usage

``` r
read_g3_gaze(path)
```

## Arguments

- path:

  Path to a recording folder or directly to a `gazedata.gz` file.
  Several paths, or the output of
  [`list_g3_recordings()`](https://mcanzi.de/glasses3/reference/list_g3_recordings.md),
  read several recordings into one tibble.

## Value

A tibble with columns:

- recording:

  Name of the recording folder. If two recordings in `path` have folders
  of the same name, the full path is used instead.

- time:

  Seconds since the start of the recording.

- gaze2d_x, gaze2d_y:

  Gaze point in normalised scene camera coordinates, with (0, 0) at the
  top left of the video frame and (1, 1) at the bottom right.

- gaze3d_x, gaze3d_y, gaze3d_z:

  Point where the gaze of the two eyes meets, in millimetres from the
  scene camera.

- left_origin_x, ..., right_direction_z:

  Position of each eye in millimetres from the scene camera, and its
  gaze direction as a unit vector.

- left_pupil, right_pupil:

  Pupil diameter for each eye in millimetres, the unit given in the
  Tobii Pro Glasses 3 Developer Guide.

- valid_left, valid_right:

  Whether the glasses reported data for that eye.

- valid:

  Whether the sample has a gaze point. The glasses can estimate one from
  a single eye, so this can be `TRUE` when one eye is invalid.

See the Tobii Pro Glasses 3 Developer Guide for the coordinate systems.

The glasses record gaze at 50 or 100 Hz, in the same file format. The
rate is not stored in the recording, so functions that need it work it
out from the timestamps.

## Examples

``` r
gaze <- read_g3_gaze(g3_example())
gaze
#> # A tibble: 1,497 × 24
#>    recording   time gaze2d_x gaze2d_y gaze3d_x gaze3d_y gaze3d_z left_origin_x
#>    <chr>      <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>         <dbl>
#>  1 recording 0.0180    0.460    0.842     49.0    -208.     549.          32.1
#>  2 recording 0.0381    0.457    0.846     58.0    -237.     616.          32.1
#>  3 recording 0.0581    0.455    0.850     70.7    -279.     718.          32.1
#>  4 recording 0.0782    0.445    0.873     84.7    -295.     710.          NA  
#>  5 recording 0.0982    0.444    0.876     86.0    -298.     709.          NA  
#>  6 recording 0.118     0.445    0.869     89.4    -306.     745.          32.1
#>  7 recording 0.138     0.446    0.869    132.     -466.    1134.          32.1
#>  8 recording 0.158     0.449    0.867    230.     -849.    2079.          32.1
#>  9 recording 0.178     0.451    0.867    272.    -1046.    2559.          32.1
#> 10 recording 0.198     0.453    0.866    427.    -1686.    4131.          32.1
#> # ℹ 1,487 more rows
#> # ℹ 16 more variables: left_origin_y <dbl>, left_origin_z <dbl>,
#> #   left_direction_x <dbl>, left_direction_y <dbl>, left_direction_z <dbl>,
#> #   left_pupil <dbl>, right_origin_x <dbl>, right_origin_y <dbl>,
#> #   right_origin_z <dbl>, right_direction_x <dbl>, right_direction_y <dbl>,
#> #   right_direction_z <dbl>, right_pupil <dbl>, valid_left <lgl>,
#> #   valid_right <lgl>, valid <lgl>

recordings <- list_g3_recordings(dirname(g3_example()))
read_g3_gaze(recordings)
#> # A tibble: 1,497 × 24
#>    recording   time gaze2d_x gaze2d_y gaze3d_x gaze3d_y gaze3d_z left_origin_x
#>    <chr>      <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>         <dbl>
#>  1 recording 0.0180    0.460    0.842     49.0    -208.     549.          32.1
#>  2 recording 0.0381    0.457    0.846     58.0    -237.     616.          32.1
#>  3 recording 0.0581    0.455    0.850     70.7    -279.     718.          32.1
#>  4 recording 0.0782    0.445    0.873     84.7    -295.     710.          NA  
#>  5 recording 0.0982    0.444    0.876     86.0    -298.     709.          NA  
#>  6 recording 0.118     0.445    0.869     89.4    -306.     745.          32.1
#>  7 recording 0.138     0.446    0.869    132.     -466.    1134.          32.1
#>  8 recording 0.158     0.449    0.867    230.     -849.    2079.          32.1
#>  9 recording 0.178     0.451    0.867    272.    -1046.    2559.          32.1
#> 10 recording 0.198     0.453    0.866    427.    -1686.    4131.          32.1
#> # ℹ 1,487 more rows
#> # ℹ 16 more variables: left_origin_y <dbl>, left_origin_z <dbl>,
#> #   left_direction_x <dbl>, left_direction_y <dbl>, left_direction_z <dbl>,
#> #   left_pupil <dbl>, right_origin_x <dbl>, right_origin_y <dbl>,
#> #   right_origin_z <dbl>, right_direction_x <dbl>, right_direction_y <dbl>,
#> #   right_direction_z <dbl>, right_pupil <dbl>, valid_left <lgl>,
#> #   valid_right <lgl>, valid <lgl>
```
