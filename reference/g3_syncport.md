# Extract sync port pulses

Turns the sync port signal changes in the event data into one row per
pulse, where a pulse runs from the signal going high (1) to it going low
(0) again. With several recordings, pulses are numbered within each
recording.

## Usage

``` r
g3_syncport(events, direction = c("out", "in"))
```

## Arguments

- events:

  Event data from
  [`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md).

- direction:

  `"out"` for the signal sent by the glasses, `"in"` for the signal
  received from external equipment.

## Value

A tibble with columns `recording` (if `events` has one), `pulse`
(running number), `onset`, `offset` and `duration` (seconds). `offset`
is `NA` if the recording ended while the signal was high. Groups of a
grouped tibble are kept if their columns are still in the result.

## Examples

``` r
events <- read_g3_events(g3_example())
g3_syncport(events)
#> # A tibble: 5 × 5
#>   recording pulse   onset offset duration
#>   <chr>     <int>   <dbl>  <dbl>    <dbl>
#> 1 recording     1  0.0785  0.574    0.495
#> 2 recording     2  1.07    1.57     0.499
#> 3 recording     3  2.07    2.57     0.5  
#> 4 recording     4 10.1    11.1      0.994
#> 5 recording     5 20.1    21.1      1.000
```
