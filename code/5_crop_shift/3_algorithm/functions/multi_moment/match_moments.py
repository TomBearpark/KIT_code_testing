# Functions to calculate and match moments
import numpy as np
import copy
import warnings
import logging
import os
from cilpath import Cilpath
paths = Cilpath()
import sys
sys.path.append('{}/agriculture/1_code/5_crop_shift/3_algorithm/scripts'
                .format(paths.REPO))
from multi_moment.calculate_moments import (calculate_gamma, calculate_phi, analyze_empty_acreage)
from single_moment.calculate_moment import calculate_chi
# os.chdir('{}/agriculture/1_code/5_crop_shift/3_algorithm/scripts/multi_moment/'
#          .format(paths.REPO))
# from calculate_moments import calculate_gamma, calculate_phi, analyze_empty_acreage
# os.chdir('../single_moment/')
# from caclulate_moment import calculate_chi

FORMAT = '%(asctime)-15s %(message)s'
logging.basicConfig(format=FORMAT)

logger = logging.getLogger('uploader')
logger.setLevel('DEBUG')

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

# for iteratives, how many hectares do you want to move at a time?
step_size = 1000

def calculate_distances(present_args, future_args, step_size=step_size):
    '''
    Calculate moments for yield and area data in two periods, and return the
    differences between the moments.

    Parameters
    ----------
    present_args: list
        A list of lists. Each sub-list should be another list, corresponding to
        the data representing one of the two periods we want to compare. The
        elements of the sub-sub-lists should be arrays, where each set of
        arrays corresponds to a particular crop. Each set of arrays should be
        of the same length, and should be ordered such that corresponding
        indices of different arrays refer to the same region.
        The elements of the list should be as follows: total acres in each
        region, total planted acres, crop yields per hectare, crop-specific
        acreage, and calories yielded per hectare.
    futre_args: list
        Same as present_args.

    Returns
    -------
    A list of the differences between the moments.

    '''
    present_moments = (
        [calculate_phi(a[0], a[1], a[2], a[3], step_size=step_size)
         for a in present_args] +
        [calculate_gamma([present_args[i][3:]
                         for i in range(len(present_args))])]
    )

    future_moments = (
        [calculate_phi(a[0], a[1], a[2], a[3], step_size=step_size)
         for a in future_args] +
        [calculate_gamma([future_args[i][3:]
                         for i in range(len(future_args))])]
    )

    distances = [p - f for p, f in zip(present_moments, future_moments)]

    return distances


def match_moments(present_args, future_args, step_size=step_size,
                  return_chi=False, total_area=None, total_planted_area=None):
    '''
    Given data on two periods, modify the values in the second period until
    moments match across the two periods.

    Parameters
    ----------
    Same as calculate_distances
    Returns
    -------
    The modified data for the second period.
    '''
    distances = calculate_distances(present_args, future_args)

    future_args = copy.deepcopy(future_args)
    present_args = copy.deepcopy(present_args)

    counter = 0

    while any(d > 0 for d in distances):
        reallocation_info = [analyze_empty_acreage(a[0], a[1], a[2], a[3])
                             for a in future_args]
        # phi iteration happens first
        # note this relies on the fact that calculate_distances returns gamma
        # last.
        if any(d > 0 for d in distances[:-1]):
            for i in range(len(distances) - 1):
                if distances[i] > 0:
                    for a in [future_args[i][1], future_args[i][3]]:
                        a[reallocation_info[i][0]] += step_size  # empty_max_id
                        a[reallocation_info[i][1]] -= step_size   # used_min_id

        # now iterate over gamma
        if any(d > 0 for d in distances[-1:]):
            # switch an acre between the lowest-yielding and highest-yielding
            # crop in the location where that gap is largest
            # create list of crop level yields from args
            crop_yield_list = [future_args[i][2]
                               for i in range(len(future_args))]

            diffs = []
            for i in range(len(crop_yield_list)):
                j_list = list(crop_yield_list)  # modify a new copy
                del j_list[i]
                i_val = crop_yield_list[i]
                i_list = [i_val, i_val]
                if range(len(j_list) > 2):
                    for i in range(len(j_list)):
                        i_list = [i_val, i_list]
                diffs += [(i - j).tolist() for i, j in zip(i_list, j_list)]

            # flatten the list of diffs and take absolute values
            diffs = [i for diff in diffs for i in diff]
            # note this is picking the first one--not sure if this is desirable
            max_diff_id = diffs.index(max(diffs))
            min_diff_id = diffs.index(min(diffs))

            # check there are equal numbers of plots for each crop
            test_list = [len(crop_yield_list[i])
                         for i in range(len(crop_yield_list))]
            assert all(
                [test_list[i] == test_list[0] for i in range(len(test_list))]
            )
            n_plots = test_list[0]
            max_crop_id, min_crop_id = [
                i // (n_plots * (len(crop_yield_list) - 1))
                for i in [max_diff_id, min_diff_id]]

            max_plot_id, min_plot_id = [i % n_plots
                                        for i in [max_diff_id, min_diff_id]
                                        ]
            assert min_plot_id == max_plot_id

            future_args[min_crop_id][3][min_plot_id] -= step_size
            future_args[max_crop_id][3][max_plot_id] += step_size

        distances = calculate_distances(present_args, future_args)
        counter += 1
        if counter % 100 == 0:
            logger.debug('Distances are {} on interation {}.'
                         .format(distances, counter))

    # calculate Q1 and return it
    Q1 = sum([future_args[i][3] * future_args[i][4]
             for i in range(len(future_args))]).sum()

    if return_chi:
        assert total_area is not None and total_planted_area is not None, \
                ('Must provide total_area and total_planted_area to ' +
                 'calculate chi.')
        chi_p = calculate_chi(present_args, total_area, total_planted_area)
        chi_f = calculate_chi(future_args, total_area, total_planted_area)
        return [Q1, chi_p, chi_f]

    return Q1
