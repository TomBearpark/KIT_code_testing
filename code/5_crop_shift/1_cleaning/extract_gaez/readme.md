# Extract GAEZ potential yield data
Code in these directories extracts potential crop yield data from GAEZ rasters and aggregates them to regions.

## `functions/`
This directory contains two scripts:
- `extract_gaez.R`: the script doing most of the work. Defines a function, `extract_gaez_raster()`, which takes values from a GAEZ raster and aggregates them using user-specified crop weights and a user-specified shapefile. Scripts in the `jobs` directory call this function.
- `map_gaez.R`: a script to map extracted GAEZ data as a check.

## `jobs/`
Scripts in this directory apply the `extract_gaez_raster()` function, defined in `extract_gaez.R`.
-  `extract_gaez_ACP.R` extracts GAEZ data at the county level in the USA for use with ACP climate change impacts projections.
- `extract_gaez_national.R` extracts GAEZ data at the country level for use with FAO country-level yield data.
- `extract_gaez_subnational.R` extracts GAEZ data at various subnational levels for use with the subnational yield data used for impacts projections from the agriculture sector.