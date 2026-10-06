# Tests for pointTilePlan

create_test_raster <- function(nrow = 100, ncol = 100, extent = c(0, 100, 0, 100)) {
    rast(nrows = nrow, ncols = ncol, extent = extent, vals = seq_len(nrow * ncol))
}

# Construction ####
describe("pointTilePlan construction", {
    test_that("factory creates correct class", {
        tp <- pointTilePlan("spatial")
        expect_s4_class(tp, "pointTilePlan")
        expect_s4_class(tp, "tilePlan")
        expect_s4_class(tp, "tilework")
    })

    test_that("empty plan has correct defaults", {
        tp <- pointTilePlan("spatial")
        expect_equal(length(tp), 0)
        expect_equal(tp@input, "spatial")
        expect_equal(tp@output, "spatial")
        expect_equal(tp@pad, 0)
        expect_equal(nrow(tp@metadata), 0)
    })

    test_that("output defaults to input", {
        tp_s <- pointTilePlan("spatial")
        expect_equal(tp_s@output, "spatial")

        tp_p <- pointTilePlan("pixel")
        expect_equal(tp_p@output, "pixel")
    })

    test_that("input and output can differ", {
        tp <- pointTilePlan(input = "spatial", output = "pixel")
        expect_equal(tp@input, "spatial")
        expect_equal(tp@output, "pixel")
    })

    test_that("coords + dims trigger correct initialization", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20, 30), y = c(5, 15, 25))
        tp$width  <- 5
        tp$height <- 5

        expect_equal(length(tp), 3L)
        expect_equal(nrow(tp), 3L)
        expect_equal(ncol(tp), 1L)
        expect_equal(dim(tp), c(3L, 1L))
        expect_equal(nrow(tp@metadata), 3L)
    })

    test_that("single tile_dims value is replicated", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = 10, y = 10)
        tp$width  <- 5
        expect_equal(tp@tile_dims, c(5, 5))
    })

    test_that("metadata auto-populates tile, x, y columns", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20), y = c(5, 15))
        tp$width  <- 4
        tp$height <- 4

        expect_true(all(c("tile", "x", "y") %in% colnames(tp@metadata)))
        expect_equal(tp@metadata$x, c(10, 20))
        expect_equal(tp@metadata$y, c(5, 15))
        expect_equal(tp@metadata$tile, c(1L, 2L))
    })
})

# $ accessors ####
describe("pointTilePlan $ accessors", {
    test_that("getters return correct values", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20), y = c(5, 15))
        tp$width  <- 6
        tp$height <- 4

        expect_equal(tp$width, 6)
        expect_equal(tp$height, 4)
        expect_equal(tp$ncols, 6)   # alias
        expect_equal(tp$nrows, 4)   # alias
        expect_equal(tp$input, "spatial")
        expect_equal(tp$output, "spatial")
        expect_equal(tp$coords, cbind(x = c(10, 20), y = c(5, 15)))
    })

    test_that("width/height and nrows/ncols aliases are equivalent setters", {
        tp1 <- pointTilePlan("spatial")
        tp1$coords <- cbind(x = 10, y = 10)
        tp1$width  <- 6
        tp1$height <- 4

        tp2 <- pointTilePlan("spatial")
        tp2$coords <- cbind(x = 10, y = 10)
        tp2$ncols <- 6
        tp2$nrows <- 4

        expect_equal(tp1@tile_dims, tp2@tile_dims)
    })

    test_that("$input<- reinitializes", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20), y = c(5, 15))
        tp$width <- 5
        tp$input <- "pixel"
        expect_equal(tp@input, "pixel")
        expect_equal(length(tp), 2L) # still initialized
    })

    test_that("$output<- does not reinitialize", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20), y = c(5, 15))
        tp$width <- 5
        tp$output <- "pixel"
        expect_equal(tp@output, "pixel")
        expect_equal(length(tp), 2L)
    })

    test_that("$coords<- coerces non-matrix to matrix", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = 10, y = 5)  # already matrix
        expect_true(is.matrix(tp@coords))

        tp2 <- pointTilePlan("spatial")
        tp2$coords <- data.frame(x = c(10, 20), y = c(5, 15))
        expect_true(is.matrix(tp2@coords))
    })

    test_that("$coords<- errors with wrong ncol", {
        tp <- pointTilePlan("spatial")
        expect_error(tp$coords <- matrix(1:6, ncol = 3), "n x 2 matrix")
    })

    test_that("$rast_dims<- and $extent<- set slots without reinitialize", {
        tp <- pointTilePlan("pixel")
        tp$coords <- cbind(x = c(20L, 50L), y = c(20L, 50L))
        tp$width  <- 11L
        tp$rast_dims <- c(100, 100)
        tp$extent    <- c(0, 100, 0, 100)

        expect_equal(tp$rast_dims, c(100, 100))
        expect_equal(tp$extent, c(0, 100, 0, 100))
        expect_equal(length(tp), 2L) # still valid
    })
})

