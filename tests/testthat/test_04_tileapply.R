# Comprehensive tests for tileApply functionality
# Tests basic tile processing, group processing, iterator processing

# Helper functions ####
create_test_raster <- function(nrow = 50, ncol = 50, extent = c(0, 50, 0, 50), nlyr = 1, vals = NULL) {
    if (nlyr == 1) {
        if (is.null(vals)) {
            vals <- 1:(nrow * ncol)
        }
        r <- terra::rast(nrows = nrow, ncols = ncol, extent = extent, vals = vals)
    } else {
        r_list <- list()
        for (i in 1:nlyr) {
            if (is.null(vals)) {
                layer_vals <- i * (1:(nrow * ncol))
            } else {
                # If vals provided, use it for first layer and modify for others
                layer_vals <- if (i == 1) vals else vals * i
            }
            r_list[[i]] <- terra::rast(nrows = nrow, ncols = ncol, extent = extent, vals = layer_vals)
        }
        r <- do.call(c, r_list)
        names(r) <- paste0("layer_", 1:nlyr)
    }
    return(r)
}

create_test_vector <- function(n_features = 10, extent = c(0, 50, 0, 50)) {
    # Create random points within extent
    x_coords <- runif(n_features, extent[1], extent[2])
    y_coords <- runif(n_features, extent[3], extent[4])

    # Create SpatVector
    points <- terra::vect(cbind(x_coords, y_coords), type = "points")
    points$id <- 1:n_features
    points$value <- rnorm(n_features, 100, 20)
    return(points)
}

# Test tileApply with tilePlan (basic processing) ####
describe("tileApply with tilePlan", {
    test_that("basic tileApply with spatialTilePlan works", {
        # Create test data
        r <- create_test_raster(60, 60)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Create tile plan
        tp <- tilePlan("spatial")
        ext(tp) <- ext(r)
        length(tp) <- 9

        # Apply simple function
        results <- tileApply(temp_file, tiles = tp, FUN = function(tile) {
            terra::global(tile, "mean", na.rm = TRUE)[[1]]
        })

        expect_type(results, "list")
        expect_length(results, length(tp))
        expect_true(all(sapply(results, is.numeric)))
        expect_true(all(sapply(results, function(x) length(x) == 1)))

        unlink(temp_file)
    })

    test_that("basic tileApply with pixelTilePlan works", {
        r <- create_test_raster(40, 40)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Create pixel tile plan
        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 10
        tp$ncols <- 10

        # Apply function that returns tile statistics
        results <- tileApply(temp_file, tiles = tp, FUN = function(tile) {
            list(
                mean = terra::global(tile, "mean")[[1]],
                ncells = terra::ncell(tile)
            )
        })

        expect_type(results, "list")
        expect_length(results, length(tp))
        expect_true(all(sapply(results, function(x) "mean" %in% names(x))))
        expect_true(all(sapply(results, function(x) "ncells" %in% names(x))))

        unlink(temp_file)
    })

    test_that("tileApply with special function parameters works", {
        r <- create_test_raster(30, 30)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r)
        length(tp) <- 4 # 2x2 grid

        # Function using special parameters
        results <- tileApply(temp_file,
            tiles = tp,
            FUN = function(tile, .I, .TILE, .R, .C) {
                list(
                    tile_id = .I,
                    row = .R,
                    col = .C,
                    extent_area = terra::expanse(
                        terra::as.polygons(.TILE, crs = "local")
                    ),
                    tile_mean = terra::global(tile, "mean")[[1]]
                )
            }
        )

        expect_length(results, 4)

        # Check that special parameters are correctly passed
        tile_ids <- sapply(results, function(x) x$tile_id)
        expect_equal(tile_ids, 1:4)

        rows <- sapply(results, function(x) x$row)
        cols <- sapply(results, function(x) x$col)
        expect_true(all(rows %in% 1:2))
        expect_true(all(cols %in% 1:2))

        # Check extent areas are reasonable
        areas <- sapply(results, function(x) x$extent_area)
        expect_true(all(areas > 0))

        unlink(temp_file)
    })

    test_that("tileApply with two input datasets works", {
        # Create two test rasters
        r1 <- create_test_raster(40, 40, vals = 1:1600)
        r2 <- create_test_raster(40, 40, vals = 1600:1) # Reverse values

        temp_file1 <- tempfile(fileext = ".tif")
        temp_file2 <- tempfile(fileext = ".tif")
        terra::writeRaster(r1, temp_file1, overwrite = TRUE)
        terra::writeRaster(r2, temp_file2, overwrite = TRUE)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r1)
        length(tp) <- 4

        # Apply function using both datasets
        results <- tileApply(
            x = temp_file1,
            y = temp_file2,
            tiles = tp,
            FUN = function(tile_x, tile_y) {
                list(
                    x_mean = terra::global(tile_x, "mean")[[1]],
                    y_mean = terra::global(tile_y, "mean")[[1]],
                    correlation = cor(as.vector(tile_x), as.vector(tile_y))
                )
            }
        )

        expect_length(results, 4)
        expect_true(all(sapply(results, function(x) "correlation" %in% names(x))))

        # Values should be negatively correlated due to reverse ordering
        correlations <- sapply(results, function(x) x$correlation)
        expect_true(all(correlations < 0))

        unlink(c(temp_file1, temp_file2))
    })

    test_that("tileApply respects get_params", {
        # Create multi-layer raster
        r <- create_test_raster(30, 30, nlyr = 3)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r)
        length(tp) <- 4

        # Test layer selection via get_params
        results_layer2 <- tileApply(
            temp_file,
            tiles = tp,
            FUN = function(tile) terra::nlyr(tile),
            get_params_x = list(lyr = 2)
        )

        # Should get single layer tiles
        expect_true(all(sapply(results_layer2, function(x) x == 1)))

        unlink(temp_file)
    })
})

