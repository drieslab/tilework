
# Test tilePlan factory function ####
test_that("tilePlan factory function works correctly", {
    # Test spatial type
    spatial_plan <- tilePlan("spatial")
    expect_s4_class(spatial_plan, "spatialTilePlan")
    expect_s4_class(spatial_plan, "tilePlan")
    expect_s4_class(spatial_plan, "giottoTile")

    # Test pixel type
    pixel_plan <- tilePlan("pixel")
    expect_s4_class(pixel_plan, "pixelTilePlan")
    expect_s4_class(pixel_plan, "tilePlan")
    expect_s4_class(pixel_plan, "giottoTile")

    # Test invalid type
    expect_error(tilePlan("invalid"), "should be one of")
})

# Test spatialTilePlan ####
describe("spatialTilePlan", {

    test_that("initialization works correctly", {
        tp <- tilePlan("spatial")

        # Empty plan should have zero tiles
        expect_equal(length(tp), 0)
        expect_equal(dim(tp), c(0, 0))
        expect_equal(nrow(tp), 0)
        expect_equal(ncol(tp), 0)

        # Should have empty metadata
        expect_s4_class(tp@metadata, "data.frame")
        expect_equal(nrow(tp@metadata), 0)

        # Default padding should be 0
        expect_equal(tp@pad, 0)
    })

    test_that("extent setting and getting works", {
        tp <- tilePlan("spatial")

        # Test setting extent
        test_extent <- ext(0, 100, 0, 100)
        ext(tp) <- test_extent

        # Test getting extent
        retrieved_ext <- ext(tp)
        expect_s4_class(retrieved_ext, "SpatExtent")
        expect_equal(as.vector(retrieved_ext), as.vector(test_extent))

        # Test error when no extent set
        empty_tp <- tilePlan("spatial")
        expect_error(ext(empty_tp), "No extent set")
    })

    test_that("tile generation works correctly", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 9

        # Should generate at least requested number of tiles
        expect_gte(length(tp), 9)
        expect_gt(nrow(tp), 0)
        expect_gt(ncol(tp), 0)

        # Metadata should be created
        expect_equal(nrow(tp@metadata), length(tp))
        expect_true("tile" %in% colnames(tp@metadata))
        expect_equal(tp@metadata$tile, seq_len(length(tp)))
    })

    test_that("tile indexing works correctly", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 25 # Should create 5x5 grid

        # Test single tile extraction
        tile1 <- tp[1]
        expect_type(tile1, "list")
        expect_length(tile1, 1)
        expect_s4_class(tile1[[1]], "SpatExtent")

        # Test i,j indexing
        tile_ij <- tp[1, 2]
        expect_type(tile_ij, "list")
        expect_length(tile_ij, 1)

        # Test multiple tile extraction
        tiles <- tp[1:2]
        expect_type(tiles, "list")
        expect_length(tiles, 2)
        expect_length(tp[1:3], 3)
        expect_length(tp[1:2, 1:3], 6)
        expect_length(tp[2, 1:3], 3)

        # Test full extraction
        all_tiles <- tp[]
        expect_type(all_tiles, "list")
        expect_length(all_tiles, length(tp))

        # Test out of bounds
        expect_error(tp[100], "subscript out of bounds")
    })

    test_that("metadata operations work", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 4

        # Test setting custom metadata
        tp$test_meta <- sprintf("tile_%d", tp$tile)
        expect_equal(tp$test_meta, sprintf("tile_%d", 1:length(tp)))

        # Test getting metadata for specific tiles
        meta1 <- tp[[1]]
        expect_s3_class(meta1, "data.frame")
        expect_equal(nrow(meta1), 1)
        expect_true("tile" %in% colnames(meta1))
        expect_true("test_meta" %in% colnames(meta1))

        # Test metadata attributes on extracted tiles
        tile_with_meta <- tp[1][[1]]
        expect_equal(attr(tile_with_meta, "tile"), 1)
        expect_equal(attr(tile_with_meta, "test_meta"), "tile_1")
    })

    test_that("padding operations work", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 4

        # Test getting/setting pad value
        expect_equal(tp$pad, 0)
        tp$pad <- 5
        expect_equal(tp$pad, 5)

        # Test arithmetic padding
        tp_padded <- tp + 10
        expect_equal(tp_padded@pad, 15)

        tp_reduced <- tp - 3
        expect_equal(tp_reduced@pad, 2)

        # Original should be unchanged
        expect_equal(tp@pad, 5)

        # test extraction is padded
        a <- tilePlan("spatial")
        ext(a) <- c(0, 1000, 0, 1000)
        length(a) <- 20
        b <- a + 5

        e1 <- a[1]
        e2 <- b[1]
        expect_equal(e1[[1]][] + c(-5, 5, -5, 5), e2[[1]][])
    })

    test_that("centroids calculation works", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 4

        centroids_result <- centroids(tp)
        expect_s4_class(centroids_result, "SpatVector")
        expect_equal(nrow(centroids_result), length(tp))
    })
})

