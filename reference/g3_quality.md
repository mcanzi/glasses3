# Data quality per recording or epoch

Counts the samples of each recording or epoch and how many of them hold
data, for example to find trials with too much missing data before
analysis.

## Usage

``` r
g3_quality(x, by = NULL)
```

## Arguments

- x:

  Gaze data from
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md)
  or [`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md).
  Long pupil data from
  [`g3_pupil_long()`](https://mcanzi.de/glasses3/reference/g3_pupil_long.md)
  are not accepted, because each sample is there twice.

- by:

  Names of further columns to group by, such as a condition column. They
  are kept in the result.

## Value

A tibble with one row per group, starting with the grouping columns, and
these columns:

- samples:

  Number of samples.

- duration:

  Seconds from the first to the last sample.

- valid:

  Proportion of samples with a gaze point.

- valid_left, valid_right:

  Proportion of samples with data for each eye, if `x` has these
  columns.

- max_gap:

  Longest time in seconds between two samples with a gaze point. The
  first and last samples of the group count as boundaries, so missing
  data at the start or end are included. In complete data it is the
  sample interval, 0.02 s at 50 Hz. Damaged lines skipped by the readers
  also lengthen it.

Samples without a time count towards `samples` and the proportions, but
not towards `duration` and `max_gap`. A grouped tibble keeps its groups.

## Details

Rows are grouped by the `recording` and `epoch` columns where these
exist, so the function works on the output of
[`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
[`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md) and
[`g3_fill_gaps()`](https://mcanzi.de/glasses3/reference/g3_fill_gaps.md).
Columns named in `by` are added to these groups, and so are the groups
of a grouped tibble. Rows inserted by
[`g3_fill_gaps()`](https://mcanzi.de/glasses3/reference/g3_fill_gaps.md)
count as samples without data.

## Examples

``` r
rec <- read_g3(g3_example())
g3_quality(rec$gaze)
#> # A tibble: 1 × 7
#>   recording samples duration valid valid_left valid_right max_gap
#>   <chr>       <int>    <dbl> <dbl>      <dbl>       <dbl>   <dbl>
#> 1 recording    1497     30.0 0.907      0.848       0.803   0.260

ep <- g3_epochs(rec$gaze, rec$events, before = 0.5, after = 3, direction = "out")
quality <- g3_quality(ep)
quality
#> # A tibble: 5 × 8
#>   recording epoch samples duration valid valid_left valid_right max_gap
#>   <chr>     <int>   <int>    <dbl> <dbl>      <dbl>       <dbl>   <dbl>
#> 1 recording     1     153     3.05 0.922      0.850       0.817  0.220 
#> 2 recording     2     175     3.49 0.88       0.829       0.789  0.220 
#> 3 recording     3     175     3.49 0.88       0.851       0.857  0.220 
#> 4 recording     4     174     3.47 0.954      0.908       0.776  0.180 
#> 5 recording     5     175     3.49 1          0.971       0.977  0.0201
dplyr::filter(quality, valid >= 0.8, max_gap < 0.5)
#> # A tibble: 5 × 8
#>   recording epoch samples duration valid valid_left valid_right max_gap
#>   <chr>     <int>   <int>    <dbl> <dbl>      <dbl>       <dbl>   <dbl>
#> 1 recording     1     153     3.05 0.922      0.850       0.817  0.220 
#> 2 recording     2     175     3.49 0.88       0.829       0.789  0.220 
#> 3 recording     3     175     3.49 0.88       0.851       0.857  0.220 
#> 4 recording     4     174     3.47 0.954      0.908       0.776  0.180 
#> 5 recording     5     175     3.49 1          0.971       0.977  0.0201
```
