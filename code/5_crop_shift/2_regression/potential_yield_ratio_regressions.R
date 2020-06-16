# Build a predictive model of actual-to-potential yield ratios

# Code proceeds as follows:
# 1. Load data
# 2. Run regression(s)
# 3. Produce plots and other diagnostics
#	3.1. Scatters
#	3.2. Response functions
#	3.3. Maps

# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 3/5/2020

rm(list=ls())
packages = c('tidyverse', 'magrittr', 'data.table', 'glue', 'parallel', 'haven')
lapply(packages, library, character.only=TRUE)
cilpath.r:::cilpath()
cores = detectCores()

output = glue(
	'{DB}/GCP_Reanalysis/AGRICULTURE/4_outputs/2_regression_results/9_crop_shift/',
	'potential_yield_ratio'
	)

################
# 1. Load data #
################

# load functions that will allow us to prep the data
source(
	glue(
		'{REPO}/agriculture/1_code/5_crop_shift/1_cleaning/', 
		'calculate_potential_yield_ratio.R'
	)
)

########################
# 2. Run regression(s) #
########################

# might want to expand this into general functions. A task for later.
data = merge_and_calculate_ratio(c=crop, max_value=10)

run_model = function(y, x, data, title=NULL, slug=NULL, notes=NULL, ...) {
	kwargs = list(...)
	
	formula = as.formula(glue('{y} ~ {x}'))
	reg = lm(formula, data=data)

	notes = glue(
		notes,
		'\n N = {nobs(reg)}. R^2 = {round(summary(reg)$r.squared, 4)}'
		)

	return(list(reg=reg, data=data, title=title, slug=slug, notes=notes, x=x, y=y))	
}

reg_result = run_model(
	y = 'ratio',
	x = 'avg_loggdppc',
	data = data,
	slug = 'log_inc',
	title = 'Regression of actual to predicted yield ratio on log income',
	notes = ''
	)


####################
# 3. Produce plots #
####################

# 3.1 Scatters
##############

raw_data_scatter = function(crop, data, additional_notes="", ...) {
	kwargs = list(...)
		
	p = ggplot(data=data) +
		geom_point(aes(x=avg_loggdppc, y=avg_yield)) +
		theme_bw() +
		labs(
			title = 'Raw data scatter',
			caption = glue('{additional_notes}')
			)

	dir.create(
		glue('{output}/{crop}/scatters/'), 
		recursive = TRUE,
		showWarnings = FALSE)
	filename = glue('{output}/{crop}/scatters/{kwargs$reg_result$slug}_raw_data.pdf')

	ggsave(
		plot = p,
		filename = filename
		)

	message(glue('Saved {filename}'))
	return(glue('Saved {filename}'))
}

make_scatter = function(crop, reg_result, additional_notes="", ...) {
	kwargs = list(...)
	predicted_vals = data.frame(predicted=predict(reg_result$reg))
	resid = data.frame(residual=residuals(reg_result$reg))
	toplot = cbind(predicted_vals, resid) %>%
		mutate(actual = predicted + residual)
		
	p = ggplot(data=toplot) +
		geom_point(aes(x=actual, y=predicted)) +
		# add x=y line
		geom_abline(intercept=0) +
		theme_bw() +
		labs(
			title = reg_result$title,
			caption = glue('{reg_result$notes} \n {additional_notes}')
			)

	dir.create(
		glue('{output}/{crop}/scatters/'), 
		recursive = TRUE,
		showWarnings = FALSE)
	filename = glue('{output}/{crop}/scatters/{reg_result$slug}.pdf')

	ggsave(
		plot = p,
		filename = filename
		)

	message(glue('Saved {filename}'))
	return(glue('Saved {filename}'))
}

make_scatter(reg_result)

# 3.2 Response Functions
########################

make_rf = function(
	crop, reg_result, x_values, xlab, additional_notes = "", add_data=FALSE,
	return_gg=FALSE, ...) {
	kwargs = list(...)

	predicted_vals = data.frame(
		predicted = predict(
			object = reg_result$reg, 
			newdata = x_values,
			interval = "confidence",
			level = 0.95
			)
		) %>%
		cbind(x_values)

	if (is.null(kwargs$rf_xval)) {
		warning('No xval provided for response function. Defaulting to avg_loggdppc.')
		xval = quo(avg_loggdppc)
	} else {
		xval = kwargs$rf_xval
	}

	p = ggplot(data=predicted_vals) +
		geom_line(aes(x = !!xval, y = predicted.fit)) +
		geom_ribbon(
			aes(x = !!xval, ymin = predicted.lwr, ymax = predicted.upr), 
			alpha=0.2) +
		labs(
			x = xlab,
			y = 'predicted ratio',
			caption = glue('{reg_result$notes} \n {additional_notes}')
			) +
		theme_bw()

	if (add_data == TRUE) {
		p = p +
			geom_point(
				data=reg_result$data,
				aes(x = !!xval, 
					y = !!rlang::sym(reg_result$y))
				)

		rf_dir = 'response_functions_with_scatters'
	} else {
		rf_dir = 'response_functions'
	}

	if (return_gg == TRUE) {
		return(p)
	}

	dir.create(
		glue('{output}/{crop}/{rf_dir}/'), 
		recursive = TRUE, 
		showWarnings=FALSE)

	filename = glue('{output}/{crop}/{rf_dir}/{reg_result$slug}.pdf')
	ggsave(
		plot = p,
		filename = filename
		)

	message(glue('Saved {filename}'))
	return(glue('Saved {filename}'))
}