# Test pixelTilePlan ####
describe("pixelTilePlan", {

    test_that("initialization works correctly", {
        tp <- tilePlan("pixel")

        # Empty plan should have zero tiles
        expect_equal(length(tp), 0)
        expect_equal(dim(tp), c(0, 0))

        # Should have empty pixel dimensions
        expect_equal(length(tp@pxdims), 0)
        expect_equal(tp@tile_dims, c(0, 0))
    })

    test_that("pixel dimension setting works", {
        tp <- tilePlan("pixel")

        # Test setting pixel dimensions
        tp$pxdims <- c(100, 100)
        expect_equal(tp@pxdims, c(100, 100))
        expect_equal(tp$pxdims, c(100, 100))

        # Should still have no tiles without tile dimensions
        expect_equal(length(tp), 0)
    })

    test_that("tile dimension setting works", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)

        # Test setting both nrows and ncols
        tp$nrows <- 20
        tp$ncols <- 25
        expect_equal(tp$nrows, 20)
        expect_equal(tp$ncols, 25)
        expect_equal(tp@tile_dims, c(20, 25))

        # Should generate correct number of tiles
        expected_tiles <- ceiling(100/20) * ceiling(100/25) # 5 * 4 = 20
        expect_equal(length(tp), expected_tiles)
        expect_equal(dim(tp), c(5, 4))
    })

    test_that("automatic tile dimension filling works", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)

        # Setting only ncols should copy to nrows
        tp$ncols <- 20
        expect_equal(tp$nrows, 20)
        expect_equal(tp$ncols, 20)

        # Reset and test the other way
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)
        tp$nrows <- 25
        expect_equal(tp$nrows, 25)
        expect_equal(tp$ncols, 25)
    })

    test_that("pixel tile indexing works correctly", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)
        tp$nrows <- 20
        tp$ncols <- 20

        # Test single tile extraction (returns pixel bounds)
        tile1 <- tp[1]
        expect_type(tile1, "list")
        expect_length(tile1, 1)
        expect_type(tile1[[1]], "integer")
        expect_length(tile1[[1]], 4) # xmin, xmax, ymin, ymax

        # Test multi tile extraction
        expect_length(tp[1:3], 3)
        expect_length(tp[1:2, 1:3], 6)
        expect_length(tp[2, 1:3], 3)

        # Check bounds are reasonable
        bounds <- tile1[[1]]
        expect_true(all(bounds > 0))
        expect_true(bounds[2] > bounds[1]) # xmax > xmin
        expect_true(bounds[4] > bounds[3]) # ymax > ymin

        # Test i,j indexing
        tile_22 <- tp[2, 2]
        expect_type(tile_22, "list")
        expect_length(tile_22, 1)
        bounds_22 <- tile_22[[1]]

        # Second row, second column should have different bounds
        expect_false(identical(bounds, bounds_22))
    })

    test_that("pixel tile padding works correctly", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)
        tp$nrows <- 20
        tp$ncols <- 20

        # Get original bounds
        original_tile <- tp[1][[1]]

        # Add padding
        tp_padded <- tp + 5
        padded_tile <- tp_padded[1][[1]]

        # Padded tile should have expanded bounds but zeroed out
        # (pixel tiles zero out padding effects)
        expect_type(padded_tile, "integer")
        expect_length(padded_tile, 4)

        # test extracted bounds are padded
        a <- tilePlan("pixel")
        a$pxdims <- c(1000, 1000)
        a$ncols <- 100
        a$nrows <- 100
        b <- a + 5

        e1 <- a[1]
        e2 <- b[1]
        expect_equal(e1[[1]][] + c(0, 10, 0, 10), e2[[1]][])
    })

    test_that("pixel centroids work correctly", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)
        tp$nrows <- 20
        tp$ncols <- 20

        centroids_result <- centroids(tp)
        expect_type(centroids_result, "double")
        expect_true(is.matrix(centroids_result))
        expect_equal(nrow(centroids_result), length(tp))
        expect_equal(ncol(centroids_result), 2) # x, y coordinates
    })
})

