# Calculate empty arable land in each gridcell and aggregate up to a shapefile.
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 6/4/2020

library(raster)
library(sf)
library(dplyr)
library(magrittr)
library(glue)
cilpath.r:::cilpath()

#' Take a weighted sum of extracted values from a raster.
#' Set up to proceed iteratively over a list of matrices returned by a call to
#' raster::extract.
#' @param l List. The list of matrices.
#' @param i Integer. The index in the list of matrices
#' @param from_fraction Boolean. Whether to extracted values by areas before
#'                      summing.
get_weighted_sum = function(l, i, from_fraction, layername='layer.1',
	                        areaname='layer.2') {
	r = l[[i]] %>% as.data.frame()

	r['tosum'] = ifelse(from_fraction,
		                r[layername] * r[areaname] * r['weight'],
		                r['value'] * r['weight'])

	ret_val = sum(r['tosum'], na.rm=TRUE)

	return(ret_val)
}

#' Sum two elements. If both are NAs, return NA. Else, sum with NA rm.
NA_sum = function(x, y) {
	return(
	   ifelse(is.na(x) & is.na(y),
		      NA,
		      sum(x, y, na.rm=TRUE))
	   )
}

#' Calculate the empty arable land in each gridcell and aggregate up to a
#' shapefile.
#' Arable land is defined as cropland and pastureland from SAGE.
#' To avoid negative empty area due to data error and minimize biased values
#' due to double-cropping, we calculate empty area as the difference between
#' the sum of crop- and pasturelands and of all the crop-specific cropped area
#' values we have at the gridcell level. We then aggregate up to the desired
#' level.
#' Calling this function with the defaults will aggregate arable area at the
#' Impact Region level globally.
#' @param filepath String. The path to the SAGE data.
#' @param shppath String. The path to the shapefile.
#' @param shplayer String. The name of the shapefile.
#' @param iso String. A 3-letter ISO code if you want to aggregate one country
#'            only.
aggregate_arable_area = function(
	filepath=glue('/shares/gcp/estimation/agriculture/',
		          'Data/1_raw/3_cropped_area'),
	shppath=glue('/shares/gcp/climate/_spatial_data/world-combo-new-nytimes'),
	shplayer='new_shapefile',
	regions='hierid',
	iso=NULL
	) {

	# load the shapefile we want to aggregate to
	shp = st_read(dsn=shppath, layer=shplayer, stringsAsFactors=FALSE)

	if (!is.null(iso)) {
		shp %<>% dplyr::filter(ISO==iso)
	}

	# load and combine cropland and pasture area data
	cropland = raster(
		glue('{filepath}/CroplandPastureArea2000_Geotiff/',
			 'cropland2000_area.tif')
		)
	pasture = raster(
		glue('{filepath}/CroplandPastureArea2000_Geotiff/',
			 'pasture2000_area.tif')
		)

	# crop the rasters to the extent of the shapefile
	ext = extent(shp)
	cropland = raster::crop(x=cropland, y=ext)
	pasture = raster::crop(x=pasture, y=ext)

	# For some reason these two rasters have slightly different extents,
	# despite being from the same source... resample then combine them.
	pasture_mod = raster::resample(x=pasture, y=cropland, method='bilinear')

	# add these two together to get arable land
	arable_area = raster::overlay(cropland, pasture_mod, fun=sum)

	# topcode at 1 (ie 100% of the gridcell is arable)
	# note this binds for >1% of all global gridcells and ~3% of global
	# gridcells with nonzero arable area
	arable_area[arable_area > 1] = 1

	# the values for cropland and pastureland are in fractions of the gridcells.
	# convert these to hectares before extracting.
	areas = raster::area(arable_area) * 100
	arable_area = raster::stack(arable_area, areas)

	# extract the arable area values for the shapefile regions
	arable_area_extracted = raster::extract(x=arable_area, y=shp, weights=TRUE,
		                                    normalizeWeights=FALSE)

	# aggregate
	arable_area_agg = sapply(seq_along(arable_area_extracted),
		                     get_weighted_sum,
		                     l=arable_area_extracted,
		                     from_fraction=TRUE) %>%
		as.data.frame()

	colnames(arable_area_agg) = 'arable_hectares'
	arable_area_agg[[regions]] = shp[[regions]]

	return(arable_area_agg)
}