loggdp_p5 = quantile(data$avg_loggdppc, 0.05)
loggdp_p95 = quantile(data$avg_loggdppc, 0.95)

x_values = data.frame(avg_loggdppc = seq(floor(loggdp_p5), ceiling(loggdp_p95)))
make_rf(
	crop = 'corn', reg_result=reg_result, x_values=x_values, 
	xlab='log GDP per capita', add_data=T, return_gg = T)

# wrapper function to load data, run a regression, 
do_all = function(
	crop, 
	country_level=FALSE, 
	pooled=FALSE, 
	pre_pooled=FALSE,
	...) {
	kwargs = list(...)

	if (pooled == FALSE) {
		data = merge_and_calculate_ratio(
			c=crop, 
			country_level=country_level, 
			...)	
	} else {
		message('Preparing data for pooled regression')
		if (pre_pooled == TRUE) {
			message('Pooling, then calculating ratio')
			data = merge_and_calculate_ratio(
				c = crop,
				country_level = country_level,
				pool = TRUE,
				...)
		} else {
			message('Calculating ratio, then pooling')
			data = mclapply(
				crop,
				merge_and_calculate_ratio,
				country_level = country_level,
				mc.cores = cores,
				mc.cleanup = TRUE
				) %>%
				rbindlist()
		}
		crop = 'all'
	}

	data %<>% filter(!is.na(ratio))
	
	reg_result = run_model(data=data, ...)

	raw_data_scatter(data = data, crop = crop, reg_result = reg_result, ...)

	make_scatter(crop = crop, reg_result = reg_result, ...)

	# function to return a sequence from the 5th to the 95th percentile of a var
	# for plotting the response function
	get_x_vals = function(x, rf_xval=NULL, lb=0.05, ub=0.95, ...) {
		if (!is.null(rf_xval)) {
			var = quo_name(rf_xval)
		} else {
			var = x
		}

		data %<>% as.data.frame() %>%
			filter(!is.na(ratio))

		vector = data[,var]

		p5 = quantile(vector, lb, na.rm=TRUE)
		p95 = quantile(vector, ub, na.rm=TRUE)

		x_values = data.frame(x = seq(floor(p5), ceiling(p95)))
		names(x_values) = var

		# also return a squared version of the x variable, for the case
		# where we are regression on log GDP and log GDP squared.
		x_values[,glue('{var}_2')] = x_values[,var]^2

		return(x_values)
	}

	make_rf(
		crop = crop, 
		reg_result = reg_result, 
		x_values = get_x_vals(...), 
		...
		)

	# also make the rf with the scatter below it
	make_rf(
		crop = crop, 
		reg_result = reg_result, 
		x_values = get_x_vals(ub=1, lb=0, ...), 
		add_data = TRUE, 
		...
		)

	return(glue('Ran regression and plotted results for {crop}'))
}

# run on all the crops
# note: need to ask Lau about dryland vs. wetland rice vs. rice
# also, need to check on why there's no subnational cotton data. 
# maybe try something other than cotton lint?
crops = c('corn', 'soy', 'wheat')

mapply(
	do_all,
	crop = crops,
	MoreArgs = list(
		y = 'ratio', 
		x = 'avg_loggdppc', 
		slug = 'log_inc', 
		title = 'Regression of actual to predicted yield ratio on log income', 
		notes = 'Log income calculated as log of 10 year average of annual GDP',
		xlab = 'log GDP per capita'
		)
	)

# country level version
mapply(
	do_all,
	crop = crops,
	country_level = TRUE,
	MoreArgs = list(
		y = 'ratio', 
		x = 'avg_loggdppc', 
		slug = 'log_inc_country_level_all_countries',
		title = 'Regression of actual to predicted yield ratio on log income', 
		notes = 'Log income calculated as log of 10 year average of annual GDP',
		xlab = 'log GDP per capita'
		)
	)

# Pooled regressions
# 1. country level
# a. pool data after calculating ratio
do_all(
	crop = crops,
	country_level = TRUE,
	pooled = TRUE,
	y = 'ratio',
	x = 'avg_loggdppc', 
	slug = 'log_inc_country_level_all_countries_pooled_post_calculation',
	title = 'Regression of actual to predicted yield ratio on log income', 
	notes = glue(
		'Log income calculated as log of 10 year average of annual GDP. \n',
		'Ratios calculated for each country and crop,',
		' then pooled into a single regression.'),
	xlab = 'log GDP per capita'
	)

# b. pool data, then calculate ratio
do_all(
	crop = crops,
	country_level = TRUE,
	pooled = TRUE,
	pre_pooled = TRUE,
	y = 'ratio',
	x = 'avg_loggdppc', 
	slug = 'log_inc_country_level_all_countries_pooled_pre_calculation',
	title = 'Regression of actual to predicted yield ratio on log income',
	notes = glue(
		'Log income calculated as log of 10 year average of annual GDP. \n',
		'Actual and potential yields summed before calculating ratio.'),
	xlab = 'log GDP per capita'
	)

