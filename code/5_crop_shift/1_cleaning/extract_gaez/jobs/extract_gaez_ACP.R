# Extract county-level US data from GAEZ for use with agricultural impacts
# projections from the ACP. Both the ACP impacts and this GAEZ data will 
# be used for testing out the crop reallocation algorithm.
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 4/17/2020

library(glue)
cilpath.r:::cilpath()

source(glue('{REPO}/agriculture/1_code/5_crop_shift/1_cleaning/extract_gaez/',
	        'functions/extract_gaez.R'))

# first do a version where weights are crop-specific
usa_data = mclapply(
	list('maize', 'cotton', 'soy'),
	extract_gaez_raster,
	iso='USA', input_level='intermediate_inputs',
	irrigation='rainfed', hierid=TRUE,
	mc.cores=3
	) %>%
	rbindlist(fill=TRUE, use.names=TRUE)

fwrite(
	usa_data,
	glue('{SAC_SHARES}/',
		'estimation/agriculture/Data/2_intermediate/potential_yield/',
		'hierid/cropwt/gaez_potential_yield_usa.csv')
	)

# then a version where we use general cropweights
usa_data = mclapply(
	list('maize', 'cotton', 'soy'),
	extract_gaez_raster,
	iso='USA', input_level='intermediate_inputs',
	irrigation='rainfed', hierid=TRUE, weighting='all_crop',
	mc.cores=3
	) %>%
	rbindlist(fill=TRUE, use.names=TRUE)

fwrite(
	usa_data,
	glue('{SAC_SHARES}/',
		'estimation/agriculture/Data/2_intermediate/potential_yield/',
		'hierid/allcropwt/gaez_potential_yield_usa.csv')
	)
