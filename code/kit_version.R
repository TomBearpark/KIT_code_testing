library(haven)
library(tidyverse)
library(plm)

# SET UP
setwd("C:/Users/kitsc/KIT_code_testing/data")

# DEFINITIONS

## seed
	seed=51
	set.seed(seed)
## number of repetitions
	reps=5000 
## sd of error term
	sd = 3000
## coefficients on temperature term (hypothetical linear response)
	beta = 0.25
## coefficients on long-run temperature interaction term
	gamma = 0.02
## constant term
	alpha = 12000
## difference in pixel temperature and polynomial means
	pixel_meantemp_diff = 20

# REAL COUNTRY-LEVEL TEMP DATA

## importing
	real_temps <- read_dta("Europe_temps.dta")
## create country ID
	real_temps$group <- real_temps %>% group_indices(country) 
## create count of countries
	country_count = length(unique(real_temps$group))
## create mean-temp-by-country variable

	# aggregate(x = real_temps$temp1,             
 #          by = list(real_temps$group),  
 #          FUN = mean)
data = real_temp %>% 
  dplyr::filter(country== "ALB")