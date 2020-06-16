'''
This script calculates welfare changes given an impact of climate change on
calories produced and produces diagnostic plots.
'''

import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
from cilpath import Cilpath
paths = Cilpath()
import sys
sys.path.append('{}/agriculture/1_code/5_crop_shift/3_algorithm/scripts'
                .format(paths.REPO))
from calculate_welfare_changes import calculate_welfare_changes

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

# load results
results = pd.read_csv('{}/GCP_Reanalysis/AGRICULTURE/'.format(paths.DB)
                      + '4_outputs/3_projections/5_crop_shift/'
                      + 'model_results_comparison.csv')
