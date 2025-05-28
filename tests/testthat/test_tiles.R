
test_that("spatialTileIterator can be created", {
    spatTI <- tileIterator()
    checkmate::expect_class(spatTI, "spatialTileIterator")
    expect_true(inherits(spatTI, "tileIterator"))
})

test_that("pixelTileIterator can be created", {
    pixelTI <- tileIterator("pixel")
    checkmate::expect_class(pixelTI, "pixelTileIterator")
    expect_true(inherits(pixelTI, "tileIterator"))
})

test_that("ext works", {
    x <- tileIterator()
    e <- c(0, 1000, 0, 1000)
    ext(x) <- e
    expect_identical(ext(x)[], ext(e)[])
})

test_that("pixel bound extraction works", {
    px <- tileIterator("pixel")
    px$pxdims <- c(1000, 1000)
    px$ncols <- 100
    px$nrows <- 100

    checkmate::expect_list(px[1], types = "numeric")
    expect_length(px[1:3], 3)
    expect_length(px[1:2, 1:3], 6)
    expect_length(px[2, 1:3], 3)
})

test_that("spat extent extraction works", {
    spat <- tileIterator("spatial")
    ext(spat) <- c(0, 1000, 0, 1000)
    length(spat) <- 20

    checkmate::expect_list(spat[1], types = "SpatExtent")
    expect_length(spat[1:3], 3)
    expect_length(spat[1:2, 1:3], 6)
    expect_length(spat[2, 1:3], 3)
})

test_that("buffer setting works", {
    b1 <- 3
    b2 <- 10
    spat <- tileIterator("spatial")
    pix <- tileIterator("pixel")

    spat <- spat + b1
    pix <- pix + b1
    expect_equal(spat@buffer, b1)
    expect_equal(pix@buffer, b1)

    spat$buffer <- b2
    pix$buffer <- b2
    expect_equal(spat$buffer, b2)
    expect_equal(pix$buffer, b2)
})

test_that("buffer behaves correctly - spatial", {
    a <- tileIterator("spatial")
    ext(a) <- c(0, 1000, 0, 1000)
    length(a) <- 20
    b <- a + 5

    e1 <- a[1]
    e2 <- b[1]
    expect_equal(e1[[1]][] + c(-5, 5, -5, 5), e2[[1]][])
})

test_that("buffer behaves correctly - pixel", {
    a <- tileIterator("pixel")
    a$pxdims <- c(1000, 1000)
    a$ncols <- 100
    a$nrows <- 100
    b <- a + 5

    e1 <- a[1]
    e2 <- b[1]
    expect_equal(e1[[1]][] + c(0, 10, 0, 10), e2[[1]][])
})
