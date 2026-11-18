# Extract API events

Returns the events sent to the glasses through their API during the
recording, for example with the `send-event` call from an experiment
script. Each event has a tag and an object, which can hold any JSON
value.

## Usage

``` r
g3_api_events(events)
```

## Arguments

- events:

  Event data from
  [`read_g3_events()`](https://mcanzi.de/glasses3/reference/read_g3_events.md).

## Value

A tibble with columns `recording` (if `events` has one), `onset`
(seconds since the start of the recording), `tag` and `object` (the
object as a JSON string, or `NA` if the event has none). Pass it to
[`g3_epochs()`](https://mcanzi.de/glasses3/reference/g3_epochs.md) to
cut epochs at the events. Groups of a grouped tibble are kept if their
columns are still in the result.

## Examples

``` r
events <- read_g3_events(g3_example())
g3_api_events(events)
#> # A tibble: 0 × 4
#> # ℹ 4 variables: recording <chr>, onset <dbl>, tag <chr>, object <chr>
```
