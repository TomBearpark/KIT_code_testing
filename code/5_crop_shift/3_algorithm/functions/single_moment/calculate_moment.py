'''
Functions to calculate chi.
This version (1.1) is set up to accept arguments as DataFrames
for simpler and less error-prone computation. For a version accepting arguments
as numpy arrays (for speed and compatibility with the multi-moment matching
scripts), see version 1.0 in z_old.
'''

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.1'

import numpy as np
import pandas as pd


def maximize_output(crop_data, total_arable_area, total_planted_area):
    '''
    Calculate the maximum possible output given total planted area and yields
    in each region.
    Parameters
    ----------
    crop_data: DataFrame
        This DataFrame should contain a region ID column, a crop column, a
        column giving the number of hectares of that crop planted in that
        region, and a column giving the (potential) calories per hectare
        yielded by that crop in that region.
    total_arable_area: DataFrame
        This DataFrame should contain a region ID column and a column
        containing the total arable area (in hectares) in each region.
    total_planted_area: DataFrame
        This DataFrame should contain a region ID column and a column
        containing the total planted area (in hectares) in each region.

    '''
    # get the crop data into a wide format so we can identify the max-yielding
    # crop in each region
    caloric_yields = (crop_data[['hierid', 'crop', 'potential_cal_per_ha']]
                      .pivot(index='hierid', columns='crop',
                             values='potential_cal_per_ha'))

    # identify the maximum-yielding crop in each region
    max_yields = pd.DataFrame(
        {'potential_cal_per_ha': caloric_yields.max(axis=1)}
    )

    # merge with total area data
    df = (max_yields.merge(total_arable_area, on='hierid')
          .sort_values(by='potential_cal_per_ha', ascending=False))
    df['cumulative_arable_ha'] = df.arable_hectares.cumsum()

    total_planted_area = total_planted_area.harvested_hectares.sum()

    # identify the top-yielding regions
    max_yield_regions = df.loc[df.cumulative_arable_ha <= total_planted_area]
    # add the first region that is outside of the top, planting only as many
    # hectares as are left over. Only do this if there are regions outside the
    # top in the first place.
    if len(df.loc[df.cumulative_arable_ha > total_planted_area]) > 0:
        residual_region = (df.loc[df.cumulative_arable_ha
                                  > total_planted_area]
                           .iloc[[0]])
        residual_space = (total_planted_area
                          - sum(max_yield_regions.arable_hectares))
        residual_region.arable_hectares = residual_space

        max_yield_regions = pd.concat([max_yield_regions, residual_region],
                                      axis=0)

    max_yield = sum(max_yield_regions.arable_hectares
                    * max_yield_regions.potential_cal_per_ha)
    return max_yield


def calculate_chi(crop_data, total_arable_area, total_planted_area):
    '''
    Calculate chi, the ratio of calories grown to the maximum possible
    number of calories grown if crops were chosen and allocated perfectly,
    conditional on the total number of acres planted.
    Parameters
    ----------
    crop_data: DataFrame
        This DataFrame should contain a region ID column, a crop column, a
        column giving the number of hectares of that crop planted in that
        region, and a column giving the (potential) calories per hectare
        yielded by that crop in that region.
    total_arable_area: DataFrame
        This DataFrame should contain a region ID column and a column
        containing the total arable area (in hectares) in each region.
    total_planted_area: DataFrame
        This DataFrame should contain a region ID column and a column
        containing the total planted area (in hectares) in each region.
    '''
    # sum up total calories by region
    calories_grown = sum(crop_data.harvested_hectares
                         * crop_data.potential_cal_per_ha)

    max_yield = maximize_output(crop_data, total_arable_area,
                                total_planted_area)
    if max_yield == 0:
        return np.nan

    return calories_grown / max_yield
