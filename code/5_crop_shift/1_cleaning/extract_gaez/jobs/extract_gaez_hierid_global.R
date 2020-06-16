# Extract impact region-level global data to calculate chi globally
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 5/27/2020

rm(list=ls())
library(glue)
library(parallel)
library(testthat)
cilpath.r:::cilpath()

source(glue('{REPO}/agriculture/1_code/5_crop_shift/1_cleaning/extract_gaez/',
	        'functions/extract_gaez.R'))

data = mclapply(
	list('maize', 'rice', 'soy', 'sorghum', 'cassava', 'wheat'),
	extract_gaez_raster,
	input_level='intermediate_inputs',
	irrigation='rainfed',
	aggregation='hierid',
	weighting='all_crop',
	mc.cores=6
	) %>%
	rbindlist(fill=TRUE, use.names=TRUE)

expect(nrow(data) == 24378 * 3, 'uh oh!')

fwrite(
	data,
	glue('/shares/gcp/estimation/agriculture/Data/2_intermediate/',
		 'potential_yield/hierid/allcropwt/gaez_potential_yield_global.csv')
	)