# [ indexing ####
describe("pointTilePlan [ indexing", {
    test_that("spatial input returns SpatExtent", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(25, 75), y = c(25, 75))
        tp$width  <- 10
        tp$height <- 10

        b <- tp[1]
        expect_type(b, "list")
        expect_length(b, 1L)
        expect_s4_class(b[[1]], "SpatExtent")
    })

    test_that("spatial bounds are correctly centered on coords", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = 25, y = 25)
        tp$width  <- 10
        tp$height <- 10

        b <- tp[1][[1]][]
        expect_equal(b[["xmin"]], 20)
        expect_equal(b[["xmax"]], 30)
        expect_equal(b[["ymin"]], 20)
        expect_equal(b[["ymax"]], 30)
    })

    test_that("pixel input returns integer[4]", {
        tp <- pointTilePlan("pixel")
        tp$coords <- cbind(x = c(20L, 50L), y = c(20L, 50L))
        tp$width  <- 11L
        tp$height <- 11L

        b <- tp[1]
        expect_type(b, "list")
        expect_length(b, 1L)
        expect_type(b[[1]], "integer")
        expect_length(b[[1]], 4L)
    })

    test_that("pixel bounds are correctly centered on coords", {
        tp <- pointTilePlan("pixel")
        tp$coords <- cbind(x = 20L, y = 20L)
        tp$width  <- 11L
        tp$height <- 11L

        b <- tp[1][[1]]
        # center=20, half=5 → 15 to 25
        expect_equal(b[[1L]], 15L) # col_min
        expect_equal(b[[2L]], 25L) # col_max
        expect_equal(b[[3L]], 15L) # row_min
        expect_equal(b[[4L]], 25L) # row_max
    })

    test_that("multiple tiles return correct length", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20, 30, 40), y = c(10, 20, 30, 40))
        tp$width  <- 5
        tp$height <- 5

        expect_length(tp[1:3], 3L)
        expect_length(tp[], 4L)
    })

    test_that("out of bounds and NA errors are raised", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20), y = c(10, 20))
        tp$width  <- 5

        expect_error(tp[3], "subscript out of bounds")
        expect_error(tp[0], "subscript out of bounds")
        expect_error(tp[NA_integer_], "may not be NA")
    })

    test_that("metadata is attached as attributes", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20), y = c(5, 15))
        tp$width  <- 5
        tp$label  <- c("a", "b")

        b <- tp[2][[1]]
        expect_equal(attr(b, "tile"), 2L)
        expect_equal(attr(b, "label"), "b")
    })
})

# Padding ####
describe("pointTilePlan padding", {
    test_that("+ and - adjust pad value", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = 25, y = 25)
        tp$width  <- 10

        tp2 <- tp + 5
        expect_equal(tp2@pad, 5)
        expect_equal(tp@pad, 0) # original unchanged

        tp3 <- tp2 - 3
        expect_equal(tp3@pad, 2)
    })

    test_that("padding expands spatial bounds", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = 25, y = 25)
        tp$width  <- 10
        tp$height <- 10

        b_unpadded <- tp[1][[1]][]
        b_padded   <- (tp + 5)[1][[1]][]

        expect_equal(b_padded, b_unpadded + c(-5, 5, -5, 5))
    })

    test_that("pixel mode + enforces integerish padding", {
        tp <- pointTilePlan("pixel")
        tp$coords <- cbind(x = 20L, y = 20L)
        tp$width  <- 11L

        expect_error(tp + 1.5)
        expect_silent(tp + 2L)
    })
})

