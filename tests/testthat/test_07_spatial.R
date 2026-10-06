# as.polygons ####

describe("as.polygons", {

    test_that("spatialTilePlan produces correct polygon count and extent", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 9)
        sv <- as.polygons(tp)
        expect_s4_class(sv, "SpatVector")
        expect_equal(nrow(sv), length(tp))
        expect_equal(unname(as.vector(terra::ext(sv))), c(0, 100, 0, 100))
        expect_equal(sv$tile, seq_len(length(tp)))
    })

    test_that("spatialTilePlan respects padding", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 4) + 5
        sv <- as.polygons(tp)
        e <- unname(as.vector(terra::ext(sv)))
        expect_true(e[[1L]] < 0)   # xmin expanded
        expect_true(e[[2L]] > 100) # xmax expanded
        expect_true(e[[3L]] < 0)   # ymin expanded
        expect_true(e[[4L]] > 100) # ymax expanded
    })

    test_that("spatialTilePlan empty returns empty SpatVector", {
        tp <- spatialTilePlan()
        sv <- as.polygons(tp)
        expect_s4_class(sv, "SpatVector")
        expect_equal(nrow(sv), 0L)
    })

    test_that("freeTilePlan produces correct polygon count and bounds", {
        fp <- freeTilePlan()
        fp$bounds <- rbind(
            c(0,  50,  0,  50),
            c(50, 100, 0,  50),
            c(0,  50,  50, 100),
            c(50, 100, 50, 100)
        )
        sv <- as.polygons(fp)
        expect_s4_class(sv, "SpatVector")
        expect_equal(nrow(sv), 4L)
        expect_equal(unname(as.vector(terra::ext(sv))), c(0, 100, 0, 100))
        expect_equal(sv$tile, 1:4)
    })

    test_that("freeTilePlan respects padding", {
        fp <- freeTilePlan()
        fp$bounds <- matrix(c(10, 20, 10, 20), nrow = 1L)
        fp <- fp + 2
        sv <- as.polygons(fp)
        e <- unname(as.vector(terra::ext(sv)))
        expect_equal(e, c(8, 22, 8, 22))
    })

    test_that("freeTilePlan empty returns empty SpatVector", {
        fp <- freeTilePlan()
        sv <- as.polygons(fp)
        expect_s4_class(sv, "SpatVector")
        expect_equal(nrow(sv), 0L)
    })

    test_that("pointTilePlan spatial/spatial produces correct bounds", {
        tp <- pointTilePlan("spatial")
        tp$coords <- matrix(c(10, 20, 10, 20), ncol = 2L)
        tp$width  <- 4; tp$height <- 4
        sv <- as.polygons(tp)
        expect_s4_class(sv, "SpatVector")
        expect_equal(nrow(sv), 2L)
        e1 <- unname(as.vector(terra::ext(sv[1L, ])))
        expect_equal(e1, c(8, 12, 8, 12))
    })

})


# intersect ####

describe("intersect", {

    test_that("spatialTilePlan returns tileSelection", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 16)
        sel <- intersect(tp, terra::ext(20, 60, 20, 60))
        expect_s4_class(sel, "tileSelection")
    })

    test_that("spatialTilePlan central query hits correct tiles", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 4) # 2x2, tiles 50 wide
        # query strictly inside the top-right quadrant (shared boundary at 50 would
        # touch adjacent tiles due to inclusive edge semantics)
        sel <- intersect(tp, terra::ext(51, 99, 51, 99))
        expect_equal(length(sel), 1L)
    })

    test_that("spatialTilePlan full-extent query hits all tiles", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 9)
        sel <- intersect(tp, terra::ext(0, 100, 0, 100))
        expect_equal(length(sel), length(tp))
    })

    test_that("spatialTilePlan out-of-bounds query returns empty", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 9)
        sel <- intersect(tp, terra::ext(200, 300, 200, 300))
        expect_equal(length(sel), 0L)
    })

    test_that("spatialTilePlan padding extends reach", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 4) # 2x2, tiles 50 wide
        # query just outside top-right tile without padding
        sel_no_pad <- intersect(tp, terra::ext(101, 110, 101, 110))
        expect_equal(length(sel_no_pad), 0L)
        # with padding the corner tile is reached
        sel_pad <- intersect(tp + 15, terra::ext(101, 110, 101, 110))
        expect_equal(length(sel_pad), 1L)
    })

    test_that("freeTilePlan returns tileSelection", {
        fp <- freeTilePlan()
        fp$bounds <- rbind(
            c(0,  50,  0,  50),
            c(50, 100, 0,  50),
            c(0,  50,  50, 100),
            c(50, 100, 50, 100)
        )
        sel <- intersect(fp, terra::ext(40, 60, 40, 60))
        expect_s4_class(sel, "tileSelection")
        expect_equal(length(sel), 4L) # centre touches all 4
    })

    test_that("freeTilePlan out-of-bounds query returns empty", {
        fp <- freeTilePlan()
        fp$bounds <- matrix(c(0, 50, 0, 50), nrow = 1L)
        sel <- intersect(fp, terra::ext(100, 200, 100, 200))
        expect_equal(length(sel), 0L)
    })

    test_that("SpatVector polygon query subsets correctly", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 4) # 2x2
        # diagonal polygon covering only bottom-left tile
        corners <- rbind(c(0, 0), c(40, 0), c(40, 40), c(0, 40), c(0, 0))
        poly <- terra::vect(corners, type = "polygons")
        sel <- intersect(tp, poly)
        expect_true(length(sel) >= 1L)
        # all returned tiles must actually overlap the polygon
        tile_sv <- as.polygons(tp)[sel$tile, ]
        hits <- terra::relate(tile_sv, poly, relation = "intersects")
        expect_true(all(as.logical(hits)))
    })

    test_that("$tile metadata accessible on result", {
        tp <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 9)
        sel <- intersect(tp, terra::ext(0, 100, 0, 100))
        expect_equal(sort(sel$tile), seq_len(length(tp)))
    })

})
