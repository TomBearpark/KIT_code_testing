# Compute reallocation under single-moment and multi-moment models using
# data from Ishan's toy model, making it easy to check that everything is
# working as intended.
import numpy as np
import pandas as pd
import os
from cilpath import Cilpath
paths = Cilpath()

# import algo functions
os.chdir('{}/agriculture/1_code/5_crop_shift/3_algorithm/scripts'
         .format(paths.REPO))
# import multi_moment.match_moments as m
from multi_moment.match_moments import match_moments
from single_moment.match_moment import match_moment
from calculate_welfare_changes import calculate_welfare_changes

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

######################
# 1. Set up the data #
######################

crops = np.array(['soy', 'rice'])
geo0 = np.array([1])
geo1 = np.array([1, 2, 3])
total_acres = np.array([100, 100, 100])
soy_calories_per_bushel = 25
rice_calories_per_bushel = 15
# present data
present_soy_yields = np.array([10, 20, 15])
present_rice_yields = np.array([20, 10, 15])

# what happens if you scale by a linear factor?
present_soy_yields = present_soy_yields
present_rice_yields = present_rice_yields

present_soy_acreage = np.array([40, 70, 0])
present_rice_acreage = np.array([60, 30, 0])

present_soy_calories = present_soy_yields * soy_calories_per_bushel
present_rice_calories = present_rice_yields * rice_calories_per_bushel

present_total_planted_acreage = present_soy_acreage + present_rice_acreage

# future data
future_soy_yield_shocks = np.array([0.5, 0.8, 1])
future_rice_yield_shocks = np.array([0.9, 0.6, 1])

future_soy_yields = present_soy_yields * future_soy_yield_shocks
future_rice_yields = present_rice_yields * future_rice_yield_shocks

future_soy_acreage = present_soy_acreage
future_rice_acreage = present_rice_acreage

future_soy_calories = future_soy_yields * soy_calories_per_bushel
future_rice_calories = future_rice_yields * rice_calories_per_bushel

present_both_args = [total_acres, present_total_planted_acreage]
present_soy_args = (present_both_args +
                    [present_soy_yields, present_soy_acreage,
                     present_soy_calories])
present_rice_args = (present_both_args +

                     [present_rice_yields, present_rice_acreage,
                      present_rice_calories])
present_args = [present_soy_args, present_rice_args]

future_both_args = [total_acres, present_total_planted_acreage]
future_soy_args = (future_both_args +
                   [future_soy_yields, future_soy_acreage,
                    future_soy_calories])
future_rice_args = (future_both_args +
                    [future_rice_yields, future_rice_acreage,
                     future_rice_calories])
future_args = [future_soy_args, future_rice_args]

###############################################
# Run algorithm and calculate welfare changes #
###############################################

Q0 = sum([present_args[i][3] * present_args[i][4]
         for i in range(len(present_args))]).sum()

Q1_no_reallocation = sum([future_args[i][3] * future_args[i][4]
                          for i in range(len(future_args))]).sum()
Q1_chi = match_moment(present_args, future_args, total_acres,
                      present_total_planted_acreage)
Q1_mm_1 = match_moments(present_args, future_args, step_size=1)

wfare_no_reallocation = calculate_welfare_changes(Q0=Q0, Q1=Q1_no_reallocation)
wfare_chi = calculate_welfare_changes(Q0=Q0, Q1=Q1_chi)
wfare_mm_1 = calculate_welfare_changes(Q0=Q0, Q1=Q1_mm_1)
wfare_list = [wfare_no_reallocation, wfare_chi, wfare_mm_1]

results = pd.DataFrame({
    'model': ['no-reallocation', 'single-moment', 'multi-moment'],
    'step_size': [np.nan, np.nan, 1],
    'Q1': [Q1_no_reallocation, Q1_chi, Q1_mm_1],
    'delta_total_welfare': [w[0] for w in wfare_list],
    'delta_CS': [w[1] for w in wfare_list],
    'delta_PS': [w[2] for w in wfare_list]
})
