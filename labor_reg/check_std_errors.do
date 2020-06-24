// insert this code right after this line:
// use `reg_data', clear

* creating a matrix of standard errors
mat A = e(V)
local coefs =colsof(A)
matrix std_errors = vecdiag(e(V))
forvalues i = 1/`coefs' {
    matrix std_errors[1, `i'] = sqrt(std_errors[1, `i'])
}
* summing all standard errors
mata : st_matrix("sum", rowsum(st_matrix("std_errors")))

* checking if all standard errors are zero; if so, we run a normal reg.
if sum[1,1] == 0 {
	di "Your standard errors are all zero. Now running a normal reg."
	gen included = e(sample)
	local fixed_effects = e(extended_absvars)
	run_specification "reg" "`spec_desc'" polynomials_`t_version'_`chn_week'_`data_subset'_`t_version' do_not_include_0_min "`reg_treatment'" "`reg_control'" `treat_risk' diff_cont "`fixed_effects'" `weights' `clustering' "`ster_name'" 

	}
else {
	di "Good job! You have some standard errors from reghdfe."
	}
	