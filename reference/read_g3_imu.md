# Read inertial measurement unit data

Parses `imudata.gz`. Accelerometer and gyroscope samples and
magnetometer samples are stored on separate lines at different rates, so
each row has `NA` for the sensors not sampled at that time. Lines that
cannot be parsed are skipped with a warning.

## Usage

``` r
read_g3_imu(path)
```

## Arguments

- path:

  Path to a recording folder or directly to an `imudata.gz` file.
  Several paths, or the output of
  [`list_g3_recordings()`](https://mcanzi.de/glasses3/reference/list_g3_recordings.md),
  read several recordings into one tibble.

## Value

A tibble with columns `recording` (see
[`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md)),
`time` (seconds since the start of the recording), `accel_x`, `accel_y`,
`accel_z` (accelerometer), `gyro_x`, `gyro_y`, `gyro_z` (gyroscope) and
`mag_x`, `mag_y`, `mag_z` (magnetometer). Following the Tobii Pro
Glasses 3 Developer Guide, acceleration is in metres per second squared,
rotation in degrees per second and the magnetic field in microtesla.

## Examples

``` r
read_g3_imu(g3_example())
#> # A tibble: 3,835 × 11
#>    recording    time accel_x accel_y accel_z gyro_x gyro_y gyro_z mag_x mag_y
#>    <chr>       <dbl>   <dbl>   <dbl>   <dbl>  <dbl>  <dbl>  <dbl> <dbl> <dbl>
#>  1 recording 0.00338  NA       NA      NA      NA    NA      NA   -12.5  31.9
#>  2 recording 0.0119   -0.462   -9.96   -1.69  -17.0  -3.84  -25.3  NA    NA  
#>  3 recording 0.0204   -0.527   -9.94   -1.64  -17.6  -4.05  -24.7  NA    NA  
#>  4 recording 0.0288   -0.607   -9.87   -1.55  -18.0  -4.37  -24.1  NA    NA  
#>  5 recording 0.0373   -0.678   -9.83   -1.52  -18.2  -4.80  -23.3  NA    NA  
#>  6 recording 0.0457   -0.722   -9.82   -1.48  -18.4  -5.35  -22.2  NA    NA  
#>  7 recording 0.0542   -0.790   -9.80   -1.44  -18.6  -5.97  -20.9  NA    NA  
#>  8 recording 0.0627   -0.834   -9.75   -1.37  -18.3  -6.56  -19.4  NA    NA  
#>  9 recording 0.0711   -0.864   -9.71   -1.32  -18.2  -6.81  -17.4  NA    NA  
#> 10 recording 0.0796   -0.904   -9.67   -1.27  -17.9  -7.16  -14.8  NA    NA  
#> # ℹ 3,825 more rows
#> # ℹ 1 more variable: mag_z <dbl>
```
