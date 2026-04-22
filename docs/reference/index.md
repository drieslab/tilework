# Package index

## Tile Plans

Classes and constructors for planning how data is divided into tiles.

- [`tilework-class`](https://drieslab.github.io/tilework/reference/tilework-class.md)
  :

  Virtual Class `tilework`

- [`tilePlan()`](https://drieslab.github.io/tilework/reference/tilePlan.md)
  : Create a Tiling Plan

- [`tilePlan-class`](https://drieslab.github.io/tilework/reference/tilePlan-class.md)
  : Tile Plan

- [`spatialTilePlan()`](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md)
  : Spatial Tile Plan

- [`pixelTilePlan()`](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md)
  : Pixel Tile Plan

- [`pointTilePlan()`](https://drieslab.github.io/tilework/reference/pointTilePlan-class.md)
  : Point Tile Plan

- [`freeTilePlan-class`](https://drieslab.github.io/tilework/reference/freeTilePlan-class.md)
  : Free Tile Plan

- [`freeTilePlan()`](https://drieslab.github.io/tilework/reference/freeTilePlan.md)
  : Create a Fluid Tile Plan

- [`quadtreePlan()`](https://drieslab.github.io/tilework/reference/quadtreePlan.md)
  : Adaptive Quadtree Tile Plan

## tile\* Methods

Common accessors and operators that work across all tile\* objects.

- [`` `[` ``](https://drieslab.github.io/tilework/reference/bracket.md)
  [`` `[<-`( ``*`<tileIterator>`*`,`*`<missing>`*`,`*`<missing>`*`)`](https://drieslab.github.io/tilework/reference/bracket.md)
  : Extract Bounds from Tile Object

- [`` `[[`( ``*`<tilePlan>`*`,`*`<numeric>`*`,`*`<missing>`*`)`](https://drieslab.github.io/tilework/reference/double_bracket.md)
  [`` `[[`( ``*`<tilePlan>`*`,`*`<missing>`*`,`*`<missing>`*`)`](https://drieslab.github.io/tilework/reference/double_bracket.md)
  [`` `[[`( ``*`<tilePlan>`*`,`*`<missing>`*`,`*`<character>`*`)`](https://drieslab.github.io/tilework/reference/double_bracket.md)
  [`` `[[`( ``*`<tilePlan>`*`,`*`<numeric>`*`,`*`<character>`*`)`](https://drieslab.github.io/tilework/reference/double_bracket.md)
  [`` `[[<-`( ``*`<tilePlan>`*`,`*`<numeric>`*`,`*`<character>`*`)`](https://drieslab.github.io/tilework/reference/double_bracket.md)
  [`` `[[<-`( ``*`<tilePlan>`*`,`*`<missing>`*`,`*`<character>`*`)`](https://drieslab.github.io/tilework/reference/double_bracket.md)
  : Get and set metadata

- [`` `$<-`( ``*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$`( ``*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$<-`( ``*`<freeTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$`( ``*`<freeTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$<-`( ``*`<pointTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$`( ``*`<pointTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$<-`( ``*`<pixelTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$`( ``*`<pixelTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$<-`( ``*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$`( ``*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$`( ``*`<tileSelection>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  [`` `$<-`( ``*`<tileSelection>`*`)`](https://drieslab.github.io/tilework/reference/dollar.md)
  : Get and Set Tile Metadata and Params

- [`` `+`( ``*`<tilePlan>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/arith.md)
  [`` `-`( ``*`<tilePlan>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/arith.md)
  [`` `+`( ``*`<pointTilePlan>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/arith.md)
  [`` `+`( ``*`<pixelTilePlan>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/arith.md)
  [`` `+`( ``*`<tileGroup>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/arith.md)
  [`` `-`( ``*`<tileGroup>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/arith.md)
  [`` `+`( ``*`<tileSelection>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/arith.md)
  [`` `-`( ``*`<tileSelection>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/arith.md)
  : Tile Pads

- [`ext(`*`<pointTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/ext.md)
  [`` `ext<-`( ``*`<pointTilePlan>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/ext.md)
  [`ext(`*`<spatialTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/ext.md)
  [`` `ext<-`( ``*`<spatialTilePlan>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/ext.md)
  : Get and Set Spatial Extent

- [`nrow(`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dim.md)
  [`ncol(`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dim.md)
  [`length(`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dim.md)
  [`dim(`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dim.md)
  [`` `length<-`( ``*`<spatialTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/dim.md)
  [`length(`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/dim.md)
  : Tile Plan Array Characteristics

- [`plot(`*`<tilePlan>`*`,`*`<missing>`*`)`](https://drieslab.github.io/tilework/reference/plot.md)
  [`plot(`*`<freeTilePlan>`*`,`*`<missing>`*`)`](https://drieslab.github.io/tilework/reference/plot.md)
  [`plot(`*`<pointTilePlan>`*`,`*`<missing>`*`)`](https://drieslab.github.io/tilework/reference/plot.md)
  [`plot(`*`<pixelTilePlan>`*`,`*`<missing>`*`)`](https://drieslab.github.io/tilework/reference/plot.md)
  :

  Plot a `tilePlan`

- [`centroids(`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/centroids.md)
  [`centroids(`*`<freeTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/centroids.md)
  [`centroids(`*`<pointTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/centroids.md)
  [`centroids(`*`<pixelTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/centroids.md)
  [`centroids(`*`<spatialTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/centroids.md)
  : Get Tile Centroids

- [`as.polygons(`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/as.polygons.md)
  [`as.polygons(`*`<freeTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/as.polygons.md)
  [`as.polygons(`*`<pointTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/as.polygons.md)
  [`as.polygons(`*`<spatialTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/as.polygons.md)
  : Coerce a tile plan to polygons

- [`intersect(`*`<tilePlan>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/intersect.md)
  [`intersect(`*`<freeTilePlan>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/intersect.md)
  [`intersect(`*`<spatialTilePlan>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/intersect.md)
  : Find tiles intersecting a spatial region

## Tile Orchestration

Tools for grouping, selecting, and iterating over tiles.

- [`tileGroup-class`](https://drieslab.github.io/tilework/reference/tileGroup-class.md)
  : Tile Group
- [`tileGroup()`](https://drieslab.github.io/tilework/reference/tileGroup.md)
  : Create a Tile Group
- [`tileIterator-class`](https://drieslab.github.io/tilework/reference/tileIterator-class.md)
  : tileIterator
- [`` `$`( ``*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/tileIterator.md)
  [`` `$<-`( ``*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/tileIterator.md)
  [`tileIterator()`](https://drieslab.github.io/tilework/reference/tileIterator.md)
  : Stateful Tile Iterator
- [`iterSplit(`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/iterSplit.md)
  : Create multiple walkers from a single iterator

## Tile Processing

Apply functions across tiles and extract data by bounds.

- [`tileApply(`*`<ANY>`*`,`*`<missing>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/tileApply.md)
  [`tileApply(`*`<ANY>`*`,`*`<ANY>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/tileApply.md)
  [`tileApply(`*`<token>`*`,`*`<ANY>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/tileApply.md)
  : Apply Functions Across Spatial Tiles
- [`tileApply(`*`<token>`*`,`*`<missing>`*`,`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/tileApply-plan.md)
  [`tileApply(`*`<token>`*`,`*`<token>`*`,`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/tileApply-plan.md)
  [`tileApply(`*`<token>`*`,`*`<missing>`*`,`*`<tileSelection>`*`)`](https://drieslab.github.io/tilework/reference/tileApply-plan.md)
  [`tileApply(`*`<token>`*`,`*`<token>`*`,`*`<tileSelection>`*`)`](https://drieslab.github.io/tilework/reference/tileApply-plan.md)
  : Basic Tile Processing
- [`tileApply(`*`<token>`*`,`*`<missing>`*`,`*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/tileApply-group.md)
  [`tileApply(`*`<token>`*`,`*`<token>`*`,`*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/tileApply-group.md)
  : Hierarchical Tile Group Processing
- [`tileApply(`*`<token>`*`,`*`<missing>`*`,`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/tileApply-iterator.md)
  [`tileApply(`*`<token>`*`,`*`<token>`*`,`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/tileApply-iterator.md)
  : Streaming Tile Processing with Iterators
- [`getTile(`*`<token>`*`,`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/getTile.md)
  [`getTile(`*`<ANY>`*`,`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/getTile.md)
  [`getTile(`*`<character>`*`,`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/getTile.md)
  [`getTile(`*`<SpatRaster>`*`,`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/getTile.md)
  [`getTile(`*`<SpatRaster>`*`,`*`<pointTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/getTile.md)
  [`getTile(`*`<ANY>`*`,`*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/getTile.md)
  [`getTile(`*`<ANY>`*`,`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/getTile.md)
  : Get Tile
- [`getBoundedData(`*`<SpatRaster>`*`,`*`<numeric>`*`)`](https://drieslab.github.io/tilework/reference/getBoundedData.md)
  [`getBoundedData(`*`<SpatRaster>`*`,`*`<SpatExtent>`*`)`](https://drieslab.github.io/tilework/reference/getBoundedData.md)
  [`getBoundedData(`*`<SpatVectorProxy>`*`,`*`<SpatExtent>`*`)`](https://drieslab.github.io/tilework/reference/getBoundedData.md)
  : Get Data Within Bounds

## Parallel Settings

Configure parallelization backends and logging.

- [`getTileworkParMethod()`](https://drieslab.github.io/tilework/reference/parallel_params.md)
  [`setTileworkParMethod()`](https://drieslab.github.io/tilework/reference/parallel_params.md)
  : Parallel Processing Parameters
- [`getTileworkLogDir()`](https://drieslab.github.io/tilework/reference/tilework_management.md)
  [`setTileworkLogDir()`](https://drieslab.github.io/tilework/reference/tilework_management.md)
  [`getTileworkJobID()`](https://drieslab.github.io/tilework/reference/tilework_management.md)
  : tilework management

## tilework Extension

Developer API for extending tilework to new data types.

- [`extending_tilework`](https://drieslab.github.io/tilework/reference/extending_tilework.md)
  : Extending {tilework}

- [`redispatch_tileapply(`*`<SpatRaster>`*`,`*`<freeTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<ANY>`*`,`*`<ANY>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<character>`*`,`*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatVector>`*`,`*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatRaster>`*`,`*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<ANY>`*`,`*`<tileGroup>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<character>`*`,`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatRaster>`*`,`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatVector>`*`,`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<ANY>`*`,`*`<tileIterator>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<character>`*`,`*`<tilePlan>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatVector>`*`,`*`<spatialTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatRaster>`*`,`*`<spatialTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatRaster>`*`,`*`<pixelTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatRaster>`*`,`*`<pointTilePlan>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<character>`*`,`*`<tileSelection>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatVector>`*`,`*`<tileSelection>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  [`redispatch_tileapply(`*`<SpatRaster>`*`,`*`<tileSelection>`*`)`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
  :

  *Developer API* Redispatch for
  [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)

- [`` `[`( ``*`<token>`*`,`*`<missing>`*`,`*`<missing>`*`,`*`<missing>`*`)`](https://drieslab.github.io/tilework/reference/token-class.md)
  :

  `token` Class
