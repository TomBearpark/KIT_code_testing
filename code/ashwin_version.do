**Generate fake pixel level temperatures and fake outcome data
**Created by: Ashwin Rode, Jun 10, 2020

clear
set more off
set maxvar 30000
*cd "W:\Dropbox\GCP_Reanalysis\ENERGY\IEA\Testing\Simulation"
cd "/Users/ashwinrode/Dropbox/GCP_Reanalysis/ENERGY/IEA/Tests_and_Analysis/Unit_Root_Test/Simulation"

*****Definitions
*seed
global seed=51
set seed ${seed}
*number of repetitions
local reps=5000 
*sd of error term
local sd = 3000
*coefficients on temperature term (hypothetical linear response)
local beta = 0.25

*coefficients on long-run temperature interaction term
local gamma = 0.02

*constant term
local alpha = 12000

*difference in pixel temperature and polynomial means
local pixel_meantemp_diff = 20


*****Real country-level temperature data
use Europe_temps.dta, clear
sort country year

*****Generate country numeric identifiers
egen group = group(country)
sum group
local countries = r(max)

xtset group year

*****Generate country average temperature
bysort country : egen double avgtemp1=mean(temp1)

*****Generate year-to-year deviations from country average temperature
gen double deviation = temp1 - avgtemp1

*****Generate positively and negatively correlated pixel temperature
*****2 pairs fake pixels generated per country. In each pair, one pixel (labelled 1) is hotter than country average and other (labelled 2) is colder.
*****One pair of fake pixels have positively correlated shocks, the second pair has negatively correlated shocks
*positively correlated pixel pair
gen temp1_pospixel1 = avgtemp1 + ((`pixel_meantemp_diff')/2)*365.25 + deviation
gen temp1_pospixel2 = avgtemp1 - ((`pixel_meantemp_diff')/2)*365.25 + deviation
*negatively correlated pixel pair
gen temp1_negpixel1 = avgtemp1 + ((`pixel_meantemp_diff')/2)*365.25 + 4*deviation
gen temp1_negpixel2 = avgtemp1 - ((`pixel_meantemp_diff')/2)*365.25 - 2*deviation

*****Generate long-run average temperature (as opposed to sum) for country
gen lrtemp_country = avgtemp1/365.25

*****Generate long-run average temperature (as opposed to sum) for each pixel pair 
*****(confirm these should be separated in either direction from country average)
*positively correlated pixel pair
bysort country : egen double lrtemp_pospixel1=mean(temp1_pospixel1)
replace lrtemp_pospixel1=lrtemp_pospixel1/365.25
bysort country : egen double lrtemp_pospixel2=mean(temp1_pospixel2)
replace lrtemp_pospixel2=lrtemp_pospixel2/365.25
*negatively correlated pixel pair
bysort country : egen double lrtemp_negpixel1=mean(temp1_negpixel1)
replace lrtemp_negpixel1=lrtemp_negpixel1/365.25
bysort country : egen double lrtemp_negpixel2=mean(temp1_negpixel2)
replace lrtemp_negpixel2=lrtemp_negpixel2/365.25

******Confirm that averaging temperatures across both pairs of pixels returns the country temperature
******This is a sanity check. Both these variables should equal 0.
gen checkpos = (temp1_pospixel1 + temp1_pospixel2)*0.5 - temp1
gen checkneg = (temp1_negpixel1 + temp1_negpixel2)*0.5 - temp1

******Generate temperature * long-run average temperature, country-level values multiplied
gen interaction_country = temp1 * lrtemp_country

******Generate temperature * long-run average temperature, pixel-level values multiplied and then aggregated to country
******This is done separate for each pair of pixels
gen interaction_pospixel = (temp1_pospixel1*lrtemp_pospixel1 + temp1_pospixel2*lrtemp_pospixel2)*0.5
gen interaction_negpixel = (temp1_negpixel1*lrtemp_negpixel1 + temp1_negpixel2*lrtemp_negpixel2)*0.5

*****Generate fake outcome data in the case of positively correlated pixel temperatures
forvalues draw = 1(1)`reps'{
	gen outcome_pos_`draw' = `beta'*temp1 + `gamma'*interaction_pospixel + `alpha' + `sd'*rnormal()
}

*****Generate fake outcome data in the case of positively correlated pixel temperatures
forvalues draw = 1(1)`reps'{
	gen outcome_neg_`draw' = `beta'*temp1 + `gamma'*interaction_negpixel + `alpha' + `sd'*rnormal()
}	

save simulated_data_interaction, replace