# Test tileApply with SpatRaster and SpatVector ####
describe("tileApply with terra objects", {
    test_that("tileApply works with SpatRaster objects", {
        r <- create_test_raster(50, 50)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Read back as SpatRaster
        r_file <- terra::rast(temp_file)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r_file)
        length(tp) <- 6

        results <- tileApply(r_file, tiles = tp, FUN = function(tile) {
            terra::global(tile, "sum")[[1]]
        })

        expect_length(results, 6)
        expect_true(all(sapply(results, is.numeric)))

        unlink(temp_file)
    })

    test_that("tileApply works with SpatVector objects", {
        # Create test vector
        v <- create_test_vector(100)
        temp_file <- tempfile(fileext = ".shp")
        terra::writeVector(v, temp_file, overwrite = TRUE)
        v_file <- vect(temp_file)

        tp <- tilePlan("spatial")
        ext(tp) <- ext(v_file)
        length(tp) <- 4

        results <- tileApply(v_file, tiles = tp, FUN = function(tile_vectors) {
            if (nrow(tile_vectors) > 0) {
                list(
                    n_features = nrow(tile_vectors),
                    mean_value = mean(tile_vectors$value, na.rm = TRUE)
                )
            } else {
                list(n_features = 0, mean_value = NA)
            }
        })

        expect_length(results, length(tp))
        total_features <- sum(sapply(results, function(x) x$n_features))
        expect_equal(total_features, nrow(v))

        unlink(temp_file)
    })
})

# Test tileApply with tileGroup ####
describe("tileApply with tileGroup", {
    test_that("tileApply with group parallelization works", {
        r <- create_test_raster(60, 60)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Create tile plan and groups
        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r)
        length(tp) <- 16 # 4x4 grid

        tg <- tileGroup(tp, groups = list(
            "quadrant1" = 1:4,
            "quadrant2" = 5:8,
            "quadrant3" = 9:12,
            "quadrant4" = 13:16
        ))

        # Test group parallelization
        results <- tileApply(
            temp_file,
            tiles = tg,
            parallel_strategy = "groups",
            FUN = function(tile, .I, .GROUP) {
                list(
                    tile_id = .I,
                    group = .GROUP,
                    mean_value = terra::global(tile, "mean")[[1]]
                )
            },
            group_FUN = function(group_results, .GROUP) {
                list(
                    group_name = .GROUP,
                    n_tiles = length(group_results),
                    group_mean = mean(sapply(group_results, function(x) x$mean_value))
                )
            }
        )

        expect_length(results, 4) # 4 groups
        expect_true(all(sapply(results, function(x) "group_name" %in% names(x))))
        expect_true(all(sapply(results, function(x) x$n_tiles == 4)))

        unlink(temp_file)
    })

    test_that("tileApply with tile parallelization works", {
        r <- create_test_raster(40, 40)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r)
        length(tp) <- 12

        tg <- tileGroup(tp, groups = list(
            "batch1" = 1:6,
            "batch2" = 7:12
        ))

        # Test tile parallelization (process groups sequentially, tiles in parallel)
        results <- tileApply(
            temp_file,
            tiles = tg,
            parallel_strategy = "tiles",
            FUN = function(tile, .I, .GROUP) {
                list(
                    tile_id = .I,
                    group = .GROUP,
                    sum_value = terra::global(tile, "sum")[[1]]
                )
            },
            simplify = TRUE # Flatten to single list
        )

        expect_length(results, 12) # All tiles

        # Check that group names are preserved
        groups <- sapply(results, function(x) x$group)
        expect_true(all(groups %in% c("batch1", "batch2")))

        unlink(temp_file)
    })

    test_that("tileApply with setup_FUN works", {
        r <- create_test_raster(30, 30)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r)
        length(tp) <- 8

        tg <- tileGroup(tp, groups = list(
            "group1" = 1:4,
            "group2" = 5:8
        ))

        results <- tileApply(
            temp_file,
            tiles = tg,
            parallel_strategy = "groups",
            setup_FUN = function(.GROUP, .X) {
                list(
                    group_id = .GROUP,
                    setup_time = Sys.time(),
                    data_class = class(.X)
                )
            },
            FUN = function(data, .I, .SETUP_OUT) {
                list(
                    tile_id = .I,
                    processed_by_group = .SETUP_OUT$group_id,
                    data_class = .SETUP_OUT$data_class,
                    mean = terra::global(data, mean),
                    setup_time = .SETUP_OUT$setup_time
                )
            }
        )

        expect_length(results, 2) # 2 groups
        expect_length(results[[1]], 4) # 4 tiles in first group
        expect_length(results[[2]], 4) # 4 tiles in second group
        expect_equal(
            names(results[[1]][[1]]),
            c(
                "tile_id", "processed_by_group", "data_class",
                "mean", "setup_time"
            )
        )

        unlink(temp_file)
    })
})