# c. pool data after calculation, use log ratios
do_all(
	crop = crops,
	country_level = TRUE,
	pooled = TRUE,
	y = 'log_ratio',
	x = 'avg_loggdppc', 
	slug = 'log_inc_log_ratio_country_level_all_countries_pooled_post_calculation',
	title = 'Regression of actual to predicted yield ratio on log income', 
	notes = glue(
		'Log income calculated as log of 10 year average of annual GDP. \n',
		'Ratios calculated for each country and crop,',
		' then pooled into a single regression.'),
	xlab = 'log GDP per capita'
	)

# d. pool data, then calculate ratio; use log ratios
do_all(
	crop = crops,
	country_level = TRUE,
	pooled = TRUE,
	pre_pooled = TRUE,
	y = 'ratio',
	x = 'avg_loggdppc',
	slug = 'log_inc_log_ratio_country_level_all_countries_pooled_pre_calculation',
	title = 'Regression of actual to predicted yield ratio on log income',
	notes = glue(
		'Log income calculated as log of 10 year average of annual GDP. \n',
		'Actual and potential yields summed before calculating ratio.'),
	xlab = 'log GDP per capita'
	)

# e. pool data after calculation; regress yield on linear (not log) income
do_all(
	crop = crops,
	country_level = TRUE,
	pooled = TRUE,
	y = 'ratio',
	x = 'avg_gdppc',
	rf_xval = quo(avg_gdppc),
	slug = 'inc_country_level_all_countries_pooled_post_calculation',
	title = 'Regression of actual to predicted yield ratio on linear income', 
	notes = glue(
		'Income calculated as 10 year average of annual GDP. \n',
		'Ratios calculated for each country and crop,',
		' then pooled into a single regression.'),
	xlab = 'GDP per capita'
	)

# f. pool data before calculation; regress yield on linear (not log) income
do_all(
	crop = crops,
	country_level = TRUE,
	pooled = TRUE,
	pre_pooled = TRUE,
	y = 'ratio',
	x = 'avg_gdppc',
	rf_xval = quo(avg_gdppc),
	slug = 'inc_country_level_all_countries_pooled_pre_calculation',
	title = 'Regression of actual to predicted yield ratio on linear income', 
	notes = glue(
		'Income calculated as 10 year average of annual GDP. \n',
		'Actual and potential yields summed before calculating ratio.'),
	xlab = 'GDP per capita'
	)

# g. pool data after calculation; regress yield on poly 2 of log income
do_all(
	crop = crops,
	country_level = TRUE,
	pooled = TRUE,
	y = 'ratio',
	x = 'avg_loggdppc + avg_loggdppc_2',
	rf_xval = quo(avg_loggdppc),
	slug = 'log_inc_poly_2_country_level_all_countries_pooled_post_calculation',
	title = 'Regression of actual to predicted yield ratio on quadratic log income', 
	notes = glue(
		'Log income calculated as log of 10 year average of annual GDP. \n',
		'Ratios calculated for each country and crop,',
		' then pooled into a single regression.'),
	xlab = 'log GDP per capita'
	)

# h. pool data before calculation; regress yield on poly 2 of log income
do_all(
	crop = crops,
	country_level = TRUE,
	pooled = TRUE,
	pre_pooled = TRUE,
	y = 'ratio',
	x = 'avg_loggdppc + avg_loggdppc_2',
	rf_xval = quo(avg_loggdppc),
	slug = 'log_inc_poly_2_country_level_all_countries_pooled_pre_calculation',
	title = 'Regression of actual to predicted yield ratio on quadratic log income', 
	notes = glue(
		'Log income calculated as log of 10 year average of annual GDP. \n',
		'Ratios calculated for each country and crop,',
		' then pooled into a single regression.'),
	xlab = 'log GDP per capita'
	)

# 2. subnational
# a. pool data after calculating ratio
do_all(
	crop = crops,
	country_level = FALSE,
	pooled = TRUE,
	y = 'ratio',
	x = 'avg_loggdppc', 
	slug = 'log_inc_pooled_post_calculation',
	title = 'Regression of actual to predicted yield ratio on log income', 
	notes = glue(
		'Log income calculated as log of 10 year average of annual GDP. \n',
		'Ratios calculated for each country and crop,',
		' then pooled into a single regression.'),
	xlab = 'log GDP per capita'
	)

# b. pool data, then calculate ratio
do_all(
	crop = crops,
	country_level = FALSE,
	pooled = TRUE,
	pre_pooled = TRUE,
	y = 'ratio',
	x = 'avg_loggdppc', 
	slug = 'log_inc_pooled_pre_calculation',
	title = 'Regression of actual to predicted yield ratio on log income',
	notes = glue(
		'Log income calculated as log of 10 year average of annual GDP. \n',
		'Actual and potential yields summed before calculating ratio.'),
	xlab = 'log GDP per capita'
	)