#' Calculate total cropped area in a region
#' To do this, sum up area for all the crops we have gricell-level data for at
#' the gridcell level, then aggregate.
#' The reason for summing up at the gridcell level first is it minimizes the
#' possible double-counting from double-cropping.
#' Note that it is possible to get values for just one crop from this. Just
#' pass a single crop name to the `crops` argument.
#' @param filepath String. The path to the SAGE data.
#' @param shppath String. The path to the shapefile.
#' @param shplayer String. The name of the shapefile.
#' @param iso String. A 3-letter ISO code if you want to aggregate one country
#'            only.
#' @param crops Vector of strings. The list of crops to sum up.
aggregate_planted_area = function(
	crops = c('cassava', 'maize', 'rice', 'sorghum', 'soybean', 'wheat'),
	filepath=glue('/shares/gcp/estimation/agriculture/',
		          'Data/1_raw/3_cropped_area'),
	shppath=glue('/shares/gcp/climate/_spatial_data/world-combo-new-nytimes'),
	shplayer='new_shapefile',
	regions='hierid',
	iso=NULL
	) {
	# load the shapefile we want to aggregate to
	shp = st_read(dsn=shppath, layer=shplayer, stringsAsFactors=FALSE)

	if (!is.null(iso)) {
		shp %<>% dplyr::filter(ISO==iso)
	}
	# iteratively load, resample (if necessary), and finally combine each of
	# the cropped area rasters to calculate the values we need

	# initialize using first crop
    c = crops[1]
	stub = 'HarvAreaYield2000_Geotiff'
	prod = 'HarvestedAreaFraction'
        message(glue('{filepath}/{c}_{stub}/{c}_{prod}.tif'))
	all_crops = raster(glue('{filepath}/{c}_{stub}/{c}_{prod}.tif'))
	all_crops[all_crops > 1] = 1
	all_crops[all_crops < 0] = 0
	# crop to shapefile extent
	ext = extent(shp)
	all_crops = raster::crop(x=all_crops, y=ext)

	if (length(crops) > 1) {
		# loop over remaining crops
		for (c in crops[2:length(crops)]) {
			r = raster(glue('{filepath}/{c}_{stub}/{c}_{prod}.tif'))
			r[r > 1] = 1
			r[r < 0] = 0
			r = raster::crop(x=r, y=ext)
			all_crops = raster::overlay(all_crops, r,
				fun=function(x, y){
					return(mapply(NA_sum, x=x[], y=y[]))})
		}
	}

	# correct for places where total cropped area exceeds the area of the
	# gridcell (this could be because of double-cropping or data error; without
	# additional information it's not possible to tell)
	all_crops[all_crops > 1] = 1

	# convert from fractions of gridcells to hectares
	areas = raster::area(all_crops) * 100
	all_crops = raster::stack(all_crops, areas)

	# extract values for the regions in the shapefile
	all_crops_extracted = raster::extract(x=all_crops, y=shp, weights=TRUE,
		                                  normalizeWeights=FALSE)

	if (length(crops) == 1) {
		layername = glue('{crops[1]}_{prod}')
		areaname = 'layer'
	} else {
		layername = 'layer.1'
		areaname = 'layer.2'
	}

	# aggregate
	all_crops_agg = sapply(seq_along(all_crops_extracted),
		                   get_weighted_sum,
		                   l=all_crops_extracted,
		                   from_fraction=TRUE,
		                   layername=layername,
		                   areaname=areaname) %>%
		as.data.frame()

	colnames(all_crops_agg) = 'harvested_hectares'
	all_crops_agg[[regions]] = shp[[regions]]
	all_crops_agg$crops = list(crops)

	return(all_crops_agg)
}
