# GiottoTile

Open source and S4 extensible framework for efficient spatial and pixel-based tiling operations on large datasets (currently only raster).
GiottoTile provides easy-to-use tile iterators that enable memory-efficient processing of spatial data through parallelizable tile-based operations.

This package is part of the Giotto Suite ecosystem for spatial-omics analysis, although the only other Giotto Suite package it depends on is {GiottoUtils}.

For another approach to spatially tiled computation, see: [chopin](https://github.com/ropensci/chopin/tree/main)

# Features

- Flexible Tiling: Support for both spatial extent-based and pixel-exact tiling
- Memory Efficient: Process tilewise or batchwise without loading entire datasets into memory
- Stateful Iteration: Iterator patterns for streaming and batch processing
- Parallel Processing: Built-in support for parallel execution via the {future} framework
- Flexible Padding: Add padding around tiles to handle edge effects
- Metadata Support: Attach custom metadata to tiles for advanced workflows
- Terra Integration: Seamless integration with the {terra} package for spatial data handling

# Installation
```r
# Install from GitHub
devtools::install_github("drieslab/GiottoTile")
```

# Quick Start

## Spatial Tiling

```r
library(GiottoTile)
library(terra)

# Load a raster
f <- system.file("ex/elev.tif", package = "terra")
r <- rast(f)

# Create a spatial tile iterator
tp <- tilePlan("spatial")
ext(tp) <- ext(r)          # Set spatial extent
length(tp) <- 16           # Request 16 tiles (actual number may be higher)

# Check tile layout
tp
dim(tp)
plot(tp)

# Extract specific tiles
tile_ext <- tp[5]  # Get 5th tile
tile_grid <- tp[1, 2:3]  # Get specific grid positions

# Apply a function across tiles
outdir <- tempdir()
tileApply(r, tp = tp, FUN = function(x, .I) {
    writeRaster(x, file.path(outdir, sprintf("tile_%03d.tif", .I)))
})
```

## Pixel Tiling

```r
# Create a pixel-based tile iterator
px <- tilePlan("pixel")
px$pxdims <- c(500, 500)  # 500x500 pixel raster
px$ncols <- 100           # 100 pixel tiles
px$nrows <- 100           # 100 pixel tiles

# Check dimensions
dim(px)     # Grid dimensions
length(px)  # Total number of tiles
plot(px)    # Visualize grid

# Apply processing with pixel tiles
tileApply(r, tp = px, FUN = function(x) {
    # Process each 100x100 pixel tile
    mean(values(x), na.rm = TRUE)
})
```

# Core Classes

**`tilePlan`**

Virtual base class for all tile iterators with common functionality:

- Tile indexing with `[i]` and `[i,j]` notation
- Padding with `+` and `-` operators
- Metadata management with `$` accessor
- Plotting capabilities

**`spatialTilePlan`**

For spatial extent-based tiling:

- Define tiles using geographic coordinates
- Automatic grid layout optimization
- {terra} `SpatExtent` integration

```r
tp <- tilePlan("spatial")
ext(tp) <- c(0, 100, 0, 100)  # xmin, xmax, ymin, ymax
length(tp) <- 9               # Request 9 tiles
dim(tp)                       # Returns [3, 3] - actual grid layout
```

**`pixelTilePlan`**

For pixel-exact tiling:

- Define tiles using pixel coordinates
- Precise control over tile dimensions
- Ideal for image processing workflows

```r
pti <- tilePlan("pixel")
pti$pxdims <- c(1000, 1000)  # Total image dimensions
pti$ncols <- 250             # Pixels per tile (width)
pti$nrows <- 250             # Pixels per tile (height)
```

**`tileGroup`**

Organize tiles groups. These are created on top of `tilePlan`
classes. These serve as lazy selection(s) of particular tiles of the 
underlying `tilePlan`.

```r
# Create groups that should be processed separately or differently
tg <- tileGroup(tp, groups = list(
  "quadrant1" = 1:4,           # First 4 tiles
  "quadrant2" = c(5, 6, 9, 10), # Specific tiles
  "border" = list(c(1,3), c(1,3)) # Grid-based selection
))

# Set active group for easy access
tg$active <- "quadrant1"
length(tg)  # Returns length of active group
tg[, 2]     # Second tile from active group
```

**`tileIterator`**

Stateful iterator for streaming processing. These can be created on top of 
`tilePlan` and `tileGroup` (when an active group is set) inheriting structures.
Use with `tileApply()` for distribution of batches across parallelized {future} 
workers.

```r
# Create iterator for batch processing
iter <- tileIterator(tp, batch_size = 3)

# Check status
iter$has_next
iter$remaining
iter$progress

# Process in batches
while (iter$has_next) {
  batch <- iter$next_batch()
  cat("Processing", length(batch), "tiles\n")
}

# Reset for another pass
iter$reset()
```

# Processing Data

## Basic Tile Extraction with `getTile()`

```r
# Load a raster file
f <- system.file("ex/elev.tif", package="terra")
r <- terra::rast(f)

# Create tile plan matching raster
tp <- tilePlan("pixel")
tp$pxdims <- dim(r)[1:2]
tp$nrows <- 100
tp$ncols <- 100

# Extract tiles
tiles <- getTile(r, tp, i = 1:4)  # Get first 4 tiles
tile_data <- getTile(r, tp, i = 3, j = 5)  # Get specific grid position
```

## Parallel Processing with `tileApply()`

Apply functions across tiles with automatic parallellization.

```r
# Process tiles in parallel
results <- tileApply(r, tiles = tp, FUN = function(x, .I) {
  # x is the tile raster data
  # .I is the tile number
  
  # Example: calculate mean value per tile
  terra::global(x, "mean", na.rm = TRUE)
})

# Save tiles to files
outdir <- tempdir()
tileApply(r, tiles = tp, FUN = function(x, .I, .R, .C) {
  # .R and .C provide row/col indices
  filename <- file.path(outdir, sprintf("tile_r%d_c%d.tif", .R, .C))
  terra::writeRaster(x, filename)
})
```

Depending on the class of tp, different parallelization schemes are used.

## Advanced Processing with Groups

```r
# Process different groups with different strategies
tileApply(r, tiles = tg, 
  parallel_strategy = "groups",  # Parallelize across groups
  FUN = function(x, .GROUP) {
    # Process based on group
    if (.GROUP == "border") {
      # Special processing for border tiles
      terra::focal(x, w = matrix(1/9, 3, 3))
    } else {
      # Standard processing
      x
    }
  }
)
```

# Advanced Features

## Tile Padding

Add padding around tiles to handle edge effects:
```r
# Add 10-unit padding to all tiles
padded_ti <- tp + 10

# Remove 5-unit padding
reduced_ti <- tp - 5

# Preview padded tiles
plot(padded_ti, alpha = 0.3)
```

## Metadata Management

Attach custom metadata to tiles:

```r
# Add metadata
tp$processing_priority <- sample(1:3, length(tp), replace = TRUE)
tp$output_format <- "GTiff"

# Access metadata
tp$processing_priority
tp[[5]]  # Metadata for tile 5

# Metadata is preserved during tile selection
tile_data <- tp[5]
attr(tile_data[[1]], "processing_priority")
```

## Iterator Splitting for Parallel Processing

Split iterators. This pattern is what powers the `tileApply()` method for `tileIterator`

```r
# Create base iterator
iter <- tileIterator(tp, batch_size = 5)

# Split across 4 workers
worker_iters <- iterSplit(iter, n = 4, distribute = TRUE)

# Each worker gets independent iterator with subset of tiles
sapply(worker_iters, function(x) x$remaining)
```

## Parallel Processing

Built-in support for parallel execution:

```r
library(future)
plan(multisession, workers = 4)

# Parallel tile processing
results <- tileApply(r, tp = tp, 
    cores = 4,
    FUN = function(x) {
        # Your processing function
        mean(values(x), na.rm = TRUE)
})
```

# Tile Selection and Indexing

Multiple ways to access tiles:

```r
# Single tile by index
tile_5 <- tp[5]

# Multiple tiles
tiles_1_to_3 <- tp[1:3]

# Grid-based selection (row, column)
corner_tiles <- tp[1, c(1, ncol(tp))]

# All tiles
all_tiles <- tp[]
```

# Best Practices

1. Memory Management: Use appropriate tile sizes to balance memory usage and processing efficiency
2. Pad Planning: Consider padding requirements for spatial operations to avoid edge effects
3. Parallel Strategy: Choose between parallelizing across groups vs. within groups based on your workflow
4. Metadata Usage: Leverage metadata for complex processing logic and file organization
5. Iterator Patterns: Use stateful iterators for streaming large datasets that don't fit in memory


# Examples
Processing Large Satellite Images

```r
# Load large satellite image
large_raster <- rast("large_satellite_image.tif")

# Create efficient tiling scheme
tp <- tilePlan("spatial")
ext(tp) <- ext(large_raster)
length(tp) <- 100  # 100+ tiles for manageable processing

# Add padding for edge effects
tp <- tp + 50  # 50-unit padding

# Process tiles in parallel
plan(multisession, workers = 8)

results <- tileApply(large_raster, tp = tp,
                    cores = 8,
                    FUN = function(x, .I) {
                        # Apply NDVI calculation
                        ndvi <- (x[[4]] - x[[3]]) / (x[[4]] + x[[3]])
                        
                        # Save processed tile
                        writeRaster(ndvi, 
                                   sprintf("ndvi_tile_%03d.tif", .I))
                        
                        # Return summary statistics
                        c(mean = mean(values(ndvi), na.rm = TRUE),
                          sd = sd(values(ndvi), na.rm = TRUE))
                    })
```
                    
# Pixel-Level Image Analysis

```r
# High-resolution image processing
image <- rast("high_res_image.tif")

# Create pixel-exact tiles
pti <- tilePlan("pixel")
pti$pxdims <- c(nrow(image), ncol(image))
pti$ncols <- 512    # 512x512 pixel tiles
pti$nrows <- 512

# Process each tile
texture_metrics <- tileApply(image, tp = pti,
                           FUN = function(x) {
                               # Calculate texture metrics
                               vals <- values(x)
                               list(
                                   contrast = var(vals, na.rm = TRUE),
                                   homogeneity = 1 / (1 + var(vals, na.rm = TRUE))
                               )
                           })
```

<hr>
 
Dependencies

* **terra**: Spatial data handling and raster operations
* **checkmate**: Input validation
* **future.apply**: Parallel processing support
* **GiottoUtils**: Utility functions (part of Giotto ecosystem)

# Integration

GiottoTile is part of the broader Giotto ecosystem for spatial data analysis. It provides the foundational tiling capabilities used by other Giotto packages for efficient processing of large-scale spatial datasets.

# Contributing
Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.
