# 3_algorithm

The code in this directory implements various moment calculations and also implements code to match moments across periods.

## `functions/`
The code in this directory implements function to calculate various moments. The main ones that are useful for future work are in `functions/single_moment/`. These implement moment calculation and matching for chi.
- `single_moment/`: Code for calculating and matching chi.
	- `calculate_moment.py`: calculate chi.
	- `match_moment.py`: match chi across periods.
	- `z_old/`: this directory contains deprecated versions of the above two scripts, which are used in `acp_test/acp_test.py` and `calculate_global_chi/calculate_global_chi.py`. The new versions take simplified arguments, making them easier to use.  
	**Note for future work:** It would be a good idea to update `acp_test.py` and `calculate_global_chi.py` so they use the new versions of the functions.  
	Note also that while new implementation of chi calculation is more user-friendly, it is slower because it uses Pandas DataFrames instead of NumPy arrays. This shouldn't pose much of a problem given that the calculations required to obtain chi are fairly simple. However, the code in `z_old/` can be used as a framework for returning the the NumPy implementation if necessary.
- `multi_moment/`. These implement moment calculation and matching for phi and gamma, the two-moment approach we have since dropped.
	- `calculate_moments.py`: calculate phi and gamma.
	- `match_moments.py`: match phi and gamma across periods.
- `calculate_welfare_changes.py`: Calculate changes in producer and consumer surplus caused by a change in quantity produced. Areas correspond to the areas in [this graph](readme_images/valuation.png) (taken from the [5/15/2020 Friday meeting slides](https://www.dropbox.com/s/qrei7oya46a6ffw/20200515_CIL_all_and_SL.pdf?dl=0)).
- `state_abbrev_dict.py`: This is just a convenient dictionary mapping US state abbreviations to their full names. Used to clean the ACP data in `acp_test/acp_test.py`.

## `acp_test/`
The code in this directory applies the above functions to the results of the American Climate Prospectus (ACP).
- `acp_test.py`: This is where all the action happens. Loads the cleaned data, combines it, calculates moments, matches them, does the welfare calculations.
- `reallocate.py` and `calculate_welfare.py`: both unfinished. Goal of these scripts was to break down the contents of `acp_test.py` into two separable steps: first, the reallocation (i.e. moment matching) and second, the welfare calculation. The reason for doing this is that the moment matching for the two-moment system can take quite a while (depending on step size). Separating the scripts would avoid re-running the reallocation step every time we make a change to the welfare calculation. However, this is less of a concern if we are only working with the single moment model, which is very fast to compute.

## `global_chi/`
This directory contains code related to calculating chi globally.
- `calculate_global_chi.py`: Calculate chi at the country level globally. 
- `map_global_chi.R`: visualize global values of chi produced in `calculate_global_chi.py`
- `regress_global_chi.R`: unfinished. Run regressions of chi on functional forms of GDP and long run temperature to build model of chi which could be used to allow chi to evolve in the future.
- **For future work:** 
	- Calculate chi at other spatial levels, eg FUND region, adm1, adm2, etc.
	- Finish `regress_global_chi.R`; build projection using results.

## `toy_model/`
This code is deprecated. Was used to build intuition for the multi-moment reallocation model using fake data. Experimented with various implementations to find the fastest one.