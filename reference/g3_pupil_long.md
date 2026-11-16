# Pupil data in long format

Reshapes the pupil columns of gaze data to one row per sample and eye,
which suits plotting and mixed-effects models.

## Usage

``` r
g3_pupil_long(gaze)
```

## Arguments

- gaze:

  Gaze data from
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
  possibly with added columns.

## Value

A tibble with the non-eye columns of `gaze` (such as `recording`,
`time`, `pulse` or `epoch_time`, if present), plus `eye` (`"left"` or
`"right"`) and `pupil`. Groups of a grouped tibble are kept if their
columns are still in the result.

## Examples

``` r
gaze <- read_g3_gaze(g3_example())
g3_pupil_long(gaze)
#> # A tibble: 2,994 × 10
#>    recording   time gaze2d_x gaze2d_y gaze3d_x gaze3d_y gaze3d_z valid eye  
#>    <chr>      <dbl>    <dbl>    <dbl>    <dbl>    <dbl>    <dbl> <lgl> <chr>
#>  1 recording 0.0180    0.460    0.842     49.0    -208.     549. TRUE  left 
#>  2 recording 0.0180    0.460    0.842     49.0    -208.     549. TRUE  right
#>  3 recording 0.0381    0.457    0.846     58.0    -237.     616. TRUE  left 
#>  4 recording 0.0381    0.457    0.846     58.0    -237.     616. TRUE  right
#>  5 recording 0.0581    0.455    0.850     70.7    -279.     718. TRUE  left 
#>  6 recording 0.0581    0.455    0.850     70.7    -279.     718. TRUE  right
#>  7 recording 0.0782    0.445    0.873     84.7    -295.     710. TRUE  left 
#>  8 recording 0.0782    0.445    0.873     84.7    -295.     710. TRUE  right
#>  9 recording 0.0982    0.444    0.876     86.0    -298.     709. TRUE  left 
#> 10 recording 0.0982    0.444    0.876     86.0    -298.     709. TRUE  right
#> # ℹ 2,984 more rows
#> # ℹ 1 more variable: pupil <dbl>
```