# Test tileApply with tileIterator ####
describe("tileApply with tileIterator", {
    test_that("basic tileApply with tileIterator works", {
        r <- create_test_raster(50, 50)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 10
        tp$ncols <- 10

        iter <- tileIterator(tp, batch_size = 3)

        results <- tileApply(
            temp_file,
            tiles = iter,
            FUN = function(batch, .BATCH, .POSITION) {
                list(
                    batch_num = .BATCH,
                    batch_size = length(batch),
                    position_range = .POSITION,
                    batch_means = sapply(batch, function(tile) terra::global(tile, "mean")[[1]])
                )
            }
        )

        expect_type(results, "list")
        expect_gt(length(results), 0)

        # Check batch information
        batch_nums <- sapply(results, function(x) x$batch_num)
        expect_equal(batch_nums, seq_along(results))

        # Check position tracking
        positions <- lapply(results, function(x) x$position_range)
        expect_true(all(sapply(positions, length) == 2))

        unlink(temp_file)
    })

    test_that("tileApply with iterator setup_FUN works", {
        r <- create_test_raster(40, 40)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r)
        length(tp) <- 16

        iter <- tileIterator(tp, batch_size = 4)

        results <- tileApply(
            temp_file,
            tiles = iter,
            setup_FUN = function(.W, .X) {
                list(
                    worker_id = .W,
                    start_time = Sys.time(),
                    input_class = class(.X),
                    raster_info = list(
                        nrow = terra::nrow(.X),
                        ncol = terra::ncol(.X)
                    )
                )
            },
            FUN = function(batch, .BATCH, .SETUP_OUT) {
                list(
                    worker = .SETUP_OUT$worker_id,
                    batch_num = .BATCH,
                    tiles_processed = length(batch),
                    raster_dims = .SETUP_OUT$raster_info,
                    data_type = .SETUP_OUT$input_class,
                    batch_means = sapply(batch, function(tile) terra::global(tile, "mean")[[1]])
                )
            }
        )

        expect_type(results, "list")
        expect_gt(length(results), 0)

        # Check worker information
        workers <- sapply(results, function(x) x$worker)
        expect_true(all(is.numeric(workers)))
        expect_true(all(sapply(results, function(x) x$data_type == "SpatRaster")))
        expect_true(is.numeric(results[[1]]$batch_means) && all(!is.na(results[[1]]$batch_means)))

        unlink(temp_file)
    })

    test_that("tileApply with iterator and two datasets works", {
        r1 <- create_test_raster(30, 30)
        r2 <- create_test_raster(30, 30) * -2

        temp_file1 <- tempfile(fileext = ".tif")
        temp_file2 <- tempfile(fileext = ".tif")
        terra::writeRaster(r1, temp_file1, overwrite = TRUE)
        terra::writeRaster(r2, temp_file2, overwrite = TRUE)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r1)
        length(tp) <- 9

        iter <- tileIterator(tp, batch_size = 3)

        results <- tileApply(
            x = temp_file1,
            y = temp_file2,
            tiles = iter,
            FUN = function(batch_x, batch_y, .BATCH) {
                correlations <- mapply(function(tx, ty) {
                    cor(as.vector(tx), as.vector(ty))
                }, batch_x, batch_y)

                list(
                    batch_num = .BATCH,
                    n_tiles = length(batch_x),
                    correlations = correlations,
                    mean_correlation = mean(correlations)
                )
            }
        )

        expect_type(results, "list")
        expect_true(all(sapply(results, function(x) x$n_tiles <= 3)))
        # cor should be -1 because of r2 scaling
        expect_true(all(sapply(results, function(x) x$mean_correlation < 0)))

        unlink(c(temp_file1, temp_file2))
    })
})

