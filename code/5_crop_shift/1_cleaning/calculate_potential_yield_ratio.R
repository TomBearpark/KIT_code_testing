# Calculate the potential yield ratio: actual yield over potential yield
# Potential yield data comes from GAEZ, actual yield comes from the ag dataset

# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 3/3/2020

packages = c(
	'tidyverse', 'magrittr', 'data.table', 'glue', 'parallel', 'haven', 
	'admisc', 'countrycode'
	)
lapply(packages, library, character.only=TRUE)
cilpath.r:::cilpath()

ag = glue('{SAC_SHARES}/estimation/agriculture/Data/')

crop = 'corn'


# args for testing
iso = "ARG"
c = "corn"
adm_level = "adm2"

load_subnational_yield_data = function(crop) {
	yields = glue('{ag}/3_final/{crop}.dta') %>%
		read_dta() %>%
		data.table()

	ret = yields %>%
		dplyr::select(year, crop, iso, adm0, adm1, adm2, adm1_id, adm2_id, 
			yield, ln_yield, gdppc, gdppc_13br, loggdppc, loggdppc_13br,
			gdppc_adm0_PWT, loggdppc_adm0_PWT) %>%
		mutate(
			gdppc_2 = gdppc^2,
			loggdppc_2 = loggdppc^2
			)

	return(ret)
}

load_national_yield_data = function(c) {
	yields = glue('{ag}/1_raw/7_national_yields/fao_country_level_crop_yields.csv') %>%
		fread() %>%
		mutate(
			crop = admisc::recode(
				Item,
				"
				'Cotton lint' = 'cotton';
				Maize = 'corn';
				Soybeans = 'soy';
				Wheat = 'wheat'
				"
				),
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
				),
			# convert yields from hectograms per hectare to kg per hectare
			yield = Value / 10,
			ln_yield = log(yield)
			) %>%
		rename(
			year = Year
			) %>%
		filter(crop == c) %>%
		dplyr::select(year, iso, crop, yield, ln_yield)

	return(yields)
}

merge_and_calculate_ratio = function(
	c, 
	max_value=10, 
	country_level=FALSE,
	pool = FALSE,
	...) {
	kwargs = list(...)
	
	message(glue('Loading yield data for {c} \n'))
	if (country_level == FALSE) {
		yields = mclapply(
			c, 
			load_subnational_yield_data,
			mc.cores = cores,
			mc.cleanup = TRUE
			) %>%
			rbindlist() %>%
			filter(!is.na(yield), !is.na(gdppc), !is.na(loggdppc))	

		group_vars = quos(iso, adm1_id, adm2_id)
		group_vars_str = c('iso', 'adm1_id', 'adm2_id')
	} else {
		yields = mclapply(
			c,
			load_national_yield_data,
			mc.cores = cores,
			mc.cleanup = TRUE
			) %>%
		rbindlist() %>%
		filter(!is.na(yield))

		gdp = glue(
			'{SAC_SHARES}/estimation/agriculture/Data/1_raw/1_income/',
			'PennWorldTables/pwt90.dta'
			) %>%
			read_dta() %>%
			rename(iso = countrycode)

		# get the inflation factor to turn everything into 2005 dollars
		price_level = gdp %>%
			filter(iso == 'USA' & year == 2005) %>%
			pull(pl_gdpo)

		gdp %<>%
			mutate(
				gdppc = price_level * rgdpna / pop,
				loggdppc = log(gdppc),
				gdppc_2 = gdppc^2,
				loggdppc_2 = loggdppc^2
				) %>%
			select(iso, country, year, gdppc, gdppc_2, loggdppc, loggdppc_2)

		yields = merge(yields, gdp, by = c('year', 'iso'), all.x = TRUE)

		group_vars = quos(iso)
		group_vars_str = c('iso')
	}
	
	max_years = yields %>%
		group_by(iso) %>%
		summarize(max_year = max(year)) %>%
		# PWT data ends in 2014. To account for this, we will only calculate 
		# up to 2014
		mutate(max_year = ifelse(max_year > 2014, 2014, max_year))

	yields_prepped = yields %>% 
		merge(max_years, by='iso') %>%
		# keep only the final 10 years of data, and take an average
		filter(year >= max_year - 9 & year <= max_year) %>%
		dplyr::select(-max_year) %>%
		group_by(!!!group_vars, crop) %>%
		summarize(
			avg_yield = mean(yield),
			avg_logyield = mean(ln_yield),
			avg_gdppc = mean(gdppc),
			avg_gdppc_2 = mean(gdppc_2),
			avg_loggdppc = mean(loggdppc),
			avg_loggdppc_2 = mean(loggdppc_2)
			) %>%
		ungroup()

	if (country_level == FALSE) {
		potential_yields = glue('{SAC_SHARES}/',
			'estimation/agriculture/Data/2_intermediate/potential_yield/',
			'gaez_potential_yield_subnational.csv') %>%
			fread()
	} else {
		potential_yields = glue('{SAC_SHARES}/',
			'estimation/agriculture/Data/2_intermediate/potential_yield/',
			'gaez_potential_yield_national.csv') %>%
			fread()
	}

	p_yields = potential_yields %>%
		mutate(crop = ifelse(crop == 'maize', 'corn', crop)) %>%
		filter(crop %in% c) %>%
		# convert from tonnes per hectare to kg per hectare
		mutate(
			potential_yield = potential_yield * 1000,
			log_potential_yield = log(potential_yield)
			)

	message('Merging with GAEZ and calculating ratios')
	merged = merge(yields_prepped, p_yields, by=c(group_vars_str, 'crop'))
	
	if (pool == TRUE) {
		# get totals across crops before calculating ratio
		merged %<>% 
			group_by(!!!group_vars) %>%
			summarize(
				avg_yield = sum(avg_yield),
				potential_yield = sum(potential_yield),
				avg_loggdppc = mean(avg_loggdppc),
				avg_loggdppc_2 = mean(avg_loggdppc_2),
				avg_gdppc = mean(avg_gdppc),
				avg_gdppc_2 = mean(avg_gdppc_2),
				input_level = first(input_level),
				irrigation = first(irrigation)
				) %>%
			ungroup() %>%
			mutate(
				log_potential_yield = log(potential_yield),
				avg_logyield = log(avg_yield)
				)
	}

	ret = merged %>%
		mutate(
			ratio = ifelse(
				potential_yield > 0,
				avg_yield / potential_yield,
				NA
				),
			log_ratio = ifelse(
				potential_yield > 0,
				avg_logyield / log_potential_yield,
				NA
				)
			)
			# replace large ratios with a cap (set by max_value).
	obs = nrow(ret)
	over_max_obs = ret %>% filter(ratio > max_value) %>% nrow()

	warning(glue(
		'Clipping ratio at max value of {max_value}. ',
		'{over_max_obs} observation(s) affected, ',
		'{round(100*(over_max_obs/obs), 0.01)}% of the data.'
		))
	
	ret %<>%
		mutate(	
			ratio = ifelse(
				!is.na(ratio), 
				ifelse(
					ratio > max_value,
					max_value,
					ratio
					),
				NA
				),
			log_ratio = ifelse(
				!is.na(log_ratio),
				ifelse(
					log_ratio > log(max_value),
					log(max_value),
					log_ratio),
				NA
				)
		)

	return(ret)
}

