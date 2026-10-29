# tilework (development version)

* `quadtreePlan()` without `tiles` no longer fails when the data's extent has zero width or height (a single point, or points all on one line): it starts from one tile, and a spatial `tilePlan` over such an extent lays its tiles along the other side. Other extents plan as before.
* Outer edges of the last row and column of a spatial `tilePlan` (also in `as.polygons()` and `intersect()` with a `SpatVector`) are set to the plan extent maximum, so data on the top and right extent edges is included in tiles.
* `tileApply()` with a `tileIterator` no longer fails with `argument "X" is missing` when the parallel backend has more than one worker.

# tilework 1.0.0

* Initial CRAN release.
