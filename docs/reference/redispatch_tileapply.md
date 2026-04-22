# *Developer API* Redispatch for `tileApply()`

Utility generic for modifying
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
calls for streamlining extension with new datatypes and forcing
datatype-specific handling to be added in the expected order.

**Why**

- `tileApply` is a framework function for parallelized computing across
  tiled data. It allows dispatch on up to 3 signatures (`x`, `y`, and
  `tile`), allowing flexibility, but at the cost of normally having to
  deal with combinatorial explosion of methods when extending with a new
  `x` and `y` datatype. Especially the case when considering
  compatibility with existing types and specific handling for different
  `tile` types.

- Setting specific methods using the following example dispatch chain is
  ambiguous, with it being unclear whether 1 or 2 is first and whether
  both will be reached before 3.

  1.  `(ANY, myclass, mytiles)`

  2.  `(myclass, ANY, mytiles)`

  3.  `(ANY, ANY, mytiles)`

`redispatch_tileapply()` solves the above problems by modifying
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
calls based on the classes of `x` and `y`, appropriate to the provided
`tile*` type.

This is done by passing `x` or `y` as input `sig` alongside the `tiles`
and dispatching on the combination, and properly routing changes when
they are `x` or `y` param specific based on the `param_xy`.

After a `sig` is processed, it is coerced to the
[token](https://drieslab.github.io/tilework/reference/token-class.md)
class signifying that it is ready for processing and the call is passed
back to
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
which can either proceed with eval or pass back to
`redispatch_tileapply` if `y` is also provided.

Only when `x` (for single input tileApply()) or `x` and `y` are all of
class `token`, does the
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
call fully evaluate.

**The default `ANY`, `ANY` method performs no modifications to the input
data or the call.**

## Usage

``` r
# S4 method for class 'SpatRaster,freeTilePlan'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'ANY,ANY'
redispatch_tileapply(
  sig,
  tiles,
  default_get_params = list(),
  param_xy,
  verbose = NULL,
  ...
)

# S4 method for class 'character,tileGroup'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'SpatVector,tileGroup'
redispatch_tileapply(sig, tiles, parallel_strategy = c("groups", "tiles"), ...)

# S4 method for class 'SpatRaster,tileGroup'
redispatch_tileapply(
  sig,
  tiles,
  param_xy,
  parallel_strategy = c("groups", "tiles"),
  ...
)

# S4 method for class 'ANY,tileGroup'
redispatch_tileapply(
  sig,
  tiles,
  default_get_params = list(),
  default_callback = NULL,
  param_xy,
  parallel_strategy = c("groups", "tiles"),
  verbose = NULL,
  ...
)

# S4 method for class 'character,tileIterator'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'SpatRaster,tileIterator'
redispatch_tileapply(sig, tiles, param_xy, ...)

# S4 method for class 'SpatVector,tileIterator'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'ANY,tileIterator'
redispatch_tileapply(
  sig,
  tiles,
  default_get_params = list(),
  default_callback = NULL,
  param_xy,
  verbose = NULL,
  ...
)

# S4 method for class 'character,tilePlan'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'SpatVector,spatialTilePlan'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'SpatRaster,spatialTilePlan'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'SpatRaster,pixelTilePlan'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'SpatRaster,pointTilePlan'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'character,tileSelection'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'SpatVector,tileSelection'
redispatch_tileapply(sig, tiles, ...)

# S4 method for class 'SpatRaster,tileSelection'
redispatch_tileapply(sig, tiles, ...)
```

## Arguments

- sig:

  data type to modify the
  [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
  call based on.

- tiles:

  tile\* object

- ...:

  additional params to pass

- default_get_params:

  internal use: list of default
  [`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
  parameters to use with this `sig`, passed from an upstream (likely
  more specific) `redispatch_tileapply()` method.

  Depending on `param_xy`, this list of defaults will be merged with
  `get_params_x` or `get_params_y` in `...`

  Duplicate entries in `default_get_params` will be ignored in favor of
  `get_params_x` or `get_params_y` contents.

- param_xy:

  character. Either "x" or "y" which param it is to modify dispatch on

- verbose:

  verbosity. `TRUE`, `FALSE` or `"debug"` for more info on stack
  tracing.

- default_callback:

  internal use: Default callback function passed from an upstream
  (likely more specific) `redispatch_tileapply()` method to use as
  `callback_x` or `callback_y` if none has been provided.

## Logic flow between [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md) and `redispatch_tileapply()`

**`x` only case:**

1.  `tileApply(ANY, missing, ANY, ...)`

2.  `redispatch_tileapply(mydata, mytiles, param_xy = "x", ...)`

3.  `redispatch_tileapply(ANY, ANY, param_xy = "x", ...)`

4.  `tileApply(token, missing, ANY, ...)`

5.  evaluation

**`x` and `y` case:**

1.  `tileApply(ANY, ANY, ANY)`

2.  `redispatch_tileapply(mydata1, mytiles, param_xy = "x")`

3.  `redispatch_tileapply(ANY, ANY, param_xy = "x", ...)`

4.  `tileApply(token, ANY, ANY)`

5.  `redispatch_tileapply(mydata2, mytiles, param_xy = "y")`

6.  `redispatch_tileapply(ANY, ANY, param_xy = "y", ...)`

7.  `tileApply(token, token, plan)`

8.  evaluation

**This allows:**

- Data type-specific preprocessing, checks, and additional params to be
  injected into the
  [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
  call without having to interact with the core
  [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
  logic for tilewise data selection and parallelization

- Avoid duplicating data type-specific handling code for each of the
  following
  [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
  signature types:

  - `(mydata, missing, tiles)`

  - `(mydata, ANY, tiles)`

  - `(token, mydata, tiles)`

Instead, extending developers only have to provide code for a single
`redispatch_tileapply(myclass, tiles)` signature, and
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
\<-\> `redispatch_tileapply()` calls will iteratively apply the
appropriate preprocessing and x or y routed params.

The `x` and `y` routing and `token` coercion are also handled by the
`redispatch_tileapply(ANY, ANY)` method.

## See also

Other tilework extension:
[`extending_tilework`](https://drieslab.github.io/tilework/reference/extending_tilework.md),
[`token-class`](https://drieslab.github.io/tilework/reference/token-class.md)
