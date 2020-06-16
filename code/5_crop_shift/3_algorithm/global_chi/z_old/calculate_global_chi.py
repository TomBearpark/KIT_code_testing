'''
calculate chi for all countries globally
goal is to understand whether there are patterns in chi that might be able to
model, allowing us to allow chi to evolve in the future.

What's needed to do this (both to be done at IR level):
- total area of arable land
- total hectares planted
- potential calories for each crop

NOTE: This version is now deprecated because it uses the version of
calculate_chi that relies on the old argument structure. See new version in
parent folder.
'''

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

import numpy as np
import pandas as pd
from cilpath import Cilpath
paths = Cilpath()
import sys
sys.path.append('{}/agriculture/1_code/5_crop_shift/3_algorithm/functions'
                .format(paths.REPO))
from single_moment.z_old.match_moment import calculate_chi

# set global parameters here
wt = 'allcropwt'

###################
# 1. PREPARE DATA #
###################

# a. get yield data in terms of calories
gaez = pd.read_csv(('/shares/gcp/estimation/agriculture/Data/2_intermediate/'
                    'potential_yield/hierid/{}/gaez_potential_yield_global.csv'
                    ).format(wt))
gaez.rename(columns={'adm2_id': 'hierid', 'adm1_id': 'iso'}, inplace=True)

# b. get cropped area data
sage = pd.read_csv('/shares/gcp/estimation/agriculture/Data/2_intermediate/'
                   'cropped_area/hierid/sage_planted_area_global.csv')

# get total arable area
total_area = (sage.loc[sage.crop == 'cropland']
              .rename(columns={'harvested_hectares': 'total_area'})
              .drop(columns=['crop']))

# get total area planted by main crops
total_planted_area = (sage.loc[sage.crop != 'cropland']
                      .groupby(['hierid'])
                      .agg({'harvested_hectares': 'sum'})
                      .rename(columns={'harvested_hectares':
                                       'total_planted_area'})
                      .reset_index())

# c. create data frame of calories per tonne for diff crops
# I got this from here:
# https://iopscience.iop.org/1748-9326/8/3/034015/media/erl472821suppdata.pdf,
# supplementary material for Cassidy et al. 2013, "Redefining agricultural
# yields: from tonnes to people nourished per hectare."
# link: https://iopscience.iop.org/article/10.1088/1748-9326/8/3/034015
cals = pd.DataFrame(
    {
        'crop': ['soy', 'maize', 'cotton'],
        'calories_per_tonne': [3596499.11, 3580802.60, 4100000.00]
    }
)

# d. merge all of the above together
prepped = (gaez.merge(sage, on=['hierid', 'crop'])
           .merge(total_area, on=['hierid'])
           .merge(total_planted_area, on=['hierid'])
           .merge(cals, on=['crop'])
           .sort_values(by=['crop', 'hierid']))
prepped['potential_cal_per_ha'] = (prepped.calories_per_tonne
                                   * prepped.potential_yield)

#############################
# 2. CALCULATE CHI GLOBALLY #
#############################


def get_crop_args(iso, crop):
    '''
    Function to pull out columns from prepped as numpy arrays that are
    ready to be passed to the moments matching functions.
    '''
    total_area = prepped.loc[(prepped.crop == crop)
                             & (prepped.hierid.str.startswith(iso)),
                             'total_area']
    total_planted_area = prepped.loc[(prepped.crop == crop)
                                     & (prepped.hierid.str.startswith(iso)),
                                     'total_planted_area']
    harvested_hectares = prepped.loc[(prepped.crop == crop)
                                     & (prepped.hierid.str.startswith(iso)),
                                     'harvested_hectares']
    yields = prepped.loc[(prepped.crop == crop)
                         & (prepped.hierid.str.startswith(iso)),
                         'potential_yield']
    calories = prepped.loc[(prepped.crop == crop)
                           & (prepped.hierid.str.startswith(iso)),
                           'potential_cal_per_ha']

    retlist = [total_area, total_planted_area, yields, harvested_hectares,
               calories]

    return [np.array(s) for s in retlist]


# the way calculate_chi takes arguments is crappy and was designed only for the
# ACP data. Revise this sometime soon.
isos = prepped.iso.unique()
crops = ['soy', 'rice', 'maize', 'sorghum', 'cassava', 'wheat']
args = [[get_crop_args(i, c) for c in crops] for i in isos]
chi = [calculate_chi(args[i], args[i][0][0], args[i][0][1])
       for i in range(len(args))]
# add in iso names
chi = pd.concat([pd.Series(s) for s in [isos, chi]], axis=1)
chi.columns = ['iso', 'chi']

# save out result
chi.to_csv('{}/GCP_Reanalysis/AGRICULTURE/4_outputs/'.format(paths.DB)
           + '3_projections/5_crop_shift/chi/data/chi_global.csv',
           index=False)
