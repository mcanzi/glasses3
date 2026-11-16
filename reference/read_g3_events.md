# Read event data

Parses `eventdata.gz`, which holds sync port signals and any events sent
to the glasses through the API during the recording. Lines that cannot
be parsed are skipped with a warning.

## Usage

``` r
read_g3_events(path)
```

## Arguments

- path:

  Path to a recording folder or directly to an `eventdata.gz` file.
  Several paths, or the output of
  [`list_g3_recordings()`](https://mcanzi.de/glasses3/reference/list_g3_recordings.md),
  read several recordings into one tibble.

## Value

A tibble with columns `recording` (see
[`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md)),
`time` (seconds since the start of the recording), `type` (for example
`"syncport"`), `direction` and `value` (for sync port events; `NA`
otherwise), and `data`, the event payload as a JSON string, so that
other event types are kept unchanged.

## Examples

``` r
read_g3_events(g3_example())
#> # A tibble: 10 × 6
#>    recording    time type     direction value data                              
#>    <chr>       <dbl> <chr>    <chr>     <dbl> <chr>                             
#>  1 recording  0.0785 syncport out           1 "{\"direction\":\"out\",\"value\"…
#>  2 recording  0.574  syncport out           0 "{\"direction\":\"out\",\"value\"…
#>  3 recording  1.07   syncport out           1 "{\"direction\":\"out\",\"value\"…
#>  4 recording  1.57   syncport out           0 "{\"direction\":\"out\",\"value\"…
#>  5 recording  2.07   syncport out           1 "{\"direction\":\"out\",\"value\"…
#>  6 recording  2.57   syncport out           0 "{\"direction\":\"out\",\"value\"…
#>  7 recording 10.1    syncport out           1 "{\"direction\":\"out\",\"value\"…
#>  8 recording 11.1    syncport out           0 "{\"direction\":\"out\",\"value\"…
#>  9 recording 20.1    syncport out           1 "{\"direction\":\"out\",\"value\"…
#> 10 recording 21.1    syncport out           0 "{\"direction\":\"out\",\"value\"…
```
