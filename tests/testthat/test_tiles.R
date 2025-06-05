
test_that("spatialTilePlan can be created", {
    spatTI <- tilePlan()
    checkmate::expect_class(spatTI, "spatialTilePlan")
    expect_true(inherits(spatTI, "tilePlan"))
})

test_that("pixelTilePlan can be created", {
    pixelTI <- tilePlan("pixel")
    checkmate::expect_class(pixelTI, "pixelTilePlan")
    expect_true(inherits(pixelTI, "tilePlan"))
})

test_that("ext works", {
    x <- tilePlan()
    e <- c(0, 1000, 0, 1000)
    ext(x) <- e
    expect_identical(ext(x)[], ext(e)[])
})

test_that("pixel bound extraction works", {
    px <- tilePlan("pixel")
    px$pxdims <- c(1000, 1000)
    px$ncols <- 100
    px$nrows <- 100

    checkmate::expect_list(px[1], types = "numeric")
    expect_length(px[1:3], 3)
    expect_length(px[1:2, 1:3], 6)
    expect_length(px[2, 1:3], 3)
})

test_that("spat extent extraction works", {
    spat <- tilePlan("spatial")
    ext(spat) <- c(0, 1000, 0, 1000)
    length(spat) <- 20

    checkmate::expect_list(spat[1], types = "SpatExtent")
    expect_length(spat[1:3], 3)
    expect_length(spat[1:2, 1:3], 6)
    expect_length(spat[2, 1:3], 3)
})

test_that("pad setting works", {
    b1 <- 3
    b2 <- 10
    spat <- tilePlan("spatial")
    pix <- tilePlan("pixel")

    spat <- spat + b1
    pix <- pix + b1
    expect_equal(spat@pad, b1)
    expect_equal(pix@pad, b1)

    spat$pad <- b2
    pix$pad <- b2
    expect_equal(spat$pad, b2)
    expect_equal(pix$pad, b2)
})

test_that("pad behaves correctly - spatial", {
    a <- tilePlan("spatial")
    ext(a) <- c(0, 1000, 0, 1000)
    length(a) <- 20
    b <- a + 5

    e1 <- a[1]
    e2 <- b[1]
    expect_equal(e1[[1]][] + c(-5, 5, -5, 5), e2[[1]][])
})

test_that("pad behaves correctly - pixel", {
    a <- tilePlan("pixel")
    a$pxdims <- c(1000, 1000)
    a$ncols <- 100
    a$nrows <- 100
    b <- a + 5

    e1 <- a[1]
    e2 <- b[1]
    expect_equal(e1[[1]][] + c(0, 10, 0, 10), e2[[1]][])
})
