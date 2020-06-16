# Extract GAEZ data corresponding to subnational yield data used in ag sector.
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 4/17/2020

library(glue)
cilpath.r:::cilpath()

source(glue('{REPO}/agriculture/1_code/5_crop_shift/1_cleaning/extract_gaez/',
	        'functions/extract_gaez.R'))

# set up a df containing all the arguments we want
isos = c('ARG','BOL','BRA','CAN','CHL','CHN','COL', 'ECU', 'IDN', 'IND', 
	'JPN', 'KHM', 'LAO', 'LKA', 'MEX', 'MMR', 'MYS', 'NGA', 'NIC', 'PHL', 'SYR', 
	'THA', 'TZA', 'USA', 'VNM')
# don't forget about 'dryland_rice', and 'wetland_rice'
crops = c('cotton', 'maize', 'soy', 'wheat')
input_level = 'intermediate_inputs'
irrigation = 'rainfed'

args = expand.grid(
	isos=isos, 
	crops=crops, 
	input_level=input_level, 
	irrigation=irrigation)

all_data = mcmapply(
	extract_gaez_raster,
	iso = args$isos,
	crop = args$crops,
	input_level = args$input_level,
	irrigation = args$irrigation,
	mc.cores = cores,
	SIMPLIFY = FALSE
	) %>% 
	rbindlist(fill=TRUE, use.names=TRUE)
fwrite(
	all_data,
	glue('{SAC_SHARES}/',
		'estimation/agriculture/Data/2_intermediate/potential_yield/',
		'gaez_potential_yield_subnational.csv'))