# Test performance and edge cases ####
describe("tileApply performance and edge cases", {
    test_that("handles large number of small tiles", {
        skip_if_not(Sys.getenv("TEST_PERFORMANCE") == "true", "Performance tests skipped")

        r <- create_test_raster(200, 200)
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        # Create many small tiles
        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 5
        tp$ncols <- 5

        expect_gt(length(tp), 1000) # Should create many tiles

        # Sample subset for testing
        sample_indices <- sample(length(tp), 100)

        start_time <- Sys.time()
        results <- tileApply(
            temp_file,
            tiles = tp,
            FUN = function(tile, .I) {
                if (.I %in% sample_indices) {
                    terra::global(tile, "mean")[[1]]
                } else {
                    NA # Skip processing for non-sampled tiles
                }
            }
        )
        end_time <- Sys.time()

        expect_length(results, length(tp))

        # Should complete in reasonable time
        processing_time <- as.numeric(end_time - start_time)
        expect_lt(processing_time, 30) # Should take less than 30 seconds

        unlink(temp_file)
    })

    test_that("handles empty tiles gracefully", {
        # Create vector data that doesn't cover all tiles
        v <- create_test_vector(5, extent = c(0, 25, 0, 25)) # Only covers part of extent
        temp_file <- tempfile(fileext = ".shp")
        terra::writeVector(v, temp_file, overwrite = TRUE)

        tp <- tilePlan("spatial")
        terra::ext(tp) <- c(0, 50, 0, 50) # Larger extent than vector data
        length(tp) <- 9

        results <- tileApply(temp_file, tiles = tp, FUN = function(tile_vectors) {
            if (nrow(tile_vectors) > 0) {
                list(n_features = nrow(tile_vectors), has_data = TRUE)
            } else {
                list(n_features = 0, has_data = FALSE)
            }
        })

        expect_length(results, 9)

        # Some tiles should be empty
        has_data <- sapply(results, function(x) x$has_data)
        expect_true(sum(sapply(results, function(x) x$n_features)) == 5)
        expect_true(any(has_data))
        expect_true(any(!has_data))

        unlink(temp_file)
    })

    test_that("handles edge tiles with padding correctly", {
        r <- create_test_raster(47, 53) # Odd dimensions
        temp_file <- tempfile(fileext = ".tif")
        terra::writeRaster(r, temp_file, overwrite = TRUE)

        tp <- tilePlan("pixel")
        tp$pxdims <- dim(r)[1:2]
        tp$nrows <- 10
        tp$ncols <- 10
        tp_padded <- tp + 3

        # Test edge tiles with extension
        edge_indices <- c(1, tp@dims[2], length(tp) - tp@dims[2] + 1, length(tp)) # Corner tiles

        results <- tileApply(
            temp_file,
            tiles = tp_padded,
            FUN = function(tile, .I) {
                if (.I %in% edge_indices) {
                    list(
                        tile_id = .I,
                        dimensions = dim(tile),
                        class = class(tile),
                        is_edge = TRUE
                    )
                } else {
                    list(
                        tile_id = .I,
                        dimensions = dim(tile),
                        class = class(tile),
                        is_edge = FALSE
                    )
                }
            },
            get_params_x = list(extend = TRUE, fill = 0)
        )

        expect_length(results, length(tp))
        expect_true(all(sapply(results, function(x) x$class == "SpatRaster")))

        # Check that edge tiles have expected dimensions with padding
        edge_results <- results[edge_indices]
        expect_true(all(sapply(edge_results, function(x) x$is_edge)))
        expect_true(all(sapply(
            # everything is padded + extend including edges
            edge_results, function(x) identical(x$dimensions, c(16, 16, 1))
        )))

        unlink(temp_file)
    })
})

