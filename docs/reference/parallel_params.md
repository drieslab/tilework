# Parallel Processing Parameters

[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
is parallelized through either
[`future.apply::future_lapply()`](https://future.apply.futureverse.org/reference/future_lapply.html)
(default) or
[`BiocParallel::bplapply()`](https://rdrr.io/pkg/BiocParallel/man/bplapply.html).

Additional parameters to control parallelization can be passed as a
`list` through the `parallel_params` argument in
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
methods.

## Usage

``` r
getTileworkParMethod()

setTileworkParMethod(method)
```

## Arguments

- method:

  character. Either `"future"` (default) or `"biocparallel"`. Which
  parallelization framework to use.

## Value

`getTileworkParMethod` returns `character`. The parallelization method
being used.

`setTileworkParMethod` returns `NULL` invisibly

## Parameters

Available parameters for the `parallel_params` list:

- `method` - character. Either `"future"` (default) or `"biocparallel"`.
  Which parallelization framework to use. Overrides
  `setTileworkParMethod()`

- `future_seed` - logical (default = `TRUE`). Passed to the
  `future.seed` parameter in
  [`future.apply::future_lapply()`](https://future.apply.futureverse.org/reference/future_lapply.html).
  Only used when `method = "future"`.

- `BPPARAM` - a {BiocParallel} parallelization parameter object. Only
  used when `method = "biocparallel"`.

Additional parameters relevant to the underlying functions may also be
passed in the list and will be forwarded via `...`.

## Package Options

- `"tilework.warn_sequential"` - logical (default = `TRUE`). Whether to
  warn when using parallelization defaults that run sequentially (i.e.,
  [`future::sequential()`](https://future.futureverse.org/reference/sequential.html)
  or
  [`BiocParallel::SerialParam()`](https://rdrr.io/pkg/BiocParallel/man/SerialParam-class.html)).

- `"tilework.par_method"` - character (default = `"future"`). Either
  `"future"` or `"biocparallel"`. Which parallelization framework to
  use.

- `"tilework.bpparam"` - a {BiocParallel} parameter object. Set this to
  automatically use a specific BPPARAM, analogous to setting a
  [`future::plan()`](https://future.futureverse.org/reference/plan.html)
  for the {future} backend.

## See also

[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)

Other parallel settings:
[`tilework_management`](https://drieslab.github.io/tilework/reference/tilework_management.md)

## Examples

``` r
getTileworkParMethod()
#> [1] "future"

# Set to BiocParallel
setTileworkParMethod("biocparallel")
getTileworkParMethod()
#> [1] "biocparallel"

if (FALSE) { # \dontrun{
# Using future backend with multisession
future::plan(future::multisession, workers = 4)
tileApply(x, tiles, fun)

# Using BiocParallel backend
setTileworkParMethod("biocparallel")
options(tilework.bpparam = BiocParallel::SnowParam(workers = 4))
tileApply(x, tiles, fun)

# Or override per-call
setTileworkParMethod("future")  # global default is future
tileApply(x, tiles, fun, 
    parallel_params = list(method = "biocparallel")
) # but use BiocParallel here

# Suppress sequential warnings
options(tilework.warn_sequential = FALSE)
} # }
```
