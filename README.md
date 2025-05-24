# GiottoTile

A lightweight R package for efficient spatial and pixel-based tiling operations on large datasets (currently only raster). GiottoTile provides easy-to-use tile iterators that enable memory-efficient processing of spatial data through parallelizable tile-based operations.

# Features

- Spatial Tiling: Create tiles based on spatial extents with automatic grid layout optimization
- Pixel-Exact Tiling: Define tiles using pixel coordinates for precise image processing
- Memory Efficient: Process large rasters without loading entire datasets into memory
- Parallel Processing: Built-in support for parallel execution via the {future} framework
- Flexible Buffering: Add padding around tiles to handle edge effects
- Metadata Support: Attach custom metadata to tiles for advanced workflows
- {terra} Integration: Seamless integration with the {terra} package for spatial data handling

# Installation
```r
# Install from GitHub
devtools::install_github("drieslab/GiottoTile")
```

# Quick Start
Spatial Tiling
```r
library(GiottoTile)
library(terra)

# Load a raster
f <- system.file("ex/elev.tif", package = "terra")
r <- rast(f)

# Create a spatial tile iterator
ti <- tileIterator("spatial")
ext(ti) <- ext(r)          # Set spatial extent
length(ti) <- 16           # Request 16 tiles (actual number may be higher)

# Check tile layout
plot(ti)

# Apply a function across tiles
outdir <- tempdir()
tileApply(r, ti = ti, FUN = function(x, .I) {
    writeRaster(x, file.path(outdir, sprintf("tile_%03d.tif", .I)))
})
```

# Pixel Tiling

```r
# Create a pixel-based tile iterator
pti <- tileIterator("pixel")
pti$pxdims <- c(500, 500)  # 500x500 pixel raster
pti$ncols <- 100           # 100 pixel tiles
pti$nrows <- 100           # 100 pixel tiles

# Check dimensions
dim(pti)     # Grid dimensions
length(pti)  # Total number of tiles

# Apply processing with pixel tiles
tileApply(r, ti = pti, FUN = function(x) {
    # Process each 100x100 pixel tile
    mean(values(x), na.rm = TRUE)
})
```

# Core Classes

`tileIterator`

Virtual base class for all tile iterators with common functionality:

- Tile indexing with `[i]` and `[i,j]` notation
- Buffering with `+` and `-` operators
- Metadata management with `$` accessor
- Plotting capabilities

`spatialTileIterator`

For spatial extent-based tiling:

- Define tiles using geographic coordinates
- Automatic grid layout optimization
- {terra} `SpatExtent` integration

```r
ti <- tileIterator("spatial")
ext(ti) <- c(0, 100, 0, 100)  # xmin, xmax, ymin, ymax
length(ti) <- 9               # Request 9 tiles
dim(ti)                       # Returns [3, 3] - actual grid layout
```

`pixelTileIterator`

For pixel-exact tiling:

- Define tiles using pixel coordinates
- Precise control over tile dimensions
- Ideal for image processing workflows

```r
pti <- tileIterator("pixel")
pti$pxdims <- c(1000, 1000)  # Total image dimensions
pti$ncols <- 250             # Pixels per tile (width)
pti$nrows <- 250             # Pixels per tile (height)
```

# Advanced Features

# Tile Buffering

Add padding around tiles to handle edge effects:
```r
# Add 10-unit buffer to all tiles
buffered_ti <- ti + 10

# Remove 5-unit buffer
reduced_ti <- ti - 5

# Preview buffered tiles
plot(buffered_ti, alpha = 0.3)
```

# Metadata Management

Attach custom metadata to tiles:

```r
# Add metadata
ti$processing_priority <- sample(1:3, length(ti), replace = TRUE)
ti$output_format <- "GTiff"

# Access metadata
ti$processing_priority
ti[[5]]  # Metadata for tile 5

# Metadata is preserved during tile selection
tile_data <- ti[5]
attr(tile_data[[1]], "processing_priority")
```

# Parallel Processing

Built-in support for parallel execution:

```r
library(future)
plan(multisession, workers = 4)

# Parallel tile processing
results <- tileApply(r, ti = ti, 
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
tile_5 <- ti[5]

# Multiple tiles
tiles_1_to_3 <- ti[1:3]

# Grid-based selection (row, column)
corner_tiles <- ti[1, c(1, ncol(ti))]

# All tiles
all_tiles <- ti[]
```

# Examples
Processing Large Satellite Images

```r
# Load large satellite image
large_raster <- rast("large_satellite_image.tif")

# Create efficient tiling scheme
ti <- tileIterator("spatial")
ext(ti) <- ext(large_raster)
length(ti) <- 100  # 100+ tiles for manageable processing

# Add buffer for edge effects
ti <- ti + 50  # 50-unit buffer

# Process tiles in parallel
plan(multisession, workers = 8)

results <- tileApply(large_raster, ti = ti,
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
pti <- tileIterator("pixel")
pti$pxdims <- c(nrow(image), ncol(image))
pti$ncols <- 512    # 512x512 pixel tiles
pti$nrows <- 512

# Process each tile
texture_metrics <- tileApply(image, ti = pti,
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

**terra**: Spatial data handling and raster operations
**checkmate**: Input validation
**future**.apply: Parallel processing support
**GiottoUtils**: Utility functions (part of Giotto ecosystem)

# Integration

GiottoTile is part of the broader Giotto ecosystem for spatial data analysis. It provides the foundational tiling capabilities used by other Giotto packages for efficient processing of large-scale spatial datasets.

# Contributing
Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.
