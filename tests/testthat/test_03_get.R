# Integration tests for tilePlan with other GiottoTile components
# Tests interactions with getTile, getBoundedData, tileGroup, and tileIterator


# Helper function to create test raster
create_test_raster <- function(nrow = 100, ncol = 100, extent = c(0, 100, 0, 100)) {
    r <- rast(nrows = nrow, ncols = ncol, extent = extent, vals = 1:(nrow*ncol))
    return(r)
}

# Test tilePlan with getTile ####
describe("tilePlan with getTile", {

    test_that("spatialTilePlan works with SpatRaster getTile", {
        # Create test data
        r <- create_test_raster()
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Create spatial tile plan
        tp <- tilePlan("spatial")
        ext(tp) <- ext(r)
        length(tp) <- 4

        # Test getTile with filepath
        tiles_from_file <- getTile(temp_file, tp, i = 1:2)
        expect_type(tiles_from_file, "list")
        expect_length(tiles_from_file, 2)
        expect_s4_class(tiles_from_file[[1]], "SpatRaster")

        # Test getTile with SpatRaster object
        tiles_from_raster <- getTile(r, tp, i = 1:2)
        expect_type(tiles_from_raster, "list")
        expect_length(tiles_from_raster, 2)
        expect_s4_class(tiles_from_raster[[1]], "SpatRaster")

        # Results should be equivalent
        expect_equal(as.vector(tiles_from_file[[1]]), as.vector(tiles_from_raster[[1]]))

        unlink(temp_file)
    })

    test_that("pixelTilePlan works with SpatRaster getTile", {
        # Create test data
        r <- create_test_raster(50, 50)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Create pixel tile plan
        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 10
        tp$ncols <- 10

        # Test getTile
        tiles <- getTile(temp_file, tp, i = 1:3)
        expect_type(tiles, "list")
        expect_length(tiles, 3)
        expect_s4_class(tiles[[1]], "SpatRaster")

        # Check tile dimensions
        expect_equal(nrow(tiles[[1]]), 10)
        expect_equal(ncol(tiles[[1]]), 10)

        unlink(temp_file)
    })

    test_that("getTile respects tilePlan padding", {
        r <- create_test_raster(50, 50)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Create pixel plan with padding
        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 10
        tp$ncols <- 10
        tp_padded <- tp + 2

        # Compare tiles with and without padding
        tile_normal <- getTile(temp_file, tp, i = 5, extend = TRUE)[[1]]
        tile_padded <- getTile(temp_file, tp_padded, i = 5, extend = TRUE)[[1]]

        # Padded tile should be larger
        expect_gt(nrow(tile_padded), nrow(tile_normal))
        expect_gt(ncol(tile_padded), ncol(tile_normal))

        unlink(temp_file)
    })

    test_that("getTile handles layer selection", {
        # Create multi-layer raster
        r1 <- create_test_raster(50, 50)
        r2 <- create_test_raster(50, 50) * 2
        r_multi <- c(r1, r2)
        names(r_multi) <- c("layer1", "layer2")

        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r_multi, temp_file, overwrite = TRUE)

        tp <- tilePlan("spatial")
        ext(tp) <- ext(r_multi)
        length(tp) <- 4

        # Test getting specific layers
        tiles_layer1 <- getTile(temp_file, tp, i = 1, lyr = 1)[[1]]
        tiles_layer2 <- getTile(temp_file, tp, i = 1, lyr = 2)[[1]]

        expect_equal(terra::nlyr(tiles_layer1), 1)
        expect_equal(terra::nlyr(tiles_layer2), 1)

        # Values should be different
        expect_false(identical(as.vector(tiles_layer1), as.vector(tiles_layer2)))

        unlink(temp_file)
    })
})

