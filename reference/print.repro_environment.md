# Print a Computational Environment Snapshot

Print a Computational Environment Snapshot

## Usage

``` r
# S3 method for class 'repro_environment'
print(x, ...)
```

## Arguments

- x:

  A `repro_environment` object from
  [`capture_environment()`](https://r4sub.github.io/r4subrepro/reference/capture_environment.md).

- ...:

  Ignored.

## Value

Invisibly returns `x`. Called for the side effect of printing the R
version, platform, OS, locale, and package count.