# Integration test - complete workflow ####
describe("tileApply integration workflow", {
    test_that("complete spatial analysis workflow", {
        # Create test datasets
        r_elevation <- create_test_raster(80, 80, vals = runif(6400, 0, 1000))
        r_temperature <- create_test_raster(80, 80, vals = runif(6400, -10, 40))
        points <- create_test_vector(50, extent = c(0, 80, 0, 80))

        # Write to files
        elev_file <- tempfile(fileext = ".tif")
        temp_file <- tempfile(fileext = ".tif")
        points_file <- tempfile(fileext = ".shp")

        terra::writeRaster(r_elevation, elev_file, overwrite = TRUE)
        terra::writeRaster(r_temperature, temp_file, overwrite = TRUE)
        terra::writeVector(points, points_file, overwrite = TRUE)

        # Create analysis plan
        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(r_elevation)
        length(tp) <- 16

        # Add processing metadata
        tp$priority <- sample(1:3, length(tp), replace = TRUE)
        tp$region <- rep(c("north", "south"), each = length(tp) / 2)

        # Create groups by priority
        high_priority <- which(tp$priority == 3)
        med_priority <- which(tp$priority == 2)
        low_priority <- which(tp$priority == 1)

        tg <- tileGroup(tp, groups = list(
            "high" = high_priority,
            "medium" = med_priority,
            "low" = low_priority
        ))

        # Process with group-based parallelization
        analysis_results <- tileApply(
            x = elev_file,
            y = temp_file,
            tiles = tg,
            parallel_strategy = "groups",
            setup_FUN = function(.GROUP) {
                list(
                    group_start_time = Sys.time(),
                    priority_level = .GROUP
                )
            },
            FUN = function(elev_tile, temp_tile, .I, .GROUP, .SETUP_OUT) {
                # Calculate tile statistics
                elev_stats <- terra::global(elev_tile, c("mean", "sd"), na.rm = TRUE)
                temp_stats <- terra::global(temp_tile, c("mean", "sd"), na.rm = TRUE)

                # Calculate correlation
                elev_corr <- cor(as.vector(elev_tile), as.vector(temp_tile))

                list(
                    tile_id = .I,
                    priority_group = .GROUP,
                    processed_by = .SETUP_OUT$priority_level,
                    elevation = list(
                        mean = elev_stats$mean,
                        sd = elev_stats$sd
                    ),
                    temperature = list(
                        mean = temp_stats$mean,
                        sd = temp_stats$sd
                    ),
                    elev_temp_correlation = elev_corr
                )
            },
            group_FUN = function(group_results, .GROUP) {
                correlations <- sapply(group_results, function(x) x$elev_temp_correlation)
                elev_means <- sapply(group_results, function(x) x$elevation$mean)

                list(
                    priority_group = .GROUP,
                    n_tiles = length(group_results),
                    mean_correlation = mean(correlations, na.rm = TRUE),
                    mean_elevation = mean(elev_means, na.rm = TRUE),
                    tile_ids = sapply(group_results, function(x) x$tile_id)
                )
            }
        )

        # Validate results
        expect_length(analysis_results, 3) # 3 priority groups
        expect_true(all(sapply(analysis_results, function(x) "priority_group" %in% names(x))))
        expect_true(all(sapply(analysis_results, function(x) x$n_tiles > 0)))

        # Check that all tiles were processed
        all_tile_ids <- unlist(lapply(analysis_results, function(x) x$tile_ids))
        expect_setequal(all_tile_ids, 1:length(tp))

        # Now process points data by region
        region_results <- tileApply(
            points_file,
            tiles = tp,
            FUN = function(points_tile, .I, .TILE) {
                if (nrow(points_tile) > 0) {
                    list(
                        tile_id = .I,
                        n_points = nrow(points_tile),
                        mean_value = mean(points_tile$value, na.rm = TRUE),
                        tile_area = terra::expanse(terra::as.polygons(.TILE, crs = "local"))
                    )
                } else {
                    list(
                        tile_id = .I,
                        n_points = 0,
                        mean_value = NA,
                        tile_area = terra::expanse(terra::as.polygons(.TILE, crs = "local"))
                    )
                }
            }
        )

        # all regions are the same size
        expect_equal(length(unique(sapply(region_results, function(x) x$tile_area))), 1)
        expect_length(region_results, length(tp))
        sv2 <- terra::crop(points, c(0, 50, 0, 50))
        expected_npoints <- nrow(sv2)
        total_points <- sum(sapply(region_results, function(x) x$n_points))
        expect_equal(total_points, expected_npoints)

        # Cleanup
        unlink(c(elev_file, temp_file))
        unlink(list.files(dirname(points_file),
            pattern = tools::file_path_sans_ext(basename(points_file)),
            full.names = TRUE
        ))
    })
})
