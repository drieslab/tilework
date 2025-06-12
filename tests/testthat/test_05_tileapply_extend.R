# Tests for extensibility

# Mock data class for extensibility testing ####
setClass("MockData",
    slots = list(
        data = "matrix",
        extent = "numeric"
    )
)

setMethod("initialize", signature("MockData"), function(.Object, data = matrix(), extent = c(0, 1, 0, 1)) {
    .Object@data <- data
    .Object@extent <- extent
    .Object
})

# Define getBoundedData method for MockData
setMethod("getBoundedData", signature("MockData", "SpatExtent"), function(x, bound) {
    # Extract data within bounds (simplified implementation)
    extent <- x@extent
    data_matrix <- x@data

    # Calculate which rows/cols of data matrix to extract
    total_rows <- nrow(data_matrix)
    total_cols <- ncol(data_matrix)

    # Normalize bounds to data matrix indices
    row_range <- round(c(
        max(1, (bound[3] - extent[3]) / (extent[4] - extent[3]) * total_rows),
        min(total_rows, (bound[4] - extent[3]) / (extent[4] - extent[3]) * total_rows)
    ))
    col_range <- round(c(
        max(1, (bound[1] - extent[1]) / (extent[2] - extent[1]) * total_cols),
        min(total_cols, (bound[2] - extent[1]) / (extent[2] - extent[1]) * total_cols)
    ))

    # Extract subset
    new_ext <- as.vector(bound)
    names(new_ext) <- NULL
    subset_data <- data_matrix[row_range[1]:row_range[2], col_range[1]:col_range[2], drop = FALSE]
    new("MockData", data = subset_data, extent = new_ext)
})

# Test extensibility with mock data ####
describe("tileApply extensibility", {
    test_that("tileApply works with custom data types", {
        # Create mock data
        test_matrix <- matrix(runif(100), nrow = 10, ncol = 10)
        mock_data <- new("MockData", data = test_matrix, extent = c(0, 10, 0, 10))

        # Create tile plan
        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(mock_data@extent)
        length(tp) <- 4

        # Apply function to mock data
        results <- tileApply(mock_data, tiles = tp, FUN = function(tile_data) {
            list(
                class = class(tile_data),
                dimensions = dim(tile_data@data),
                mean_value = mean(tile_data@data)
            )
        })

        expect_length(results, 4)
        expect_true(all(sapply(results, function(x) x$class == "MockData")))
        expect_true(all(sapply(results, function(x) is.numeric(x$mean_value))))
    })

    test_that("redispatch mechanism works correctly", {
        # Test that redispatch_tileapply is called for custom classes
        test_matrix1 <- matrix(1:100, nrow = 10, ncol = 10)
        test_matrix2 <- matrix(100:1, nrow = 10, ncol = 10)
        mock_data1 <- new("MockData", data = test_matrix1, extent = c(0, 10, 0, 10))
        mock_data2 <- new("MockData", data = test_matrix2, extent = c(0, 10, 0, 10))

        tp <- tilePlan("spatial")
        terra::ext(tp) <- terra::ext(mock_data1@extent)
        length(tp) <- 2

        # This should work through the redispatch mechanism
        results <- tileApply(mock_data1, mock_data2,
            tiles = tp,
            FUN = function(md1, md2) {
                list(
                    sum1 = sum(md1@data),
                    sum2 = sum(md2@data),
                    correlation = cor(md1@data, md2@data)
                )
            }
        )

        expect_length(results, 2)
        expect_true(all(sapply(results$sum1, is.numeric)))
        expect_true(all(sapply(results$sum2, is.numeric)))
        expect_true(all(sapply(results$correlation, function(x) sum(x) == -100)))
    })
})
