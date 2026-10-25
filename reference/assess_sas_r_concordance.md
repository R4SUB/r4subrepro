# Compare SAS and R Result Tables for Concordance

Compares two result tables cell by cell and reports how many values
agree, numeric values within `tol` and other values exactly. This
supports the SAS versus R dual-verification step of a hybrid submission,
where the same table is produced in both languages and the results are
reconciled. Returns evidence with `indicator_id = "R-REPRO-009"`.

## Usage

``` r
assess_sas_r_concordance(
  r_data,
  sas_data,
  keys = NULL,
  tol = 1e-08,
  ctx = NULL
)
```

## Arguments

- r_data, sas_data:

  The R and SAS result tables, as data.frames or as paths to CSV files
  (or SAS transport `.xpt` files when 'haven' is installed).

- keys:

  Optional character vector of key columns to order both tables by
  before comparing. When `NULL` the tables are compared in their given
  order.

- tol:

  Numeric tolerance for comparing numeric values. Defaults to 1e-8.

- ctx:

  A run context from
  [`r4subcore::r4sub_run_context()`](https://r4sub.github.io/r4subcore/reference/r4sub_run_context.html).
  When `NULL` a default `"SAS_R_COMPARISON"` context is created.

## Value

A validated evidence table.

## Examples

``` r
a <- data.frame(id = 1:3, val = c(1.0, 2.0, 3.0))
b <- data.frame(id = 1:3, val = c(1.0, 2.0, 3.0))
suppressMessages(assess_sas_r_concordance(a, b))$result
#> [1] "pass"
```
