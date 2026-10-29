# quadtreePlan starting grid ####

# quadtreePlan reads SpatVector data from disk (a proxy)
.disk_pts <- function(xy) {
    f <- tempfile(fileext = ".shp")
    terra::writeVector(terra::vect(xy), f)
    terra::vect(f, proxy = TRUE)
}

describe("quadtreePlan starting grid", {

    test_that("seed tile count is four per unit of aspect ratio", {
        expect_equal(.seed_tile_count(c(100, 50)), 8)
        expect_equal(.seed_tile_count(c(10, 10)), 4)
        expect_equal(.seed_tile_count(c(30, 100)), 12)
    })

    test_that("a zero width or height starts from one tile", {
        expect_identical(.seed_tile_count(c(0, 10)), 1L)
        expect_identical(.seed_tile_count(c(10, 0)), 1L)
        expect_identical(.seed_tile_count(c(0, 0)), 1L)
    })

    test_that("a spatial tilePlan over a zero-length side has defined dims", {
        expect_equal(.get_dim_n_chunks(4, terra::ext(5, 5, 0, 10)), c(4, 1))
        expect_equal(.get_dim_n_chunks(4, terra::ext(0, 10, 5, 5)), c(1, 4))
        expect_equal(.get_dim_n_chunks(1, terra::ext(5, 5, 3, 3)), c(1, 1))
        tp <- tilePlan("spatial")
        ext(tp) <- terra::ext(5, 5, 0, 10)
        length(tp) <- 1L
        expect_equal(length(tp), 1L)
    })

    test_that("a single point plans one tile", {
        pts <- .disk_pts(cbind(x = 5, y = 3))
        fp <- quadtreePlan(pts, threshold = 10)
        expect_equal(length(fp), 1L)
        expect_equal(fp$n_records, 1)
    })

    test_that("points on one vertical line plan one tile when under threshold", {
        pts <- .disk_pts(cbind(x = rep(5, 6), y = 0:5))
        fp <- quadtreePlan(pts, threshold = 10)
        expect_equal(length(fp), 1L)
        expect_equal(fp$n_records, 6)
        expect_equal(unname(fp$bounds[1, ]), c(5, 5, 0, 5))
    })

    test_that("a regular extent plans as before", {
        set.seed(1)
        pts <- .disk_pts(cbind(x = runif(400, 0, 100), y = runif(400, 0, 50)))
        seed <- tilePlan("spatial")
        ext(seed) <- ext(pts)
        erange <- range(ext(seed))
        length(seed) <- round(max(erange) / min(erange)) * 4L
        expect_identical(quadtreePlan(pts, threshold = 60)$bounds,
            quadtreePlan(pts, tiles = seed, threshold = 60)$bounds)
    })
})
