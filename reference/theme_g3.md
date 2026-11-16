# Theme for glasses3 plots

The ggplot2 theme used by all plots in the package, for giving your own
plots the same look. It builds on
[`ggplot2::theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html)
with light grey gridlines, grey axis text, the legend at the top left
and bold left-aligned panel titles on a white background.

## Usage

``` r
theme_g3(base_size = 11)
```

## Arguments

- base_size:

  Base font size in points.

## Value

A ggplot2 theme.

## Details

In the package plots, the left eye is drawn in slate blue (`#2A568C`)
and the right eye in Indian red (`#EE6363`, R's `indianred2`). The pair
passes checks for lightness, chroma, contrast against white and
separation under simulated protanopia, deuteranopia and tritanopia.
Means use darker steps of the same hues (`#1D4371` and `indianred3`).

## Examples

``` r
library(ggplot2)
gaze <- read_g3_gaze(g3_example())
ggplot(gaze, aes(time, left_pupil)) +
  geom_line(colour = "#2A568C", na.rm = TRUE) +
  theme_g3()
```
