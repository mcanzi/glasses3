# Downsample to fixed time bins

Averages samples within bins of fixed width, for example to reduce 50 Hz
data to 100 ms bins before fitting a generalised additive mixed model.
Fewer samples make models faster to fit and reduce the autocorrelation
the model has to account for.

## Usage

``` r
g3_downsample(x, bin = 0.1, min_valid = 0.5, by = NULL)
```

## Arguments

- x:

  Gaze data from
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
  epochs from
  [`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md) or
  long pupil data from
  [`g3_pupil_long()`](https://mcanzi.de/glasses3/reference/g3_pupil_long.md).

- bin:

  Bin width in seconds.

- min_valid:

  Proportion of samples in a bin that must have a value. A numeric
  column is `NA` in bins where fewer of its samples are available, so
  that bins mostly lost to a blink do not get a value from the few
  samples left.

- by:

  Names of further columns to group by, such as a participant or
  condition column. They are kept in the result.

## Value

A tibble with one row per bin and group, starting with the grouping
columns. Other numeric columns hold the mean of the available samples,
and logical columns, such as `valid`, the proportion of `TRUE` samples.
`samples` gives the number of samples in the bin. All other columns are
dropped. A grouped tibble keeps its groups.

## Details

Bins are counted from time 0, or from the pulse onset for epochs from
[`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md), so
that the onset falls on a bin boundary. Each bin is labelled with its
start time. Rows are grouped by the `recording`, `pulse` and `eye`
columns where these exist, so the function works on the output of
[`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
[`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md) and
[`g3_pupil_long()`](https://mcanzi.de/glasses3/reference/g3_pupil_long.md).
Columns named in `by` are added to these groups, and so are the groups
of a grouped tibble.

## Examples

``` r
gaze <- read_g3_gaze(g3_example())
g3_downsample(gaze, bin = 0.1)
#> # A tibble: 300 × 25
#>    recording  time samples gaze2d_x gaze2d_y gaze3d_x gaze3d_y gaze3d_z
#>    <chr>     <dbl>   <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl>
#>  1 recording   0         5    0.452    0.857     69.7    -264.     660.
#>  2 recording   0.1       5    0.449    0.867    230.     -871.    2130.
#>  3 recording   0.2       5    0.455    0.870    371.    -1522.    3725.
#>  4 recording   0.3       5    0.454    0.895     57.4    -254.     579.
#>  5 recording   0.4       5    0.451    0.906     42.3    -181.     400.
#>  6 recording   0.5       5    0.380    0.742    425.     -380.    1611.
#>  7 recording   0.6       5    0.374    0.654    548.     -326.    2019.
#>  8 recording   0.7       5    0.372    0.658    553.     -335.    1997.
#>  9 recording   0.8       5    0.369    0.668    563.     -357.    1990.
#> 10 recording   0.9       5    0.363    0.670    887.     -551.    3025.
#> # ℹ 290 more rows
#> # ℹ 17 more variables: left_origin_x <dbl>, left_origin_y <dbl>,
#> #   left_origin_z <dbl>, left_direction_x <dbl>, left_direction_y <dbl>,
#> #   left_direction_z <dbl>, left_pupil <dbl>, right_origin_x <dbl>,
#> #   right_origin_y <dbl>, right_origin_z <dbl>, right_direction_x <dbl>,
#> #   right_direction_y <dbl>, right_direction_z <dbl>, right_pupil <dbl>,
#> #   valid_left <dbl>, valid_right <dbl>, valid <dbl>

rec <- read_g3(g3_example())
ep <- g3_epochs(rec$gaze, rec$events, before = 0.5, after = 3)
g3_downsample(g3_pupil_long(ep), bin = 0.1)
#> # A tibble: 342 × 13
#>    recording pulse eye   epoch_time samples   time gaze2d_x gaze2d_y gaze3d_x
#>    <chr>     <int> <chr>      <dbl>   <dbl>  <dbl>    <dbl>    <dbl>    <dbl>
#>  1 recording     1 left        -0.1       4 0.0481    0.454    0.853     65.6
#>  2 recording     1 left         0         5 0.138     0.447    0.869    162. 
#>  3 recording     1 left         0.1       4 0.228     0.454    0.866    476. 
#>  4 recording     1 left         0.2       5 0.319     0.456    0.884    115. 
#>  5 recording     1 left         0.3       5 0.419     0.457    0.907     37.8
#>  6 recording     1 left         0.4       5 0.519     0.414    0.848    174. 
#>  7 recording     1 left         0.5       5 0.619     0.368    0.680    572. 
#>  8 recording     1 left         0.6       5 0.719     0.377    0.642    534. 
#>  9 recording     1 left         0.7       5 0.819     0.372    0.666    552. 
#> 10 recording     1 left         0.8       5 0.920     0.363    0.668    585. 
#> # ℹ 332 more rows
#> # ℹ 4 more variables: gaze3d_y <dbl>, gaze3d_z <dbl>, valid <dbl>, pupil <dbl>

gaze |>
  dplyr::mutate(participant = "P01") |>
  g3_downsample(bin = 0.1, by = "participant")
#> # A tibble: 300 × 26
#>    recording participant  time samples gaze2d_x gaze2d_y gaze3d_x gaze3d_y
#>    <chr>     <chr>       <dbl>   <dbl>    <dbl>    <dbl>    <dbl>    <dbl>
#>  1 recording P01           0         5    0.452    0.857     69.7    -264.
#>  2 recording P01           0.1       5    0.449    0.867    230.     -871.
#>  3 recording P01           0.2       5    0.455    0.870    371.    -1522.
#>  4 recording P01           0.3       5    0.454    0.895     57.4    -254.
#>  5 recording P01           0.4       5    0.451    0.906     42.3    -181.
#>  6 recording P01           0.5       5    0.380    0.742    425.     -380.
#>  7 recording P01           0.6       5    0.374    0.654    548.     -326.
#>  8 recording P01           0.7       5    0.372    0.658    553.     -335.
#>  9 recording P01           0.8       5    0.369    0.668    563.     -357.
#> 10 recording P01           0.9       5    0.363    0.670    887.     -551.
#> # ℹ 290 more rows
#> # ℹ 18 more variables: gaze3d_z <dbl>, left_origin_x <dbl>,
#> #   left_origin_y <dbl>, left_origin_z <dbl>, left_direction_x <dbl>,
#> #   left_direction_y <dbl>, left_direction_z <dbl>, left_pupil <dbl>,
#> #   right_origin_x <dbl>, right_origin_y <dbl>, right_origin_z <dbl>,
#> #   right_direction_x <dbl>, right_direction_y <dbl>, right_direction_z <dbl>,
#> #   right_pupil <dbl>, valid_left <dbl>, valid_right <dbl>, valid <dbl>
```
