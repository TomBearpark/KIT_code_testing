library(haven)

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

# IMPORTING DATA

## Real country-level temperature data
	data <- read_dta("Europe_temps.dta")

