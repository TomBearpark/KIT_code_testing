# Aggregate cropped area
Code in these directories aggregates cropped area data from SAGE rasters.

## `functions/`
This directory contains two scripts:
- `aggregate_cropped_area.R`: Defines `aggregate_cropped_area()`, a function to extract values from SAGE rasters and aggregate them to user-specified regions.
- `calculate_empty_area.R` (in progress): Defines `calculate_empty_area()`, a function to calculate the amount of arable land that is uncultivated in the SAGE rasters.

## `jobs/`
Scripts in this directory apply the functions defined in `scripts/aggregate_cropped_area.R` and `scripts/calculate_empty_area.R`.
- `aggregate_cropped_area_ACP.R` extracts SAGE data at the county level in the USA for use with the ACP climate change impacts projections.
- `aggregate_cropped_area_hierid_global.R` extracts SAGE data at the impact region level globally for use with impacts projection from the agriculture sector.

## Additional notes
- It may be worth looking into the data quality rasters provided by SAGE. These provide information on where the data in the raster comes from, and in particular whether it is interpolated. For regressions, it may be preferable to down-weight or exclude the interpolated data.
