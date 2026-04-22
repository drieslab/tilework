# tilework management

A set of utilities to control the location and naming of automated
tilework outputs. These are mostly to do with logging information right
now.

## Usage

``` r
getTileworkLogDir()

setTileworkLogDir(path)

getTileworkJobID(advance = FALSE)
```

## Arguments

- path:

  directory path to use

- advance:

  logical (default = FALSE). Whether to consume this job ID

## Value

`getTileworkLogDir` the logging directory to use

`setTileworkLogDir` returns the previous logging directory invisibly

`getTileworkJobID` returns the next job ID to use. If `advance = FALSE`
this call will be treated as a peek and will not consume the ID.

## See also

Other parallel settings:
[`parallel_params`](https://drieslab.github.io/tilework/reference/parallel_params.md)
