# tilework — agent context

`tilework` is an R package (S4) for tile/patch-based processing of large spatial and
raster datasets. Tiles are planned lazily — bounds are computed on demand from stored
plan parameters, never materialized as a stored list.

**Architecture lives in `vignettes/articles/design.Rmd`**: class hierarchy, slots,
constructors, the `.extract_ij_tile()` dispatch chain, padding, `pointTilePlan`'s
input/output model, `tileApply` data flow, and the checklist for adding a new
`tilePlan` subclass. Read it before touching dispatch or adding a subclass. This file
covers only what that document doesn't.

## Development

```r
devtools::load_all(".")
devtools::test()        # or: testthat::test_dir("tests/testthat")
devtools::document()    # read the roxygen pin below first
```

- **Performance tests are gated** behind `TEST_PERFORMANCE=true`. Four tests in
  `test_02_tiles_edgecases.R`, `test_03_get.R`, and `test_04_tileapply.R` skip
  silently without it.
- `tests/testthat/setup.R` sets `options("tilework.warn_sequential" = FALSE)`, so
  sequential-backend warnings are suppressed under test but not at the console.
- `vignettes/articles/` is pkgdown-only and Rbuildignored — files there are not
  package vignettes and are not built by `R CMD build`. Real vignettes go in
  `vignettes/` top level.
- Examples run under `R CMD check` with `T`/`F` bound to a promise that throws
  (`$R_HOME/share/R/examples-header.R`). Always write `TRUE`/`FALSE` in `@examples`.

## Debugging dispatch

`options("tilework.verbose" = "debug")`, or `verbose = "debug"` passed to `tileApply`,
traces each step of the `redispatch_tileapply` chain — which method matched, and which
`...` params were present at each layer.

## Conventions

- Bounds are always `c(xmin, xmax, ymin, ymax)` internally, before `fun`
  post-processing. Spatial offsets are `c(ymin, xmin)` of the plan extent.
- `dims = c(nrows, ncols)`; `i` = row, `j` = col. Flat index is row-major and 1-based
  via `.tile_idx_to_ij()` / `.ij_to_tile_idx()` in `utils.R`.
- `getTile` and `tileApply` need no changes for a new subclass as long as `[i]` returns
  a `SpatExtent` or `integer[4]` — that return type is what drives `getBoundedData`
  dispatch.
- `default_get_params` in `redispatch_tileapply()` should hold only params for the
  `getTile` chain. Do not add params that already have static defaults in a `getTile`
  signature; they will shadow those defaults.
