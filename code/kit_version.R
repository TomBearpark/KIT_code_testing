## SET UP

setwd("C:/Users/kitsc/KIT_code_testing/data")
library(haven)
library(tidyverse)
library(plm)
library(dplyr)
library(magrittr)
library(glue)

## DEFINITIONS

# seed
seed=51
set.seed(seed)
# number of repetitions
reps=5000 
# sd of error term
sd = 3000
# coefficients on temperature term (hypothetical linear response)
beta = 0.25
# coefficients on long-run temperature interaction term
gamma = 0.02
# constant term
alpha = 12000
# difference in pixel temperature and polynomial means
pixel_meantemp_diff = 20

## REAL COUNTRY-LEVEL TEMP DATA

# importing
real_temps <- read_dta("Europe_temps.dta")
d <- real_temps
# create country ID
d %<>% mutate(., group = group_indices(., country))
# create count of countries
country_count = length(unique(d$group))
# create mean-temp-by-country variable & deviations variable
d %<>%
	group_by(country) %>%
	mutate(avgtemp1 = mean(temp1),
		deviation = temp1 - avgtemp1) %>%
	ungroup()

## FAKE DATA

# Generate positively and negatively correlated pixel temperature
d %<>%
  mutate(temp1_pospixel1 = avgtemp1 + ((pixel_meantemp_diff)/2)*365.25 + deviation,
  		temp1_pospixel2 = avgtemp1 - ((pixel_meantemp_diff)/2)*365.25 + deviation,
		temp1_negpixel1 = avgtemp1 + ((pixel_meantemp_diff)/2)*365.25 + 4*deviation,
		temp1_negpixel2 = avgtemp1 - ((pixel_meantemp_diff)/2)*365.25 - 2*deviation)

# Generate long-run average temperature
d %<>% mutate(lrtemp_country = avgtemp1/365.25)

# Generate long-run average temperature by pixel pair
d %<>%
  group_by(country) %>%
  mutate(lrtemp_pospixel1=mean(temp1_pospixel1)/365.25,
  		lrtemp_pospixel2=mean(temp1_pospixel2)/365.25,
  		lrtemp_negpixel1=mean(temp1_negpixel1)/365.25,
  		lrtemp_negpixel2=mean(temp1_negpixel2)/365.25) %>%
  ungroup()

# A sanity check - do these vars = 0?
# THIS IS STRANGE: IN STATA THESE ARE NOT 0, IN R THEY ARE (significant digits?)
d_check = d %>%
mutate(checkpos = (temp1_pospixel1 + temp1_pospixel2)*0.5 - temp1,
		checkneg = (temp1_negpixel1 + temp1_negpixel2)*0.5 - temp1)

# Generate temperature * long-run average temperature, country-level values multiplied
d %<>% mutate(interaction_country = temp1 * lrtemp_country)
	  	
# Generate temperature * long-run average temperature, 
# pixel-level values multiplied and then aggregated to country
d %<>% mutate(interaction_pospixel = (temp1_pospixel1*lrtemp_pospixel1 + temp1_pospixel2*lrtemp_pospixel2)*0.5,
		  		interaction_negpixel = (temp1_negpixel1*lrtemp_negpixel1 + temp1_negpixel2*lrtemp_negpixel2)*0.5)

## GENERATING FAKE OUTCOMES

# Function to generate fake outcome data in the case of positively & negatively correlated pixel temperatures
gen_outcomes <- function(d,draws,beta,a,gamma,b_pos,b_neg,alpha,sd) {
  for(i in 1:draws) {
    print(i)
    ypos = as.character(glue("outcome_pos_{i}"))
    yneg = as.character(glue("outcome_neg_{i}"))
    ## There may be an error here, with rnorm()
    d[ypos] = beta*d[a] + gamma*d[b_pos] + alpha + sd*rnorm(1)
    d[yneg] = beta*d[a] + gamma*d[b_neg] + alpha + sd*rnorm(1)
  }
   return(d)
}

# Run function on our data
new_d = gen_outcomes(d=d,draws=reps,
		beta=beta,a='temp1',
		gamma=gamma,b_pos='interaction_pospixel', b_neg='interaction_negpixel',
		alpha=alpha,sd=sd)


# SAVE

write.csv(new_d,"C:/Users/kitsc/Dropbox/KIT_code_testing/data/kit_output.csv", row.names = TRUE)