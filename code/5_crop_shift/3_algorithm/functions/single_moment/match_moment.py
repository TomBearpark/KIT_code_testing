'''
Function to calculate and match a single moment of the distribution of
crops, chi. This version (1.1) is set up to accept arguments as DataFrames
for simpler and less error-prone computation. For a version accepting arguments
as numpy arrays (for speed and compatibility with the multi-moment matching
scripts), see version 1.0 in z_old.
NOTE: as of 6/16/2020, this script has been updated but not tested.
'''

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.1'

from cilpath import Cilpath
paths = Cilpath()
import sys
sys.path.append('{}/agriculture/1_code/5_crop_shift/3_algorithm/scripts'
                .format(paths.REPO))
from single_moment.calculate_moment import calculate_chi, maximize_output


def match_moment(present_crop_data, future_crop_data, total_arable_area,
                 total_planted_area, return_future_chi=False):
    '''
    Calculate Q1, the number of calories produced in a future period, when
    holding chi constant across periods.
    Parameters
    ----------
    present_crop_data: DataFrame
        Information about the distribution and yield of crops in the initial
        period. This DataFrame should contain a region ID column, a crop
        column, a column giving the number of hectares of that crop planted
        in that region, and a column giving the (potential) calories per
        hectare yielded by that crop in that region.
    future_crop_data: DataFrame
        Information about the distribution and yield of crops in the future
        period. This DataFrame should contain a region ID column, a crop
        column, a column giving the number of hectares of that crop planted
        in that region, and a column giving the (potential) calories per
        hectare yielded by that crop in that region.
    total_arable_area: DataFrame
        This DataFrame should contain a region ID column and a column
        containing the total arable area (in hectares) in each region.
    total_planted_area: DataFrame
        This DataFrame should contain a region ID column and a column
        containing the total planted area (in hectares) in each region.
    return_future_chi: boolean. Do you want to return the value of chi
        calculated from the ratio of calories produced to maximum possible
        calories produced given future_crop_data?
    '''
    # calculate chi in the present period
    chi = calculate_chi(present_crop_data, total_arable_area,
                        total_planted_area)
    # calculate the maximum poss number of calories produced in the future
    # period
    max_q1 = maximize_output(future_crop_data, total_arable_area,
                             total_planted_area)

    if return_future_chi:
        # calculate the actual number of calories produced in the future
        # period
        q1 = sum(future_crop_data.harvested_hectares
                 * future_crop_data.potential_cal_per_ha)
        return [chi * max_q1, q1 / max_q1]

    return chi * max_q1