# Test tilePlan with getBoundedData ####
describe("tilePlan with getBoundedData", {

    test_that("tilePlan bounds work with getBoundedData", {
        r <- create_test_raster()

        # Create spatial plan
        tp <- tilePlan("spatial")
        ext(tp) <- ext(r)
        length(tp) <- 9

        # Get bounds from tilePlan
        tile_bounds <- tp[1][[1]]

        # Use bounds with getBoundedData
        bounded_data <- getBoundedData(r, tile_bounds)
        expect_s4_class(bounded_data, "SpatRaster")
        expect_gt(terra::ncell(bounded_data), 0)

        # Extent should match bounds
        bounded_ext <- ext(bounded_data)
        # without round, these will be different due to pixel limits
        expect_equal(round(as.vector(bounded_ext)), round(as.vector(tile_bounds)))
    })

    test_that("pixel bounds work with getBoundedData", {
        r <- create_test_raster(100, 100)

        # Create pixel plan
        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 20
        tp$ncols <- 20

        # Get pixel bounds
        pixel_bounds <- tp[1][[1]]

        # Use with getBoundedData
        bounded_data <- getBoundedData(r, pixel_bounds, tiles = tp)
        expect_s4_class(bounded_data, "SpatRaster")
        expect_equal(nrow(bounded_data), 20)
        expect_equal(ncol(bounded_data), 20)
    })

    test_that("getBoundedData respects extend parameter", {
        r <- create_test_raster(95, 95) # Odd dimensions to test edge tiles

        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 20
        tp$ncols <- 20

        # Get edge tile that might not fill completely
        edge_bounds <- tp[length(tp)][[1]] # Last tile

        # Without extend
        tile_no_extend <- getBoundedData(r, edge_bounds, tiles = tp, extend = FALSE)

        # With extend
        tile_with_extend <- getBoundedData(r, edge_bounds, tiles = tp, extend = TRUE)

        # Extended tile should be exactly tile size
        expect_equal(nrow(tile_with_extend), 20)
        expect_equal(ncol(tile_with_extend), 20)

        # Non-extended might be smaller
        expect_lte(nrow(tile_no_extend), 20)
        expect_lte(ncol(tile_no_extend), 20)
    })
})

# Test tilePlan with tileGroup ####
describe("tilePlan with tileGroup", {

    test_that("tileGroup creation with tilePlan", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 16 # 4x4 grid

        # Create groups
        tg <- tileGroup(tp, groups = list(
            "corners" = c(1, 4, 13, 16),
            "edges" = c(2, 3, 5, 8, 9, 12, 14, 15),
            "center" = c(6, 7, 10, 11)
        ))

        expect_s4_class(tg, "tileGroup")
        expect_equal(length(tg), 3) # 3 groups

        # Test group access
        corner_bounds <- tg[, "corners"]
        expect_type(corner_bounds, "list")
        expect_length(corner_bounds, 4)

        # Test with active group
        tg$active <- "center"
        expect_equal(length(tg), 4) # 4 tiles in center group

        center_tile <- tg[1]
        expect_type(center_tile, "list")
        expect_length(center_tile, 1)
    })

    test_that("tileGroup works with getTile", {
        r <- create_test_raster()
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("spatial")
        ext(tp) <- ext(r)
        length(tp) <- 9

        tg <- tileGroup(tp, groups = list(
            "first_half" = 1:4,
            "second_half" = 5:9
        ))

        # Test getTile with group
        tg$active <- "first_half"
        group_tiles <- getTile(temp_file, tg, i = 1:2)
        expect_type(group_tiles, "list")
        expect_length(group_tiles, 2)

        unlink(temp_file)
    })
})

