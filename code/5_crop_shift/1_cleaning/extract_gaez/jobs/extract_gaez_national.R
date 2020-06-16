# Extract GAEZ data corresponding to national yield data obtained from the FAO.
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 4/17/2020

library(glue)
cilpath.r:::cilpath()

source(glue('{REPO}/agriculture/1_code/5_crop_shift/1_cleaning/extract_gaez/',
	        'functions/extract_gaez.R'))

isos = glue('{input}/7_national_yields/fao_country_level_crop_yields.csv') %>%
		fread() %>%
		mutate(
			iso = countrycode(
				sourcevar = `Area Code`,
				origin = 'fao',
				destination = 'iso3c'
				),
			# recode the ones that countrycode couldn't handle
			# using this crosswalk: http://www.fao.org/countryprofiles/iso3list/en/
			# note that the only ones we can reconcile are China and Palestine.
			# All others are former USSR, so we don't need them since we are
			# only looking in the last 10 yrs of data
			iso = ifelse(
				is.na(iso),
				ifelse(
					`Area Code` == 41, 
					'CHN',
					ifelse(
						`Area Code` == 299,
						'PSE',
						NA
						)
					),
				iso
				)
			) %>%
		filter(!is.na(iso)) %>%
		pull(iso) %>%
		unique()

# don't forget about 'dryland_rice', and 'wetland_rice'
crops = c('cotton', 'maize', 'soy', 'wheat')
input_level = 'intermediate_inputs'
irrigation = 'rainfed'

args = expand.grid(
	isos=isos,
	crops=crops,
	input_level=input_level,
	irrigation=irrigation)

# try to optimize this by running the big countries first, forcing the system
# to parallelize over them and avoiding holding up other jobs
big_countries = c('BRA', 'IND', 'RUS', 'CAN', 'CHN', 'USA', 'AUS', 'KAZ', 'DZA',
	'DRC', 'KSA', 'MEX', 'IDN', 'GRL')

run_first = args %>% filter(isos %in% big_countries)
run_next = args %>% filter(!(isos %in% big_countries))
args = rbind(run_first, run_next)

all_data_country = mcmapply(
	extract_gaez_raster,
	iso = args$isos,
	crop = args$crops,
	input_level = args$input_level,
	irrigation = args$irrigation,
	MoreArgs = list(country_level=TRUE),
	SIMPLIFY = FALSE,
	mc.cores = cores,
	mc.cleanup = TRUE
	) %>%
	rbindlist(fill=TRUE, use.names=TRUE)

fwrite(
	all_data_country,
	glue('{SAC_SHARES}/',
		'estimation/agriculture/Data/2_intermediate/potential_yield/',
		'gaez_potential_yield_national.csv')
	)