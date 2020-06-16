# Extract county-level US cropped area from SAGE.
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 4/20/2020

rm(list=ls())
library(parallel)
library(data.table)
library(glue)
cilpath.r:::cilpath()

source(glue('{REPO}/agriculture/1_code/5_crop_shift/1_cleaning/',
	        'aggregate_cropped_area/functions/aggregate_cropped_area.R'))

crop_data = aggregate_planted_area(
	crops = c('maize', 'cotton', 'soybean', 'cassava', 'rice', 'wheat','sorghum'), 
	iso='USA')

fwrite(crop_data,
	   glue('/shares/gcp/estimation/agriculture/Data/2_intermediate/',
	   	    'cropped_area/hierid/sage_planted_area_usa.csv'))

arable_area = aggregate_arable_area(iso='USA')

fwrite(
	arable_area,
	glue('/shares/gcp/estimation/agriculture/Data/2_intermediate/',
		 'cropped_area/hierid/sage_arable_area_usa.csv')
	)
