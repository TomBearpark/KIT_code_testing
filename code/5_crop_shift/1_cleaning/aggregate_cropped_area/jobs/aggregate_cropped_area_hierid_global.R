# Extract IR-level cropped area from SAGE.
# To be used to calculate chi globally.
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 5/27/2020

rm(list=ls())
library(parallel)
library(data.table)
library(glue)
cilpath.r:::cilpath()

source(glue('{REPO}/agriculture/1_code/5_crop_shift/1_cleaning/',
	        'aggregate_cropped_area/functions/aggregate_cropped_area.R'))

cropped_area = mclapply(
	X=list('maize', 'soybean', 'cassava', 'rice', 'wheat','sorghum',
		c('maize', 'soybean', 'cassava', 'rice', 'wheat','sorghum')),
	FUN=aggregate_planted_area,
	mc.cores=7
	) %>%
	rbindlist(use.names=TRUE)

fwrite(cropped_area,
	   glue('/shares/gcp/estimation/agriculture/Data/2_intermediate/',
	   	    'cropped_area/hierid/sage_planted_area_global.csv'))

arable_area = aggregate_arable_area()

fwrite(
	arable_area,
	glue('/shares/gcp/estimation/agriculture/Data/2_intermediate/',
		 'cropped_area/hierid/sage_arable_area_global.csv')
	)
