'''
functions to calculate chi
THIS VERSION IS DEPRECATED. SEE ../calculate_moment.py for the new version.
The difference between the old and the new version is simply that the new
version takes simplified arguments, which should make it easier to use.
'''
__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

import numpy as np
import pandas as pd


def maximize_output(args, total_area, total_planted_area):
    '''
    Calculate the maximum possible output given total planted area and yields
    in each region.
    Parameters
    ----------
    args: list
        A list of lists. Each sub-list should be another list, corresponding to
        the data representing one of the two periods we want to compare. The
        elements of the sub-sub-lists should be arrays, where each set of
        arrays corresponds to a particular crop. Each set of arrays should be
        of the same length, and should be ordered such that corresponding
        indices of different arrays refer to the same region.
        The elements of the list should be as follows: total arable acres in
        each region, total planted acres, crop yields per hectare,
        crop-specific acreage, and calories yielded per hectare.
    total_area: array
        Array of the total number of arable hectares in each region. Should be
        sorted so indices correspond to the indices in args.
    total_planted_area: array
        Array of the total number of hectares planted in each region. Should be
        sorted so indices correspond to the indices in args.

    '''
    max_yields = np.amax([args[i][4] for i in range(len(args))], axis=0)

    df = (pd.DataFrame({'max_yield': max_yields, 'area': total_area})
            .sort_values(by='max_yield', ascending=False))
    df['cumulative_area'] = df.area.cumsum()

    total_planted_area = sum(total_planted_area)

    # identify the top-yielding regions
    max_yield_regions = df.loc[df.cumulative_area <= total_planted_area]
    # add the first region that is outside of the top, planting only as many
    # hectares as are left over. Only do this if there are regions outside the
    # top in the first place.
    if len(df.loc[df.cumulative_area > total_planted_area]) > 0:
        residual_region = (df.loc[df.cumulative_area > total_planted_area]
                           .iloc[[0]])
        residual_space = total_planted_area - sum(max_yield_regions.area)
        residual_region.area = residual_space

        max_yield_regions = pd.concat([max_yield_regions, residual_region],
                                      axis=0)

    max_yield = sum(max_yield_regions.area * max_yield_regions.max_yield)
    return max_yield


def calculate_chi(args, total_area, total_planted_area):
    '''
    Calculate chi, the ratio of calories grown to the maximum possible
    number of calories grown if crops were chosen and allocated perfectly,
    conditional on the total number of acres planted.
    Parameters
    ----------
    args: list
        A list of lists. Each sub-list should be another list, corresponding to
        the data representing one of the two periods we want to compare. The
        elements of the sub-sub-lists should be arrays, where each set of
        arrays corresponds to a particular crop. Each set of arrays should be
        of the same length, and should be ordered such that corresponding
        indices of different arrays refer to the same region.
        The elements of the list should be as follows: total arable acres in
        each region, total planted acres, crop yields per hectare,
        crop-specific acreage, and calories yielded per hectare.
    total_area: array
        Array of the total number of arable hectares in each region. Should be
        sorted so indices correspond to the indices in args.
    total_planted_area: array
        Array of the total number of hectares planted in each region. Should be
        sorted so indices correspond to the indices in args.
    '''
    # sum up total calories by region
    calories_grown = sum([args[i][3] * args[i][4] for i in range(len(args))])
    # sum over all the regions--this is the numerator of chi
    calories_grown = calories_grown.sum()

    max_yield = maximize_output(args, total_area, total_planted_area)

    return calories_grown / max_yield
