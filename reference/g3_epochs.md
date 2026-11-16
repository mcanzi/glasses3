# Cut samples into epochs around sync port pulses

Returns the samples from `before` seconds before to `after` seconds
after the onset of each sync port pulse, for example to analyse pupil
responses to stimuli whose onset was marked with a sync pulse. With
several recordings, each recording is cut at its own pulses.

## Usage

``` r
g3_epochs(
  x,
  events,
  before = 0,
  after = 1,
  direction = c("out", "in"),
  pulses = NULL
)
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

- before, after:

  Seconds to keep before and after each onset.

- direction:

  `"out"` for the signal sent by the glasses, `"in"` for the signal
  received from external equipment.

- pulses:

  Which pulses to use, as pulse numbers. Defaults to all.

## Value

The selected rows of `x`, sorted by time within each epoch, with added
columns `pulse` and `epoch_time` (seconds relative to the pulse onset).
Samples can appear in more than one epoch if epochs overlap. If `x` is a
grouped tibble, the result has the same groups.

## Examples

``` r
rec <- read_g3(g3_example())
ep <- g3_epochs(rec$gaze, rec$events, before = 1, after = 5)
dplyr::count(ep, pulse)
#> # A tibble: 5 × 2
#>   pulse     n
#>   <int> <int>
#> 1     1   253
#> 2     2   300
#> 3     3   300
#> 4     4   299
#> 5     5   300
```
