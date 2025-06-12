# Test extreme values and boundary conditions ####
describe("Boundary conditions", {

    test_that("handles very small extents", {
        tp <- tilePlan("spatial")

        # Very small extent
        ext(tp) <- c(0, 0.001, 0, 0.001)
        length(tp) <- 4

        expect_gt(length(tp), 0)
        expect_true(all(sapply(tp[], function(x) {
            bounds <- as.vector(x)
            bounds[2] > bounds[1] && bounds[4] > bounds[3]
        })))
    })

    test_that("handles very large extents", {
        tp <- tilePlan("spatial")

        # Very large extent
        ext(tp) <- c(-1e6, 1e6, -1e6, 1e6)
        length(tp) <- 4

        expect_gt(length(tp), 0)
        tiles <- tp[1:2]
        expect_length(tiles, 2)
    })

    test_that("handles single tile scenarios", {
        # Spatial single tile
        tp_spatial <- tilePlan("spatial")
        ext(tp_spatial) <- c(0, 100, 0, 100)
        length(tp_spatial) <- 1

        expect_equal(length(tp_spatial), 1)
        expect_equal(dim(tp_spatial), c(1, 1))

        tile <- tp_spatial[1]
        expect_length(tile, 1)

        # Pixel single tile
        tp_pixel <- tilePlan("pixel")
        tp_pixel$pxdims <- c(100, 100)
        tp_pixel$nrows <- 100
        tp_pixel$ncols <- 100

        expect_equal(length(tp_pixel), 1)
        expect_equal(dim(tp_pixel), c(1, 1))
    })

    test_that("handles maximum reasonable tile counts", {
        skip_if_not(Sys.getenv("TEST_PERFORMANCE") == "true", "Performance tests skipped")

        # Large but reasonable number of tiles
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 1000, 0, 1000)
        length(tp) <- 10000

        expect_gte(length(tp), 10000)

        # Should be able to extract metadata without memory issues
        expect_type(tp$tile, "integer")
        expect_length(tp$tile, length(tp))

        # Should be able to extract some tiles
        sample_tiles <- tp[sample(length(tp), 10)]
        expect_length(sample_tiles, 10)
    })

    test_that("handles odd pixel dimensions", {
        tp <- tilePlan("pixel")

        # Odd total dimensions with even tile dimensions
        tp$pxdims <- c(99, 101)
        tp$nrows <- 10
        tp$ncols <- 10

        # Should handle ceiling division correctly
        expect_equal(dim(tp), c(ceiling(99/10), ceiling(101/10)))
        expect_equal(dim(tp), c(10, 11))

        # All tiles should be accessible
        all_tiles <- tp[]
        expect_length(all_tiles, length(tp))
    })

    test_that("handles very small pixel tiles", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(1000, 1000)
        tp$nrows <- 1
        tp$ncols <- 1

        # Should create one tile per pixel (effectively)
        expect_equal(length(tp), 1000 * 1000)
        expect_equal(dim(tp), c(1000, 1000))

        # Spot check a few tiles
        sample_indices <- c(1, 500, 1000, 500000, 1000000)
        sample_tiles <- tp[sample_indices]
        expect_length(sample_tiles, length(sample_indices))
    })
})

# Test numerical precision and edge cases ####
describe("Numerical precision", {

    test_that("handles floating point precision in extents", {
        tp <- tilePlan("spatial")

        # Use extent that might cause floating point issues
        ext(tp) <- c(0.1, 0.3, 0.1, 0.3)
        length(tp) <- 4

        tiles <- tp[]
        expect_length(tiles, length(tp))

        # All tiles should have valid bounds
        for(tile in tiles) {
            bounds <- as.vector(tile)
            expect_true(bounds[2] > bounds[1]) # xmax > xmin
            expect_true(bounds[4] > bounds[3]) # ymax > ymin
            expect_true(all(is.finite(bounds)))
        }
    })

    test_that("handles negative coordinates", {
        tp <- tilePlan("spatial")

        # Extent spanning negative and positive
        ext(tp) <- c(-50, 50, -25, 75)
        length(tp) <- 9

        tiles <- tp[]
        expect_length(tiles, length(tp))

        # Check that some tiles have negative coordinates
        all_bounds <- do.call(rbind, lapply(tiles, as.vector))
        expect_true(any(all_bounds[,1] < 0)) # Some xmin < 0
        expect_true(any(all_bounds[,3] < 0)) # Some ymin < 0
    })
})

# Test metadata edge cases ####
describe("Metadata edge cases", {

    test_that("handles large metadata objects", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 100

        # Add large metadata
        tp$large_text <- replicate(length(tp), paste(sample(letters, 1000, replace = TRUE), collapse = ""))
        tp$numeric_vector <- lapply(seq_len(length(tp)), function(i) runif(100))

        expect_length(tp$large_text, length(tp))
        expect_length(tp$numeric_vector, length(tp))

        # Should still be able to extract tiles with metadata
        tiles_with_meta <- tp[1:5]
        expect_length(tiles_with_meta, 5)
        expect_true(nchar(attr(tiles_with_meta[[1]], "large_text")) > 500)
    })

    test_that("handles NULL and NA in metadata", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 4

        # Set some metadata with NAs
        tp$maybe_na_char <- c("value1", NA, "value3", "value4")
        tp$maybe_na_num <- c(1, 2, NA, 4)

        expect_equal(tp$maybe_na_char[2], NA_character_)
        expect_equal(tp$maybe_na_num[3], NA_real_)

        # Should handle extraction correctly
        tile_with_na <- tp[[2]]
        expect_true(is.na(tile_with_na$maybe_na_char))
        tile_with_na <- tp[[3]]
        expect_true(is.na(tile_with_na$maybe_na_num))
    })
})

