# Add clock time to samples

Adds the date and time of each sample: the start time of the recording,
as stored in `recording.g3`, plus `time`. The clock time helps to align
the samples with other devices that log the time of day.

## Usage

``` r
g3_add_clock_time(x, recordings)
```

## Arguments

- x:

  A data frame with a `time` column, such as the output of
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
  [`read_g3_imu()`](https://mcanzi.de/glasses3/reference/read_g3_imu.md)
  or
  [`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md).

- recordings:

  The start time of the recordings: a recording from
  [`read_g3()`](https://mcanzi.de/glasses3/reference/read_g3.md),
  metadata from
  [`read_g3_info()`](https://mcanzi.de/glasses3/reference/read_g3_info.md)
  or the output of
  [`list_g3_recordings()`](https://mcanzi.de/glasses3/reference/list_g3_recordings.md).
  With several recordings in `x`, use the output of
  [`list_g3_recordings()`](https://mcanzi.de/glasses3/reference/list_g3_recordings.md),
  which is matched to `x` through the `recording` column.

## Value

`x` with a POSIXct column `clock_time` after `time`, in UTC. Use
[`format()`](https://rdrr.io/r/base/format.html) with the `timezone`
from
[`read_g3_info()`](https://mcanzi.de/glasses3/reference/read_g3_info.md)
to show local time. Recordings without a start time get `NA`, with a
warning. If `x` is a grouped tibble, the result has the same groups.

## Examples

``` r
rec <- read_g3(g3_example())
g3_add_clock_time(rec$gaze, rec)
#> # A tibble: 1,497 × 25
#>    recording   time clock_time          gaze2d_x gaze2d_y gaze3d_x gaze3d_y
#>    <chr>      <dbl> <dttm>                 <dbl>    <dbl>    <dbl>    <dbl>
#>  1 recording 0.0180 2025-01-01 12:00:00    0.460    0.842     49.0    -208.
#>  2 recording 0.0381 2025-01-01 12:00:00    0.457    0.846     58.0    -237.
#>  3 recording 0.0581 2025-01-01 12:00:00    0.455    0.850     70.7    -279.
#>  4 recording 0.0782 2025-01-01 12:00:00    0.445    0.873     84.7    -295.
#>  5 recording 0.0982 2025-01-01 12:00:00    0.444    0.876     86.0    -298.
#>  6 recording 0.118  2025-01-01 12:00:00    0.445    0.869     89.4    -306.
#>  7 recording 0.138  2025-01-01 12:00:00    0.446    0.869    132.     -466.
#>  8 recording 0.158  2025-01-01 12:00:00    0.449    0.867    230.     -849.
#>  9 recording 0.178  2025-01-01 12:00:00    0.451    0.867    272.    -1046.
#> 10 recording 0.198  2025-01-01 12:00:00    0.453    0.866    427.    -1686.
#> # ℹ 1,487 more rows
#> # ℹ 18 more variables: gaze3d_z <dbl>, left_origin_x <dbl>,
#> #   left_origin_y <dbl>, left_origin_z <dbl>, left_direction_x <dbl>,
#> #   left_direction_y <dbl>, left_direction_z <dbl>, left_pupil <dbl>,
#> #   right_origin_x <dbl>, right_origin_y <dbl>, right_origin_z <dbl>,
#> #   right_direction_x <dbl>, right_direction_y <dbl>, right_direction_z <dbl>,
#> #   right_pupil <dbl>, valid_left <lgl>, valid_right <lgl>, valid <lgl>

recordings <- list_g3_recordings(dirname(g3_example()))
g3_add_clock_time(read_g3_gaze(recordings), recordings)
#> # A tibble: 1,497 × 25
#>    recording   time clock_time          gaze2d_x gaze2d_y gaze3d_x gaze3d_y
#>    <chr>      <dbl> <dttm>                 <dbl>    <dbl>    <dbl>    <dbl>
#>  1 recording 0.0180 2025-01-01 12:00:00    0.460    0.842     49.0    -208.
#>  2 recording 0.0381 2025-01-01 12:00:00    0.457    0.846     58.0    -237.
#>  3 recording 0.0581 2025-01-01 12:00:00    0.455    0.850     70.7    -279.
#>  4 recording 0.0782 2025-01-01 12:00:00    0.445    0.873     84.7    -295.
#>  5 recording 0.0982 2025-01-01 12:00:00    0.444    0.876     86.0    -298.
#>  6 recording 0.118  2025-01-01 12:00:00    0.445    0.869     89.4    -306.
#>  7 recording 0.138  2025-01-01 12:00:00    0.446    0.869    132.     -466.
#>  8 recording 0.158  2025-01-01 12:00:00    0.449    0.867    230.     -849.
#>  9 recording 0.178  2025-01-01 12:00:00    0.451    0.867    272.    -1046.
#> 10 recording 0.198  2025-01-01 12:00:00    0.453    0.866    427.    -1686.
#> # ℹ 1,487 more rows
#> # ℹ 18 more variables: gaze3d_z <dbl>, left_origin_x <dbl>,
#> #   left_origin_y <dbl>, left_origin_z <dbl>, left_direction_x <dbl>,
#> #   left_direction_y <dbl>, left_direction_z <dbl>, left_pupil <dbl>,
#> #   right_origin_x <dbl>, right_origin_y <dbl>, right_origin_z <dbl>,
#> #   right_direction_x <dbl>, right_direction_y <dbl>, right_direction_z <dbl>,
#> #   right_pupil <dbl>, valid_left <lgl>, valid_right <lgl>, valid <lgl>
```
