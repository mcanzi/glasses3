# Gaze angles and vergence

Converts the gaze direction of each eye to horizontal and vertical
angles and adds the vergence angle between the two eyes.

## Usage

``` r
g3_gaze_angles(gaze)
```

## Arguments

- gaze:

  Gaze data from
  [`read_g3_gaze()`](https://mcanzi.de/glasses3/reference/read_g3_gaze.md).

## Value

`gaze` with these columns added, in degrees:

- left_azimuth, right_azimuth:

  Horizontal angle, positive to the wearer's right.

- left_elevation, right_elevation:

  Vertical angle, positive up.

- vergence:

  Angle between the left and right gaze directions. Larger values mean
  the eyes converge on a closer point.

Samples without a direction for an eye get `NA`. The result is a tibble,
and if `gaze` is a grouped tibble, it has the same groups.

## Details

The glasses report gaze direction as a unit vector in a coordinate
system centred on the scene camera, where x points to the wearer's left,
y up and z forward (Tobii Pro Glasses 3 Developer Guide). Angles are
relative to the z axis, so (0, 0) is straight ahead of the glasses.

## Examples

``` r
gaze <- g3_gaze_angles(read_g3_gaze(g3_example()))
gaze |>
  dplyr::select(left_azimuth, left_elevation, vergence) |>
  summary()
#>   left_azimuth     left_elevation       vergence      
#>  Min.   :-24.647   Min.   :-23.003   Min.   : 0.3509  
#>  1st Qu.:  0.685   1st Qu.:-12.245   1st Qu.: 4.2129  
#>  Median :  2.172   Median : -7.240   Median : 5.0712  
#>  Mean   :  2.015   Mean   : -8.667   Mean   : 5.4612  
#>  3rd Qu.:  3.983   3rd Qu.: -5.307   3rd Qu.: 6.1301  
#>  Max.   : 25.299   Max.   : 18.841   Max.   :39.3296  
#>  NAs    :228       NAs    :228       NAs    :384      
```
