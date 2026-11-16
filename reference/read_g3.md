# Read a Tobii Pro Glasses 3 recording

Reads a recording folder as written to the SD card by the Tobii Pro
Glasses 3. The folder contains `recording.g3`, `gazedata.gz`,
`imudata.gz`, `eventdata.gz` and a `meta` folder. The scene video is not
needed.

## Usage

``` r
read_g3(path, data = c("gaze", "imu", "events"))
```

## Arguments

- path:

  Path to a recording folder.

- data:

  Which data streams to read. Any of `"gaze"`, `"imu"` and `"events"`.

## Value

An object of class `g3_recording`: a list with elements `info` (see
[`read_g3_info()`](https://mcanzi.de/glasses3/reference/read_g3_info.md)),
`gaze` (see
[`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md)),
`imu` (see
[`read_g3_imu()`](https://mcanzi.de/glasses3/reference/read_g3_imu.md))
and `events` (see
[`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md)).
Streams not requested are `NULL`.

## Details

`read_g3()` reads one recording. To read several recordings into one
data frame, give their paths to
[`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
[`read_g3_imu()`](https://mcanzi.de/glasses3/reference/read_g3_imu.md)
or
[`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md).

## See also

[`list_g3_recordings()`](https://mcanzi.de/glasses3/reference/list_g3_recordings.md)
to find recordings on an SD card.

## Examples

``` r
path <- g3_example()
rec <- read_g3(path)
rec
#> Tobii Pro Glasses 3 recording
#>   Name:        Example recording
#>   Participant: example
#>   Created:     2025-01-01 12:00:00 UTC
#>   Duration:    30.0 s
#>   Gaze:        1497 samples, 90.7% valid
#>   Firmware:    1.14.5+nudelsoppa
#>   Sampling:    50 Hz
#>   $gaze      1497 rows
#>   $imu       3835 rows
#>   $events    10 rows
summary(rec)
#> Duration: 30.0 s, 1497 samples at 50 Hz (largest gap 0.020 s)
#> Valid: 90.7% gaze point, 84.8% left, 80.3% right
#> Left pupil (mm):
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.     NAs 
#>   4.706   5.886   6.117   6.067   6.264   6.963     228 
#> Right pupil (mm):
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max.     NAs 
#>   4.629   6.001   6.192   6.152   6.312   7.419     295 
#> Sync port pulses (out): 5
rec$gaze
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
plot(rec)
```
