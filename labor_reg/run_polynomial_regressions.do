*cilpath 
******** to Kit: change this to point to your repo
global code_dir "${REPO}/gcp-labor/"

******** to Kit: change this to the path of this file on your machine
do "${code_dir}/2_regression/time_use/common_functions.do"

init
gen_controls_and_FEs



global t_version_list tmax
global chn_week_list chn_prev7days
*chn_prev_week 
  

global data_subset_list no_chn all_data
*global data_subset_list CHN_mon CHN_tue CHN_wed CHN_thu CHN_fri CHN_sat CHN_sun FRA GBR ESP IND CHN USA BRA MEX EU no_chn all_data

* if set to yes, will skip existing ster files
global skip_existing_ster "no"

* if set to yes, will randomly sample 1% of data
global test_code "no"

* if set to yes, will run the same specification with lead and lag weeks
global run_lcl "no"

* set to yes to run interacted models
global is_interacted "no"
* the list of weights we want to try
global weight_list risk_adj_sample_wgt

* set to yes to run different treatment specifications
global differentiated_treatment "yes"
* put all the FEs that need to be run in this list
* FEs are defined in function gen_controls_and_FEs
global fe_list fe_week_adm0
*global fe_list fe_week_adm0 fe_adm0 fe_adm1 fe_adm3 fe_week_adm1 fe_week_saturated

* a global to choose dataset
global ll_version lcl_1
* select a global for controls defined in gen_controls_and_FEs
global controls_varname usual_controls

* set reference temperature for generating response function
global ref_temp 27




cap program drop run_polynomial_regressions
program define run_polynomial_regressions

	args data_path differentiated_treatment is_interacted t_version chn_week data_subset leads_lags N_order controls_var fe clustering weights suffix

	* detect type of the regressions and generate the folders to save the results	
	if "`is_interacted'" == "yes" local reg_folder interacted_polynomials
	else local reg_folder uninteracted_polynomials
	if "`differentiated_treatment'" == "yes" local reg_folder `reg_folder'_by_risk


	* generate ster file name
	local ster_name "$output_dir/estimates/`reg_folder'/polynomials_`t_version'_`chn_week'/`fe'_poly_`N_order'_`leads_lags'_`data_subset'_`weights'`suffix'"
	
	* check if file exists or if the regression has been run
	capture confirm file "`ster_name'_reghdfe.ster"

	* if regression hasn't been run or if we want to overwrite existing results, run it
	if _rc != 0 | "${skip_existing_ster}" == "no" {
		preserve

		* keep only the part of data that we need
		select_data_subset `data_subset'

		* if test code mode is on, take a random sample
		if "${test_code}"=="yes" {
			sample 1
		}
		
		* generate globals for the treatment, 1: number of lead and lag weeks 
		* (we need to make it an argument if we want more than 1 week on each side)
		gen_treatment_polynomials `N_order' `t_version' `leads_lags' 1

		* a string for displaying the specificatino later
		
		* if we want to run the interacted spline, the treatment will include the interacted terms
		if "`is_interacted'" == "yes" {
			local reg_treatment ${vars_T_polynomials} ${vars_T_x_gdp_polynomials} ${vars_T_x_lr_`t_version'_polynomials}
		}
		else {
			* otherwise the treatment is only the uninteracted part
			local reg_treatment ${vars_T_polynomials}
		}
		
		* get the appropriate controls (right now we only have one, ${usual_controls})
		local reg_control ${`controls_var'}

		* we organize the results in the format of: regression_type/data_file/ster_file.ster
		cd "$output_dir/estimates/`reg_folder'"
		cap mkdir polynomials_`t_version'_`chn_week'
		
		* generate arguments for the run_specification command
		if "${differentiated_treatment}" == "yes" local treat_risk diff_treat
		else local treat_risk comm_treat

		* gather the information to be stored in ster file as a note
		local spec_desc "polynomials, order `N_order', `t_version', interacted = `is_interacted', `treat_risk'"
		local spec_desc "`spec_desc'. data: `data_path'"

		* run reghdfe by default
		run_specification "reghdfe" "`spec_desc'" polynomials_`t_version'_`chn_week'_`data_subset' do_not_include_0_min "`reg_treatment'" "`reg_control'" `treat_risk' diff_cont `fe' `weights' `clustering' "`ster_name'" 

		* save the data for regression because new data needs to be generated for the response function
		tempfile reg_data
		save `reg_data', replace
		*get_RF_uninteracted_polynomials `leads_lags' `differentiated_treatment' `ster_name'_reghdfe `t_version' `chn_week' `fe' `N_order' `weights' `data_subset' `reg_folder' ${ref_temp}

		use `reg_data', clear

		* also run reg version for interacted regressions
		* reg version is run when reghdfe doesn't produce standard errors (which happens in higher order interacted regressions)
		* reg has to be run after reghdfe because we need to drop the same singleton observations dropped by reghdfe
		* because reg doesn't automatically drop singletons.
		* otherwise, the point estimates will be different between reg and reghdfe
		* right now we only need to run interacted regressions with week_adm0 fixed effects
		* also we don't save response function for the interacted regressions here

		* creating a matrix of standard errors
		mat A = e(V)
		local coefs =colsof(A)
		matrix std_errors = vecdiag(e(V))
		forvalues i = 1/`coefs' {
			matrix std_errors[1, `i'] = sqrt(std_errors[1, `i'])
		}
		* summing all standard errors
		mata : st_matrix("sum", rowsum(st_matrix("std_errors")))

		* checking if sum of all standard errors are zero; if so, we run a normal reg.
		if sum[1,1] == 0 {
			di "Your standard errors are all zero. Now running a normal reg."
			* e(sample) isn't working for some reason -- neither with my version or Rae's previous version
			*gen included = e(sample)
			local fixed_effects = e(extended_absvars)
			run_specification "reg" "`spec_desc'" polynomials_`t_version'_`chn_week'_`data_subset'_`t_version' do_not_include_0_min "`reg_treatment'" "`reg_control'" `treat_risk' diff_cont "`fixed_effects'" `weights' `clustering' "`ster_name'" 
			}
		else {
			di "Good job! You have some standard errors from reghdfe. No need to run reg."
			}
	
		restore
	}
	else {
		di "`ster_name'_reghdfe.ster already exists!"
	}
end 


* data can be different depending on whether it's tmax or tavg
foreach t_version in $t_version_list {
	* or if china polynomials are matched to previous week, previous 7 days, or next week
	foreach chn_week in $chn_week_list {	

		* load data
		local data_path "${data_dir}/labor_dataset_polynomials_`t_version'_`chn_week'_${ll_version}.dta"
		di "data loaded: `data_path'"
		use "`data_path'", clear

		* run polynomials of order p
		forval p = 2/4 {
			* run different versions of fixed effect
			foreach f in ${fe_list} {
				* using different weights
				foreach w in ${weight_list} {
					* subsetting data
					foreach data_subset in ${data_subset_list} {
						* run regression without lead and lag weeks
						run_polynomial_regressions `data_path' ${differentiated_treatment} ${is_interacted} `t_version' `chn_week' `data_subset' this_week `p' ${controls_varname} `f' ${clustering_var} `w' ${ster_suffix}
						* run regression with lead and lag weeks
						if "${run_lcl}" == "yes" {
							run_polynomial_regressions `data_path' ${differentiated_treatment} ${is_interacted} `t_version' `chn_week' `data_subset' all_weeks `p' ${controls_varname} `f' ${clustering_var} `w' ${ster_suffix}
						}
					}
				}
			}
		}
	}
}
