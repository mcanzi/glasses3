# Insert rows for missing samples

The glasses write a line even for samples where they detect no gaze, so
the gaze data are usually complete. Samples can still be missing, for
example after damaged lines were skipped. `g3_fill_gaps()` inserts a row
for each missing sample, so that the data are evenly spaced again, as
many preprocessing methods assume. The new rows hold `NA`, and their
validity columns are `FALSE`. Values are not interpolated.

## Usage

``` r
g3_fill_gaps(x, rate = NULL)
```

## Arguments

- x:

  Gaze data from
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md),
  [`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md) or
  [`g3_pupil_long()`](https://mcanzi.de/glasses3/reference/g3_pupil_long.md).

- rate:

  Sampling rate in Hz. By default it is worked out from the median
  interval between samples and set to 50 or 100 Hz when it is within 10%
  of either.

## Value

`x` with the inserted rows, sorted by time within each epoch, and a
logical column `inserted` that is `TRUE` for the new rows. If `x` is a
grouped tibble, the result has the same groups.

## Details

With several recordings in `x`, each is filled separately, and so is
each epoch from
[`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md) and
each eye in long data from
[`g3_pupil_long()`](https://mcanzi.de/glasses3/reference/g3_pupil_long.md).
The `recording`, `epoch`, `pulse` and `eye` columns and columns you
added yourself, such as a participant column, are copied into the new
rows when they have a single value within the recording, epoch or eye.
`epoch_time` and `clock_time` are worked out for the new rows.

## Examples

``` r
gaze <- read_g3_gaze(g3_example())
gappy <- dplyr::slice(gaze, -(100:109))
filled <- g3_fill_gaps(gappy)
nrow(gappy)
#> [1] 1487
nrow(filled)
#> [1] 1497
filled |>
  dplyr::filter(inserted) |>
  dplyr::select(time, left_pupil, valid)
#> # A tibble: 10 × 3
#>     time left_pupil valid
#>    <dbl>      <dbl> <lgl>
#>  1  2.00         NA FALSE
#>  2  2.02         NA FALSE
#>  3  2.04         NA FALSE
#>  4  2.06         NA FALSE
#>  5  2.08         NA FALSE
#>  6  2.10         NA FALSE
#>  7  2.12         NA FALSE
#>  8  2.14         NA FALSE
#>  9  2.16         NA FALSE
#> 10  2.18         NA FALSE
```