# Test tilePlan with tileIterator ####
describe("tilePlan with tileIterator", {

    test_that("tileIterator creation with tilePlan", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 16

        # Create iterator
        iter <- tileIterator(tp, batch_size = 4)
        expect_s4_class(iter, "tileIterator")
        expect_equal(iter$batch_size, 4)
        expect_equal(iter$total_tiles, 16)
        expect_true(iter$has_next)

        # Test batch retrieval
        batch1 <- iter$next_batch()
        expect_type(batch1, "list")
        expect_length(batch1, 4)

        # Check progress
        expect_equal(iter$position, 4)
        expect_equal(iter$remaining, 12)
    })

    test_that("tileIterator works with getTile", {
        r <- create_test_raster(60, 60)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 20
        tp$ncols <- 20

        iter <- tileIterator(tp, batch_size = 2)

        # Test getTile with iterator
        batch_tiles <- getTile(temp_file, iter)
        expect_type(batch_tiles, "list")
        expect_length(batch_tiles, 2)
        expect_s4_class(batch_tiles[[1]], "SpatRaster")

        # Iterator should advance
        expect_equal(iter$position, 2)

        unlink(temp_file)
    })

    test_that("tileIterator with tileGroup combination", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 12

        tg <- tileGroup(tp, groups = list(
            "group1" = 1:6,
            "group2" = 7:12
        ))

        # Set active group and create iterator
        tg$active <- "group1"
        iter <- tileIterator(tg, batch_size = 3)

        expect_equal(iter$total_tiles, 6)
        expect_true(iter$has_next)

        # Get batches
        batch1 <- iter$next_batch()
        batch2 <- iter$next_batch()

        expect_length(batch1, 3)
        expect_length(batch2, 3)
        expect_false(iter$has_next)
    })
})

# Test complex integration scenarios ####
describe("Complex integration scenarios", {

    test_that("end-to-end spatial workflow", {
        # Create test raster
        r <- create_test_raster(100, 100, c(0, 1000, 0, 1000))
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Step 1: Create spatial tile plan
        tp <- tilePlan("spatial")
        ext(tp) <- ext(r)
        length(tp) <- 25

        # Step 2: Add metadata
        tp$filename <- sprintf("output_tile_%03d.tif", tp$tile)
        tp$priority <- sample(1:5, length(tp), replace = TRUE)

        # Step 3: Create groups by priority
        high_priority <- which(tp$priority >= 4)
        low_priority <- which(tp$priority < 4)

        tg <- tileGroup(tp, groups = list(
            "high_priority" = high_priority,
            "low_priority" = low_priority
        ))

        # Step 4: Process high priority tiles first
        tg$active <- "high_priority"
        iter_high <- tileIterator(tg, batch_size = 3)

        processed_tiles <- list()
        batch_count <- 0
        while(iter_high$has_next) {
            batch_count <- batch_count + 1
            batch <- getTile(temp_file, iter_high)
            processed_tiles[[batch_count]] <- batch
            expect_type(batch, "list")
            expect_true(length(batch) <= 3)
        }

        expect_gt(batch_count, 0)
        expect_equal(sum(lengths(processed_tiles)), length(high_priority))

        unlink(temp_file)
    })

    test_that("end-to-end pixel workflow with padding", {
        # Create test raster with specific pattern
        r <- create_test_raster(80, 80)
        terra::values(r) <- 1:terra::ncell(r)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Step 1: Create pixel plan with padding
        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 20
        tp$ncols <- 20
        tp_padded <- tp + 5  # Add 5 pixel padding

        # Step 2: Create iterator for batch processing
        iter <- tileIterator(tp_padded, batch_size = 4)

        # Step 3: Process in batches
        all_results <- list()
        while(iter$has_next) {
            batch <- getTile(temp_file, iter, extend = TRUE, fill = 0)

            # Each tile should be 30x30 (20 + 2*5 padding)
            for(tile in batch) {
                expect_equal(dim(tile), c(30, 30, 1))
            }

            all_results <- c(all_results, batch)
        }

        expect_equal(length(all_results), length(tp))

        unlink(temp_file)
    })

    test_that("memory efficiency with large tile plans", {
        skip_if_not(Sys.getenv("TEST_PERFORMANCE") == "true", "Performance tests skipped")

        # Large tile plan
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 10000, 0, 10000)
        length(tp) <- 10000

        # Should be able to create without memory issues
        expect_gt(length(tp), 9999)

        # Random access should be efficient
        start_time <- Sys.time()
        random_tiles <- tp[sample(length(tp), 100)]
        end_time <- Sys.time()

        expect_length(random_tiles, 100)
        # Should complete in reasonable time (< 1 second)
        expect_lt(as.numeric(end_time - start_time), 1.0)

        # Metadata operations should scale
        tp$batch_id <- rep(1:100, length.out = length(tp))
        expect_length(tp$batch_id, length(tp))
    })
})