# centroids ####
describe("pointTilePlan centroids", {
    test_that("spatial input returns SpatVector", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20, 30), y = c(5, 15, 25))
        tp$width  <- 5

        ct <- centroids(tp)
        expect_s4_class(ct, "SpatVector")
        expect_equal(nrow(ct), 3L)
    })

    test_that("pixel input returns matrix", {
        tp <- pointTilePlan("pixel")
        tp$coords <- cbind(x = c(10L, 20L), y = c(10L, 20L))
        tp$width  <- 5L

        ct <- centroids(tp)
        expect_true(is.matrix(ct))
        expect_equal(nrow(ct), 2L)
        expect_equal(ncol(ct), 2L)
    })

    test_that("centroids match input coords", {
        coords <- cbind(x = c(10, 20, 30), y = c(5, 15, 25))
        tp <- pointTilePlan("spatial")
        tp$coords <- coords
        tp$width  <- 5

        ct <- terra::crds(centroids(tp))
        expect_equal(ct[, "x"], coords[, "x"])
        expect_equal(ct[, "y"], coords[, "y"])
    })
})

# show ####
describe("pointTilePlan show", {
    test_that("show works on empty plan", {
        tp <- pointTilePlan("spatial")
        expect_output(show(tp), "empty")
    })

    test_that("show works on populated plan", {
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(10, 20), y = c(5, 15))
        tp$width  <- 5
        expect_output(show(tp), "pointTilePlan")
    })
})

# getTile integration ####
describe("pointTilePlan getTile integration", {
    test_that("same-mode spatial: returns SpatRaster tiles", {
        r  <- create_test_raster(100, 100, c(0, 100, 0, 100))
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = c(25, 75), y = c(25, 75))
        tp$width  <- 20
        tp$height <- 20

        tiles <- getTile(r, tp, i = 1:2)
        expect_type(tiles, "list")
        expect_length(tiles, 2L)
        expect_s4_class(tiles[[1]], "SpatRaster")
    })

    test_that("same-mode pixel: returns SpatRaster tiles", {
        r  <- create_test_raster(100, 100)
        tp <- pointTilePlan("pixel")
        tp$coords <- cbind(x = c(25L, 75L), y = c(25L, 75L))
        tp$width  <- 11L
        tp$height <- 11L

        tiles <- getTile(r, tp, i = 1:2)
        expect_type(tiles, "list")
        expect_length(tiles, 2L)
        expect_s4_class(tiles[[1]], "SpatRaster")
        expect_equal(nrow(tiles[[1]]), 11L)
        expect_equal(ncol(tiles[[1]]), 11L)
    })

    test_that("cross-mode CRS->pixel: returns pixel-sized tiles", {
        r  <- create_test_raster(100, 100, c(0, 100, 0, 100))
        tp <- pointTilePlan(input = "spatial", output = "pixel")
        tp$coords <- cbind(x = c(25, 75), y = c(25, 75))
        tp$width  <- 11   # CRS units = 11 pixels at res 1
        tp$height <- 11

        tiles <- getTile(r, tp, i = 1:2)
        expect_length(tiles, 2L)
        expect_s4_class(tiles[[1]], "SpatRaster")
    })

    test_that("cross-mode pixel->CRS: returns SpatRaster tiles", {
        r  <- create_test_raster(100, 100, c(0, 100, 0, 100))
        tp <- pointTilePlan(input = "pixel", output = "spatial")
        tp$coords <- cbind(x = c(25L, 75L), y = c(25L, 75L))
        tp$width  <- 11L
        tp$height <- 11L

        tiles <- getTile(r, tp, i = 1:2)
        expect_length(tiles, 2L)
        expect_s4_class(tiles[[1]], "SpatRaster")
    })

    test_that("lyr parameter subsets layers", {
        r1 <- create_test_raster(100, 100)
        r2 <- create_test_raster(100, 100) * 2
        r  <- c(r1, r2)

        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = 50, y = 50)
        tp$width  <- 20
        tp$height <- 20

        tile_l1 <- getTile(r, tp, i = 1, lyr = 1)[[1]]
        tile_l2 <- getTile(r, tp, i = 1, lyr = 2)[[1]]

        expect_equal(terra::nlyr(tile_l1), 1L)
        expect_equal(terra::nlyr(tile_l2), 1L)
        expect_false(identical(as.vector(tile_l1), as.vector(tile_l2)))
    })

    test_that("pad parameter is applied at getTile time", {
        r  <- create_test_raster(100, 100, c(0, 100, 0, 100))
        tp <- pointTilePlan("spatial")
        tp$coords <- cbind(x = 50, y = 50)
        tp$width  <- 10
        tp$height <- 10

        tile_no_pad <- getTile(r, tp, i = 1)[[1]]
        tile_padded <- getTile(r, tp, i = 1, pad = 5)[[1]]

        expect_gt(nrow(tile_padded), nrow(tile_no_pad))
        expect_gt(ncol(tile_padded), ncol(tile_no_pad))
        expect_equal(tp@pad, 0) # plan unchanged
    })
})
