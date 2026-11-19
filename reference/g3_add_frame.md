# Add scene video frame numbers

Adds the number of the scene video frame shown at the time of each
sample, so that samples can be matched to codes made frame by frame from
the video, such as areas of interest.

## Usage

``` r
g3_add_frame(x, fps = 25, start = 0)
```

## Arguments

- x:

  A data frame with a `time` column, such as the output of
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
  [`read_g3_imu()`](https://mcanzi.de/glasses3/reference/read_g3_imu.md),
  [`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md)
  or [`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md).

- fps:

  Frame rate of the scene video in frames per second.

- start:

  Time of the first video frame in seconds since the start of the
  recording. With several recordings in `x`, it applies to all of them.

## Value

`x` with an integer column `frame` after `time`. Frames are counted from
0, as in ffmpeg and OpenCV. Samples before `start` or without a time get
`NA`. If `x` is a grouped tibble, the result has the same groups.

## Details

The Tobii Pro Glasses 3 Developer Guide gives the scene video as 25
frames per second, and states that all data streams are timestamped by
the same clock. Frame `k` is taken to start at `start + k / fps` seconds
since the start of the recording. The guide does not say when the first
frame is taken, so `start` defaults to 0. Check the alignment against an
event visible in the video, such as a light switched on by a sync port
pulse, and set `start` if needed.

## Examples

``` r
gaze <- g3_add_frame(read_g3_gaze(g3_example()))
gaze |>
  dplyr::select(time, frame, gaze2d_x, gaze2d_y) |>
  head()
#> # A tibble: 6 × 4
#>     time frame gaze2d_x gaze2d_y
#>    <dbl> <int>    <dbl>    <dbl>
#> 1 0.0180     0    0.460    0.842
#> 2 0.0381     0    0.457    0.846
#> 3 0.0581     1    0.455    0.850
#> 4 0.0782     1    0.445    0.873
#> 5 0.0982     2    0.444    0.876
#> 6 0.118      2    0.445    0.869

gaze |>
  dplyr::summarise(gaze2d_x = mean(gaze2d_x, na.rm = TRUE),
                   gaze2d_y = mean(gaze2d_y, na.rm = TRUE), .by = frame)
#> # A tibble: 750 × 3
#>    frame gaze2d_x gaze2d_y
#>    <int>    <dbl>    <dbl>
#>  1     0    0.458    0.844
#>  2     1    0.450    0.861
#>  3     2    0.444    0.873
#>  4     3    0.448    0.868
#>  5     4    0.452    0.866
#>  6     5    0.454    0.865
#>  7     6    0.455    0.867
#>  8     7    0.456    0.885
#>  9     8    0.455    0.892
#> 10     9    0.452    0.904
#> # ℹ 740 more rows
```
