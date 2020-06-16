'''
Calculate chi for all countries globally
goal is to understand whether there are patterns in chi that might be able to
model, allowing us to allow chi to evolve in the future.

What's needed to do this (both to be done at IR level):
- total area of arable land
- total hectares planted
- potential calories for each crop
'''

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

import os
import pandas as pd
from cilpath import Cilpath
paths = Cilpath()
import sys
sys.path.append('{}/agriculture/1_code/5_crop_shift/3_algorithm/functions'
                .format(paths.REPO))
from single_moment.match_moment import calculate_chi

# set global parameters here
wt = 'allcropwt'

###################
# 1. PREPARE DATA #
###################

# a. get (potential) yield data in terms of calories
gaez = pd.read_csv(('/shares/gcp/estimation/agriculture/Data/2_intermediate/'
                    'potential_yield/hierid/{}/gaez_potential_yield_global.csv'
                    ).format(wt))
gaez.rename(columns={'adm2_id': 'hierid', 'adm1_id': 'iso'}, inplace=True)

# b. get cropped area data
sage_path = ('/shares/gcp/estimation/agriculture/Data/'
             '2_intermediate/cropped_area/hierid')

total_arable_area = pd.read_csv('{}/sage_arable_area_global.csv'
                                .format(sage_path))
total_arable_area['iso'] = total_arable_area.hierid.str[:3]

planted_area = pd.read_csv('{}/sage_planted_area_global.csv'
                           .format(sage_path))
planted_area['iso'] = planted_area.hierid.str[:3]
planted_area.rename(columns={'crops': 'crop'}, inplace=True)
# replace 'soybean' with 'soy' for merging with gaez data below
planted_area.replace('soybean', 'soy', inplace=True)

total_planted_area = planted_area.loc[planted_area.crop == 'maize|soybean|'
                                      'cassava|rice|wheat|sorghum']

# c. create DataFrame of calories per tonne for diff crops
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

# merge together to get the 'crop_data' DataFrame needed for calculate_chi
crop_data = (gaez.merge(planted_area, on=['iso', 'hierid', 'crop'])
                 .merge(cals, on=['crop']))
crop_data['potential_cal_per_ha'] = (crop_data.calories_per_tonne
                                     * crop_data.potential_yield)
crop_data = crop_data[['hierid', 'iso', 'crop', 'harvested_hectares',
                       'potential_cal_per_ha']]

#############################
# 2. CALCULATE CHI GLOBALLY #
#############################

isos = crop_data.iso.unique()
chi = [calculate_chi(crop_data.loc[crop_data.iso == i],
                     total_arable_area.loc[total_arable_area.iso == i],
                     total_planted_area.loc[total_planted_area.iso == i])
       for i in isos]
# add in iso names
chi = pd.concat([pd.Series(s) for s in [isos, chi]], axis=1)
chi.columns = ['iso', 'chi']

# save out result
# commented out for Kit's version so she doesn't save over the previously]
# generated output!
# write_dir = ('{}/GCP_Reanalysis/AGRICULTURE/4_outputs/'.format(paths.DB)
#              + '3_projections/5_crop_shift/chi/data')
# os.mkdir(write_dir)
# chi.to_csv('{}/chi_global.csv'.format(write_dir), index=False)
