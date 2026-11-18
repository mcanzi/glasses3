# Cut samples into epochs

Returns the samples from `before` seconds before to `after` seconds
after each onset, for example to analyse pupil responses to stimuli. The
onsets are the sync port pulses in the event data, or any table of
onsets, such as the API events from
[`g3_api_events()`](https://mcanzi.de/glasses3/reference/g3_api_events.md)
or the trial onsets of an experiment. With several recordings, each
recording is cut at its own onsets.

## Usage

``` r
g3_epochs(
  x,
  events,
  before = 0,
  after = 1,
  direction = c("in", "out"),
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
  [`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md),
  to cut at the sync port pulses, or a data frame with an `onset` column
  in seconds since the start of the recording. With a `recording`
  column, each recording is cut at its own onsets; without one, every
  recording is cut at all onsets. The other columns of the data frame,
  such as a condition or the `tag` of an API event, are copied to the
  samples of each epoch, except `time`, `epoch` and `epoch_time`.

- before, after:

  Seconds to keep before and after each onset.

- direction:

  Sync port direction, used with event data; see
  [`g3_syncport()`](https://mcanzi.de/glasses3/reference/g3_syncport.md).

- pulses:

  Which sync port pulses to use, as pulse numbers. Defaults to all. To
  use some rows of a table of onsets, filter the table instead.

## Value

The selected rows of `x`, sorted by time within each epoch, with added
columns `epoch` (running number of the onset within the recording) and
`epoch_time` (seconds relative to the onset). Epochs cut at sync port
pulses also get `pulse`, the pulse number. Columns copied from a table
of onsets replace columns of `x` with the same name. Samples can appear
in more than one epoch if epochs overlap. If `x` is a grouped tibble,
the result has the same groups.

## Examples

``` r
rec <- read_g3(g3_example())
ep <- g3_epochs(rec$gaze, rec$events, before = 1, after = 5, direction = "out")
dplyr::count(ep, epoch)
#> # A tibble: 5 × 2
#>   epoch     n
#>   <int> <int>
#> 1     1   253
#> 2     2   300
#> 3     3   300
#> 4     4   299
#> 5     5   300

trials <- data.frame(onset = c(2, 12, 22), condition = c("a", "b", "a"))
ep <- g3_epochs(rec$gaze, trials, before = 0.5, after = 3)
dplyr::count(ep, epoch, condition)
#> # A tibble: 3 × 3
#>   epoch condition     n
#>   <int> <chr>     <int>
#> 1     1 a           175
#> 2     2 b           174
#> 3     3 a           174
```
