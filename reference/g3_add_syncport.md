# Add sync port information to samples

Adds the sync port state and the most recent pulse to each sample of
gaze or IMU data. With several recordings, samples are matched to the
pulses of their own recording through the `recording` column.

## Usage

``` r
g3_add_syncport(x, events, direction = c("out", "in"))
```

## Arguments

- x:

  A data frame with a `time` column, such as the output of
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md)
  or
  [`read_g3_imu()`](https://mcanzi.de/glasses3/reference/read_g3_imu.md).

- events:

  Event data from
  [`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md).

- direction:

  `"out"` for the signal sent by the glasses, `"in"` for the signal
  received from external equipment.

## Value

`x` with three added columns: `syncport` (1 while the signal is high, 0
otherwise), `pulse` (number of the most recent pulse onset, `NA` before
the first one) and `pulse_time` (seconds since that onset). If `x` is a
grouped tibble, the result has the same groups.

## Examples

``` r
rec <- read_g3(g3_example())
gaze <- g3_add_syncport(rec$gaze, rec$events)
gaze |>
  dplyr::filter(syncport == 1) |>
  dplyr::select(time, pulse, pulse_time)
#> # A tibble: 173 × 3
#>      time pulse pulse_time
#>     <dbl> <int>      <dbl>
#>  1 0.0982     1     0.0197
#>  2 0.118      1     0.0397
#>  3 0.138      1     0.0597
#>  4 0.158      1     0.0798
#>  5 0.178      1     0.0998
#>  6 0.198      1     0.120 
#>  7 0.218      1     0.140 
#>  8 0.238      1     0.160 
#>  9 0.258      1     0.180 
#> 10 0.279      1     0.200 
#> # ℹ 163 more rows
```
