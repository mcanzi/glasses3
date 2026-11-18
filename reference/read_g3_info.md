# Read recording metadata

Reads `recording.g3` and the files in the `meta` folder.

## Usage

``` r
read_g3_info(path)
```

## Arguments

- path:

  Path to a recording folder.

## Value

A list of class `g3_info` with these elements:

- `name` and `uuid` of the recording

- `created`, the start time (POSIXct, UTC), and `timezone`

- `duration` in seconds

- `gaze_samples` and `gaze_valid_samples`, as counted by the glasses

- `participant`, as entered when recording

- `firmware` version

- `recording_unit` and `head_unit` serial numbers

- `files`, the names of the data files

- `scene_camera`, the camera calibration

- `meta`, all files in the `meta` folder as character strings, or as raw
  vectors for files that are not UTF-8 text

## Examples

``` r
read_g3_info(g3_example())
#> Tobii Pro Glasses 3 recording
#>   Name:        Example recording
#>   Participant: example
#>   Created:     2025-01-01 12:00:00 UTC
#>   Duration:    30.0 s
#>   Gaze:        1497 samples, 90.7% valid
#>   Firmware:    1.14.5+nudelsoppa
```
