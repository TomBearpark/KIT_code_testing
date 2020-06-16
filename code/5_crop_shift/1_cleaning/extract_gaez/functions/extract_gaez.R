# Extract GAEZ data and aggregate it
# Based on 1_code/2_analysis/4_gaez_data/1_gaez_data_extraction.R, by Lau
# This script is designed to have greater flexibility over which GAEZ model 
# is used. The script defines general functions that can be called by other
# scripts (see extract_gaez_national.R for example).
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 1/22/2020

library(tidyverse)
library(magrittr)
library(glue)
library(data.table)
library(raster)
library(sf)
library(rlang)
library(parallel)
library(testthat)
library(ddpcr)
library(countrycode)
cilpath.r:::cilpath()
cores = detectCores()

# this is where all GAEZ data are stored. 
# To use a new GAEZ product with this script, download it from 
# http://gaez.fao.org/Main.html and put it at the below path 
# (if you can get the website to work).
input = glue('{SAC_SHARES}/estimation/agriculture/Data/1_raw/')
shp_input = glue('{SAC_SHARES}/estimation/agriculture/Data/1_raw/')

get_subnational_shapefile_info = function(iso) {
	# function to get the name of the shapefile we want for each iso
	# I put this in a separate function to avoid complicating extract_gaez_raster
	# note that it might be best to even call this function from a separate script
	isolist = c('ARG','BOL','BRA','CAN','CHL','CHN','COL', 'ECU', 'EU', 'IDN', 
		'IND', 'JPN', 'KHM', 'LAO', 'LKA', 'MEX', 'MMR', 'MYS', 'NGA', 'NIC', 
		'PHL', 'SYR', 'THA', 'TZA', 'USA', 'VNM')
	adm2list = c('ARG', 'BRA', 'LAO', 'IND', 'TZA', 'EU', 'CHN', 'USA', 'MEX')

	if (!(iso %in% isolist)) {
		stop(glue('get_subnational_shapefile_info not implemented for {iso}.'))
	}
	shpdir = glue('{shp_input}/{iso}/shapefile/')

	#Specify shapefile name for shapefiles with several resolutions
	if (iso == 'TZA' | iso == 'LAO' | iso == 'BRA') {
		filename = Sys.glob(glue('{shpdir}*adm2*.shp'), dirmark= FALSE)
	} else if (iso == 'EU') {
		filename = Sys.glob(paste0(shpdir,'*NUTS2*.shp'), dirmark= FALSE)
	} else if (iso == 'MEX') {
		filename = list.files(shpdir, pattern = '\\Municipalities.shp$')
	} else {	
		filename = list.files(shpdir, pattern = '\\.shp$')
	}
	# remove the extension
	shpname = str_sub(filename, 1, -5)
	# remove the path (eg /shares/gcp/shp becomes shp)
	shpname = gsub('\\/?\\w+\\/', '\\1', shpname)
	# get adm id names
	if (iso %in% adm2list) {
		if (iso == 'CHN'){
			adm_id_1 = quo(PROVGB)
			adm_id_2 = quo(CNTYGB)
		} else if (iso == 'IND') {
 			adm_id_1 = quo(NAME_1)
			adm_id_2 = quo(NAME_2)
		} else if (iso == 'EU') {
			adm_id_1 = NULL
			adm_id_2 = quo(NUTS_ID)
		} else {
			adm_id_1 = quo(ID_1)
			adm_id_2 = quo(ID_2)
		}
	} else {
		adm_id_1 = quo(ID_1)
		adm_id_2 = NULL
	}

	return(list(shpname=shpname, adm_id_1=adm_id_1, adm_id_2=adm_id_2))
}

get_national_shapefile_info = function() {
	return(list(shpname='gadm36_0', adm_id_1=NA, adm_id_2=NA))
}

