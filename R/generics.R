# exported generics
setGeneric("tileApply", function(x, y, tiles, ...) standardGeneric("tileApply"))
setGeneric("getTile", function(x, tiles, ...) standardGeneric("getTile"))
setGeneric("iterSplit", function(tiles, ...) standardGeneric("iterSplit"))
setGeneric("getBoundedData", function(x, bound, ...) standardGeneric("getBoundedData"))

# internal generics
setGeneric("redispatch_tileapply", function(sig, tiles, ...) standardGeneric("redispatch_tileapply"))