# Test common tilePlan functionality ####
describe("Common tilePlan functionality", {

    # Helper function to create test plans
    create_test_plans <- function() {
        # Spatial plan
        spatial <- tilePlan("spatial")
        ext(spatial) <- c(0, 100, 0, 100)
        length(spatial) <- 9

        # Pixel plan
        pixel <- tilePlan("pixel")
        pixel$pxdims <- c(100, 100)
        pixel$nrows <- 20
        pixel$ncols <- 20

        list(spatial = spatial, pixel = pixel)
    }

    test_that("show methods work", {
        plans <- create_test_plans()

        # Should not error when printing
        expect_output(show(plans$spatial))
        expect_output(show(plans$pixel))
    })

    test_that("dimension methods work consistently", {
        plans <- create_test_plans()

        for(plan in plans) {
            # Basic dimension checks
            expect_type(length(plan), "integer")
            expect_type(nrow(plan), "integer")
            expect_type(ncol(plan), "integer")
            expect_length(dim(plan), 2)

            # Consistency checks
            expect_equal(length(plan), nrow(plan) * ncol(plan))
            expect_equal(dim(plan), c(nrow(plan), ncol(plan)))
            expect_gt(length(plan), 0)
        }
    })

    test_that("metadata system works consistently", {
        plans <- create_test_plans()

        for(plan in plans) {
            # Default metadata should exist
            expect_true("tile" %in% colnames(plan@metadata))
            expect_equal(plan$tile, seq_len(length(plan)))

            # Custom metadata should work
            plan$custom <- paste0("value_", plan$tile)
            expect_equal(plan$custom, paste0("value_", seq_len(length(plan))))

            # Metadata extraction should work
            meta_subset <- plan[[1:3]]
            expect_s3_class(meta_subset, "data.frame")
            expect_equal(nrow(meta_subset), 3)
            expect_true("custom" %in% colnames(meta_subset))
        }
    })

    test_that("arithmetic operations work consistently", {
        plans <- create_test_plans()

        for(plan in plans) {
            original_pad <- plan@pad

            # Test addition
            plan_plus <- plan + 5
            expect_equal(plan_plus@pad, original_pad + 5)
            expect_equal(plan@pad, original_pad) # Original unchanged

            # Test subtraction
            plan_minus <- plan - 3
            expect_equal(plan_minus@pad, original_pad - 3)

            # Test chaining
            plan_chain <- plan + 10 - 2
            expect_equal(plan_chain@pad, original_pad + 8)
        }
    })

    test_that("indexing edge cases are handled", {
        plans <- create_test_plans()

        for(plan in plans) {
            # Test empty extraction
            empty <- plan[integer(0)]
            expect_type(empty, "list")
            expect_length(empty, 0)

            # Test out of bounds
            expect_error(plan[length(plan) + 1], "subscript out of bounds")
            expect_error(plan[0], "subscript out of bounds")
            expect_error(plan[-1], "subscript out of bounds")

            # Test NA indices
            expect_error(plan[NA_integer_], "may not be NA")
            expect_error(plan[1, NA_integer_], "may not be NA")
        }
    })
})

# Test error conditions ####
describe("Error handling", {

    test_that("spatialTilePlan validates extent", {
        tp <- tilePlan("spatial")

        # Invalid extent length
        expect_error({
            tp@extent <- c(1, 2, 3) # Only 3 values
            initialize(tp)
        }, "invalid extent information")
    })

    test_that("pixelTilePlan validates dimensions", {
        tp <- tilePlan("pixel")

        # Should error with non-integer pixel dimensions
        expect_error({
            tp$pxdims <- c(100.5, 100.5)
        })

        # Should error with wrong length
        expect_error({
            tp$pxdims <- c(100, 100, 100)
        })
    })

    test_that("plotting requires tiles", {
        tp <- tilePlan("spatial")
        # No extent or tiles set

        expect_error(plot(tp), "No tiles to plot")
    })

    test_that("centroids require valid plan", {
        tp <- tilePlan("spatial")
        # No extent set

        expect_error(centroids(tp), "No extent set")
    })
})

describe("Integration scenarios", {

    test_that("workflow: spatial plan creation to tile extraction", {
        # Create plan
        tp <- tilePlan("spatial")
        expect_s4_class(tp, "spatialTilePlan")

        # Set extent
        ext(tp) <- c(0, 1000, 0, 1000)

        # Request tiles
        length(tp) <- 16
        expect_gte(length(tp), 16)

        # Add metadata
        tp$filename <- sprintf("tile_%03d.tif", tp$tile)
        expect_length(tp$filename, length(tp))

        # Extract tiles with metadata
        tiles <- tp[1:4]
        expect_length(tiles, 4)
        expect_equal(attr(tiles[[1]], "filename"), "tile_001.tif")

        # Add padding and extract
        tp_padded <- tp + 50
        padded_tiles <- tp_padded[1:2]
        expect_length(padded_tiles, 2)

        # Centroids
        centers <- centroids(tp)
        expect_s4_class(centers, "SpatVector")
        expect_equal(nrow(centers), length(tp))
    })

    test_that("workflow: pixel plan creation to bounds extraction", {
        # Create plan
        tp <- tilePlan("pixel")
        expect_s4_class(tp, "pixelTilePlan")

        # Set dimensions
        tp$pxdims <- c(1000, 1000)
        tp$nrows <- 100
        tp$ncols <- 100

        expected_tiles <- ceiling(1000/100) * ceiling(1000/100) # 10 * 10 = 100
        expect_equal(length(tp), expected_tiles)
        expect_equal(dim(tp), c(10, 10))

        # Add custom metadata
        tp$process_order <- sample(length(tp))
        expect_length(tp$process_order, length(tp))

        # Extract pixel bounds
        bounds <- tp[1:5]
        expect_length(bounds, 5)
        expect_true(all(sapply(bounds, is.integer)))
        expect_true(all(sapply(bounds, function(x) length(x) == 4)))

        # Test i,j indexing
        corner_tiles <- tp[c(1, 10), c(1, 10)] # corners
        expect_length(corner_tiles, 4)

        # Centroids as matrix
        centers <- centroids(tp)
        expect_true(is.matrix(centers))
        expect_equal(dim(centers), c(length(tp), 2))
    })
})