#' Function to extract potential yield data from a GAEZ raster and aggregate it
#' to regions according to user-specified weights.
#' @param crop String. The crop you want to aggregate for.
#' @param input_level String. The input level in the GAEZ raster. Currently only
#'     data for 'intermediate-inputs' is available.
#' @param irrigation String. The irrigation level in the GAEZ raster. Currently
#'     only data for 'rainfed' is available.
#' @param aggregation String. The aggregation level desired. Accepts 'country_level'
#'     or 'hierid'.
#' @param iso String. The iso-3 code for the country to do the aggregation for.
#'     If NULL, every country in the shapefile is aggregated.
#' @param weighting String. The weighting scheme to use. Either 'crop_specific',
#'     which will use planted area of the crop being aggregated as the weights,
#'     or 'all_crop', which will weight by all planted area.
#' @param filepath String. The path to the GAEZ data.
#' @param filename String. The name of the GAEZ datasets.
#' @param shppath String. The path to the shapefile.
#' @return Dataframe of potential yields by region in the shapefile.
extract_gaez_raster = function(
	crop,
	input_level,
	irrigation,
	aggregation,
	iso=NULL,
	weighting='crop_specific',
	filepath=input,
	filename='data.asc',
	shppath=shp_input
	) {
	# function to extract a gaez raster and aggregate it to a shapefile

	message(
		glue('BEGIN: {iso} {crop}')
		)

	# get the shapefile info
	if (aggregation == 'country_level') {
		shpinfo = get_national_shapefile_info()
		shppath_iso = glue('{shppath}/8_GADM/gadm36_levels_shp/')
	} else if (aggregation == 'hierid') {
		shpinfo = list(
			shpname = 'new_shapefile',
			adm_id_1 = NULL,
			adm_id_2 = 'hierid'
			)
		shppath_iso = glue('{SAC_SHARES}/climate/_spatial_data/world-combo-new-nytimes')
	} else {
		shpinfo = get_subnational_shapefile_info(iso)
		shppath_iso = glue('{shppath}/{iso}/shapefile/')
	}
	
	shpname = shpinfo$shpname
	adm_id_1 = shpinfo$adm_id_1
	adm_id_2 = shpinfo$adm_id_2
	
	quiet( # do this step quietly
		assign(
			'shp',
			st_read(dsn=shppath_iso, layer=shpname, stringsAsFactors=FALSE)
			)
		)

	if (aggregation == 'country_level') {
		# filter global shapefile to include only the current country
		shp %<>%
			dplyr::filter(GID_0 == iso) %>%
			rename(ISO = GID_0)
	}
	if (aggregation == 'hierid' & !is.null(iso)) {
		# filter the hierid data to just one country if desired
		shp %<>% dplyr::filter(ISO == iso)
	}

	ext = extent(shp)

	if (is.null(shp$ISO)) {
		shp$ISO = iso
	}

	gaez = raster(
		glue('{filepath}/6_GAEZ/potential_yield/{crop}/{input_level}/',
		'{irrigation}/{filename}')
		)

	# crop the raster to the country we're extracting for speed
	gaez_cropped = raster::crop(x=gaez, y=ext)

	# weight the raster by cropped area
	# there are two options here: crop_specific (the default), and all_crop.
	# crop_specific will weight the raster according the cropped area of the
	# specific crop you are weighting for.
	# all_crop will weight according to cropped area of any crop.
	if (weighting == 'crop_specific') {
		raster_crop = ifelse(crop == 'soy', 'soybean', crop)

		cropped_area = raster(
			glue('{filepath}/3_cropped_area/{raster_crop}_HarvAreaYield2000_Geotiff/',
				'{raster_crop}_HarvestedAreaHectares.tif')
			)

	} else if (weighting == 'all_crop') {
		raster_crop = 'cropland'
		cropped_area = raster(
			glue('{filepath}/3_cropped_area/CroplandPastureArea2000_Geotiff/',
			     'cropland2000_area_ha.tif')
			)
	} else {
		stop('weighting argument must be either \'crop_specific\' or \'all_crop\'.')
	}
	

	# replace any negative values with NAs
	gaez_cropped[gaez_cropped < 0] = NA
	cropped_area[cropped_area < 0] = NA

	# create a RasterStack object of the two files
	# for some countries, the grids are slightly off (despite being the same 
	# CRS and having the same extent.) Align the extents so be able to correctly
	# stack the rasters by resampling if necessary.
	stacked = tryCatch(
		{
			cropped_area = raster::crop(x=cropped_area, y=ext)
			raster::stack(gaez_cropped, cropped_area)
		},
		error = function(cond) {
			warning('Cannot stack rasters natively. Resample then stack.')
			cropped_area_mod = raster::resample(
				x = cropped_area,
				y = gaez_cropped,
				method = 'bilinear'
				)

			# cropped_area_mod = raster::crop(
			# 	x=cropped_area, 
			# 	y=alignExtent(ext, cropped_area, snap='in')
			# 	)

			stacked = raster::stack(gaez_cropped, cropped_area_mod)
			return(stacked)
		}, 
		finally = {}
	)

 	ret = raster::extract(
 		x = stacked,
 		y = shp,
 		weights = TRUE
 		)

 	# function to get a crop-weighted mean from each of the values outputted by ret
 	get_weighted_mean = function(i) {
 		r = ret[[i]] %>% as.data.frame()

 		varname = ifelse(weighting == 'crop_specific',
 					     glue('{raster_crop}_HarvestedAreaHectares'),
 					     glue('{raster_crop}2000_area_ha'))
 		r['pix_crops'] = r[varname] * r['weight']
 		
 		crop_total = sum(r['pix_crops'], na.rm=TRUE)
 		if (crop_total == 0) {
 			return(0)
 		}

 		r['cropwt'] = r['pix_crops'] / sum(crop_total)

 		total = sum(r[,'cropwt'], na.rm=TRUE)
 		if (!(abs(total - 1) <= 1e-10)) {
 			stop(glue('Weights do not sum to one! Index: {i}'))
 		}
 		
 		r = r[,!(names(r) %in% c(varname, 'pix_crops', 'weight'))]

 		ret_val = sum(r['data'] * r['cropwt'], na.rm=TRUE)

 		return(ret_val)
 	}

 	means = sapply(seq_along(ret), get_weighted_mean) %>%
 		as.data.frame()

 	colnames(means) = c('potential_yield')

 	# merge in admin region ids if desired
 	if (aggregation != 'country_level') {
 		# create data.frame of admin unit codes
		adm = shp %>%
				as.data.frame()
	
		if (is.null(adm_id_1)) {
			adm %<>% dplyr::select(!!adm_id_2) %>%
				rename(adm2_id = !!adm_id_2) %>%
				# for NUTS ids, get the NUTS1 by substringing the NUTS2
				mutate(adm1_id = substr(adm2_id, 1, 3))
		} else if (is.null(adm_id_2)) {
			adm %<>% dplyr::select(!!adm_id_1) %>%
				rename(adm1_id = !!adm_id_1) %>%
				# if our yield data is at adm1 level, replace adm1 with
				# the empty string
				mutate(adm2_id = '')
		} else {
			adm %<>% dplyr::select(!!adm_id_1, !!adm_id_2) %>%
				rename(adm1_id = !!adm_id_1, adm2_id = !!adm_id_2)
		}

 		means %<>% cbind(adm)
 	}

 	means %<>% mutate(
		iso = iso,
		crop = crop,
		input_level = input_level,
		irrigation = irrigation)

 	message(
		glue('DONE: {iso} {crop}')
		)

 	return(means)
}




