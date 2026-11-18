# Angular gaze velocity

Adds the angular velocity of each eye: the angle between the gaze
directions of two consecutive samples, divided by the time between them.
The directions are relative to the glasses, so the velocity is that of
the eye in the head. It is not smoothed, and can be the starting point
for detecting fixations and saccades, for example with a velocity
threshold.

## Usage

``` r
g3_gaze_velocity(gaze)
```

## Arguments

- gaze:

  Gaze data from
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md)
  or [`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md).

## Value

`gaze` with columns `left_velocity` and `right_velocity` in degrees per
second. Each sample is compared with the previous sample of the same
recording and epoch. The first sample, and samples where either sample
of the pair has no direction, get `NA`. The result is a tibble, and if
`gaze` is a grouped tibble, it has the same groups.

## Examples

``` r
gaze <- g3_gaze_velocity(read_g3_gaze(g3_example()))
gaze |>
  dplyr::select(time, left_velocity, right_velocity) |>
  summary()
#>       time          left_velocity      right_velocity     
#>  Min.   : 0.01802   Min.   :  0.2704   Min.   :   0.2612  
#>  1st Qu.: 7.51158   1st Qu.:  4.1465   1st Qu.:   3.7903  
#>  Median :15.00514   Median :  8.6165   Median :   9.0639  
#>  Mean   :15.00516   Mean   : 29.6006   Mean   :  38.8253  
#>  3rd Qu.:22.49869   3rd Qu.: 25.2244   3rd Qu.:  32.5353  
#>  Max.   :29.99225   Max.   :802.9578   Max.   :1727.0960  
#>                     NAs    :286        NAs    :359        
```
