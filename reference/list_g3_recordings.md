# List recordings

Searches a folder, such as the root of the Glasses 3 SD card, for
recording folders.

## Usage

``` r
list_g3_recordings(path, recursive = TRUE)
```

## Arguments

- path:

  Folder to search.

- recursive:

  Search subfolders.

## Value

A tibble with one row per recording: `recording` (the folder name, as
used in the `recording` column by the readers), `path`, `name`,
`participant`, `created` and `duration`. Pass it to
[`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
[`read_g3_imu()`](https://mcanzi.de/glasses3/reference/read_g3_imu.md)
or
[`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md)
to read all recordings at once.

## Examples

``` r
recordings <- list_g3_recordings(dirname(g3_example()))
recordings
#> # A tibble: 1 × 6
#>   recording path                  name  participant created             duration
#>   <chr>     <chr>                 <chr> <chr>       <dttm>                 <dbl>
#> 1 recording /home/runner/work/_t… Exam… example     2025-01-01 12:00:00       30
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
