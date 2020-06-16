'''
This script takes projections of the impacts of climate change on agricultural
yields for grains, cotton, and oilcrops from the ACP and applies two crop
reallocation algorithms to those projections.

The first algorithm scales projected losses so the ratio of total calories
grown to maximum possible calories grown is constant across time, conditional
on the total number of acres planted.

The second algorithm iteratively reassigns crops in space so two moments are
held constant through time: the ratio of total calories to maximum possible
calories conditional on where crops are grown, and the crop-specific ratio
of total yields and maximum total yield conditional on the number of acres
planted.

Caveats (see inline comments for futher details):
- 
'''

from cilpath import Cilpath
paths = Cilpath()
import sys
sys.path.append('{}/agriculture/1_code/5_crop_shift/3_algorithm/scripts'
                .format(paths.REPO))
from multi_moment.match_moments import match_moments
from single_moment.match_moment import match_moment, calculate_chi
from state_abbrev_dict import abbreviate_state_name
import numpy as np
import pandas as pd

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'
