'''
THIS VERSION DEPRECATED. SEE ../match_moment.py for new version.
Function to calculate and match a single moment of the distribution of
crops, chi. These functions are set up to accept arguments formatted
in the same way as for the functions in multi_moment/match_moments.py
so both sets approaches can be used on the same data more seamlessly.
'''

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

from cilpath import Cilpath
paths = Cilpath()
import sys
sys.path.append('{}/agriculture/1_code/5_crop_shift/3_algorithm/scripts'
                .format(paths.REPO))
from single_moment.calculate_moment import calculate_chi, maximize_output


def match_moment(present_args, future_args, total_area, total_planted_area,
                 return_future_chi=False):
    '''
    Calculate Q1, the number of calories produced in a future period.
    '''
    chi = calculate_chi(present_args, total_area, total_planted_area)
    max_q1 = maximize_output(future_args, total_area, total_planted_area)

    if return_future_chi:
        q1 = sum([future_args[i][3] * future_args[i][4]
                  for i in range(len(future_args))]).sum()
        return [chi * max_q1, chi, q1 / max_q1]

    return chi * max_q1
