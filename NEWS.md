# tilework (development version)

* Outer edges of the last row and column of a spatial `tilePlan` (also in `as.polygons()` and `intersect()` with a `SpatVector`) are set to the plan extent maximum, so data on the top and right extent edges is included in tiles.
* `tileApply()` with a `tileIterator` no longer fails with `argument "X" is missing` when the parallel backend has more than one worker.

# tilework 1.0.0

* Initial CRAN release.