# Test padding edge cases ####
describe("Padding edge cases", {

    test_that("handles extreme padding values", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 4

        # Very large padding
        tp_large_pad <- tp + 1000
        expect_equal(tp_large_pad@pad, 1000)

        tiles_padded <- tp_large_pad[1:2]
        expect_length(tiles_padded, 2)

        # Negative padding
        tp_negative <- tp - 10
        expect_equal(tp_negative@pad, -10)

        tiles_negative <- tp_negative[1:2]
        expect_length(tiles_negative, 2)
    })

    test_that("handles padding larger than tile size", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)
        tp$nrows <- 10
        tp$ncols <- 10

        # Padding larger than tile dimensions
        tp_huge_pad <- tp + 50 # Tiles are 10x10, padding is 50

        tiles <- tp_huge_pad[1:2]
        expect_length(tiles, 2)

        # Bounds should still be valid integers
        for(tile in tiles) {
            expect_type(tile, "integer")
            expect_length(tile, 4)
        }
    })

    test_that("handles cumulative padding operations", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 4

        # Chain many padding operations
        tp_result <- tp + 5 - 2 + 10 - 3 + 1
        expect_equal(tp_result@pad, 11)

        # Original should be unchanged
        expect_equal(tp@pad, 0)
    })
})

# Test indexing edge cases ####
describe("Indexing edge cases", {

    test_that("handles duplicate indices", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 9

        # Duplicate indices
        duplicate_tiles <- tp[c(1, 1, 2, 2, 1)]
        expect_length(duplicate_tiles, 5)

        # Should get same tile multiple times
        expect_identical(as.vector(duplicate_tiles[[1]]), as.vector(duplicate_tiles[[2]]))
        expect_identical(as.vector(duplicate_tiles[[1]]), as.vector(duplicate_tiles[[5]]))
    })

    test_that("handles non-sequential indices", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)
        tp$nrows <- 10
        tp$ncols <- 10

        # Random order indices
        random_indices <- sample(length(tp), 10)
        random_tiles <- tp[random_indices]
        expect_length(random_tiles, 10)

        # Reverse order
        reverse_tiles <- tp[length(tp):1]
        expect_length(reverse_tiles, length(tp))
    })

    test_that("handles large index vectors", {
        skip_if_not(Sys.getenv("TEST_PERFORMANCE") == "true", "Performance tests skipped")

        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 1000, 0, 1000)
        length(tp) <- 10000

        # Extract many tiles at once
        many_indices <- sample(length(tp), 1000)
        many_tiles <- tp[many_indices]
        expect_length(many_tiles, 1000)
    })

    test_that("handles i,j indexing edge cases", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 16 # Should be 4x4

        # Single row
        row_tiles <- tp[1, 1:ncol(tp)]
        expect_length(row_tiles, ncol(tp))

        # Single column
        col_tiles <- tp[1:nrow(tp), 1]
        expect_length(col_tiles, nrow(tp))

        # Reverse order i,j
        reverse_ij <- tp[nrow(tp):1, ncol(tp):1]
        expect_length(reverse_ij, length(tp))

        # Non-contiguous i,j
        sparse_ij <- tp[c(1,3), c(2,4)]
        expect_length(sparse_ij, 4)
    })
})

# Test memory and performance edge cases ####
describe("Memory and performance", {

    test_that("handles repeated access patterns", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 25

        # Repeated access to same tiles should be consistent
        tile1_first <- tp[[1]]
        tile1_second <- tp[[1]]
        expect_identical(as.vector(tile1_first), as.vector(tile1_second))

        # Mixed access patterns
        for(i in 1:10) {
            random_tile <- tp[sample(length(tp), 1)]
            expect_length(random_tile, 1)
        }
    })

    test_that("handles metadata access patterns", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(200, 200)
        tp$nrows <- 20
        tp$ncols <- 20

        # Add multiple metadata columns
        tp$batch <- rep(1:4, length.out = length(tp))
        tp$priority <- sample(1:10, length(tp), replace = TRUE)
        tp$status <- sample(c("pending", "processing", "complete"), length(tp), replace = TRUE)

        # Repeated metadata access
        for(i in 1:20) {
            meta <- tp[[sample(length(tp), 1)]]
            expect_s3_class(meta, "data.frame")
            expect_true(all(c("batch", "priority", "status") %in% colnames(meta)))
        }
    })
})

# Test recovery from errors ####
describe("Error recovery", {

    test_that("recovers from invalid operations", {
        tp <- tilePlan("spatial")
        ext(tp) <- c(0, 100, 0, 100)
        length(tp) <- 4

        # Try invalid index, then valid operation
        expect_error(tp[100], "subscript out of bounds")

        # Should still work normally after error
        valid_tile <- tp[1]
        expect_length(valid_tile, 1)

        # Try invalid metadata, then valid operation
        expect_error(tp$tile <- c("a", "b", "c"), "replacement has 3 rows")

        tp$tile <- c("a", "b")
        expect_identical(tp$tile, rep(c("a", "b"), 2))

        # Should still work normally
        tp$new_meta <- paste0("tile_", tp$tile)
        expect_length(tp$new_meta, length(tp))
    })

    test_that("handles partial failures gracefully", {
        tp <- tilePlan("pixel")
        tp$pxdims <- c(100, 100)
        tp$nrows <- 10

        # Try to set invalid ncols after valid setup
        expect_no_error({
            try(tp$ncols <- -5, silent = TRUE) # Should fail silently
        })

        # Should be able to set valid ncols
        tp$ncols <- 10
        expect_equal(tp$ncols, 10)
    })
})
