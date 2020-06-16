# load ACP data and apply the algorithm to it
import numpy as np
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
from cilpath import Cilpath
paths = Cilpath()
import sys
sys.path.append('{}/agriculture/1_code/5_crop_shift/3_algorithm/functions'
                .format(paths.REPO))
from multi_moment.match_moments import match_moments
from single_moment.z_old.match_moment import match_moment, calculate_chi
from state_abbrev_dict import abbreviate_state_name
from calculate_welfare_changes import calculate_welfare_changes

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

# Global parameters
wt = 'allcropwt'  # the weights we want our GAEZ data aggregated to

##############################
# Part 1: Get the data ready #
##############################

# start with a crosswalk for regions
hierid_cw = pd.read_csv(('{}/GCP_Reanalysis/cross_sector/IR_fips_cw.csv'
                         .format(paths.DB)))
hierid_cw['state'] = hierid_cw['state'].apply(abbreviate_state_name)


def prep_acp(crop, rcp='rcp85', year='2080'):
    '''
    Load and prep ACP data.
    '''
    df = pd.read_csv('/shares/gcp/outputs/agriculture/acp_impacts/Agriculture/'
                     'state_20yr/yields-{crop}-{rcp}-{year}b.csv'
                     .format(crop=crop, rcp=rcp, year=year))

    # select only the median impacts
    df = df[['state', 'region', 'q0.5']]
    df.rename(columns={'region': 'statefips', 'q0.5': 'impact'}, inplace=True)
    df['crop'] = crop

    # also set a random seed that will be crop specific
    if crop == 'grains':
        df['gaez_crop'] = 'maize'
        np.random.seed(0)
    elif crop == 'oilcrop':
        df['gaez_crop'] = 'soy'
        np.random.seed(1)
    else:
        df['gaez_crop'] = df['crop']
        np.random.seed(2)

    # merge in the county fips codes
    df = (df.merge(
        hierid_cw,
        how='left',
        on='state')
        .rename(columns={'geoid': 'countyfips'}))

    # the data we're using here are state level only. add some noise in so we
    # get some county-level variation to test our algorithm on.
    # the noise will be normally distributed with SD equal to half the SD in
    # the real data. The intuition I'm going for here is that within-state
    # variability is lower than (eg. half) of country-wide variability.
    SD = np.std(df['impact'])
    df['noise'] = np.random.normal(0, SD / 2, len(df.index))
    df['impact_plus_noise'] = df['impact'] + df['noise']

    return df


grains, cotton, oilcrop = (
    [prep_acp(c) for c in ['grains', 'cotton', 'oilcrop']]
)

acp_impacts = pd.concat([grains, cotton, oilcrop])
acp_impacts.drop(['statefips'], axis=1, inplace=True)

# load yield levels. Just using GAEZ for this right now since the future
# scaling we're going to be using only applies at the country level and the
# algorithm is invariant to scaling
gaez = pd.read_csv(('/shares/gcp/estimation/agriculture/Data/2_intermediate/'
                    'potential_yield/hierid/{}/gaez_potential_yield_usa.csv'
                    ).format(wt))

gaez = gaez.merge(hierid_cw, left_on='adm2_id', right_on='region')
gaez.rename(columns={'geoid': 'countyfips'}, inplace=True)


# load planted area by hierid.
sage = pd.read_csv('/shares/gcp/estimation/agriculture/Data/2_intermediate/'
                   'cropped_area/hierid/z_old/sage_cropped_area_usa.csv')
sage = sage.merge(hierid_cw, left_on='hierid', right_on='region')
sage.rename(columns={'geoid': 'countyfips'}, inplace=True)
sage.drop(['county', 'region', 'state'], axis=1, inplace=True)

# calculate total arable acres (note this is a stand-in)
total_area = (sage.loc[sage.crop == 'cropland']
              .sort_values(by='countyfips')
              .groupby(['countyfips'])
              .agg({'harvested_hectares': 'sum'})
              .rename(columns={'harvested_hectares': 'total_area'})
              .reset_index())
# calculate the total acres currently planted with main crops
total_planted_area = (sage.loc[sage.crop != 'cropland']
                      .groupby(['countyfips'])
                      .agg({'harvested_hectares': 'sum'})
                      .rename(columns={'harvested_hectares':
                                       'total_planted_area'})
                      .reset_index())

# merge back into sage
sage = (sage.merge(total_area, on='countyfips', how='outer')
            .merge(total_planted_area, on='countyfips', how='outer'))
# create data frame of calories per tonne for diff crops
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

# now merge gaez with acp results
prepped = (gaez.merge(acp_impacts,
                      left_on=['crop', 'countyfips'],
                      right_on=['gaez_crop', 'countyfips'],
                      how='outer')
               .merge(sage,
                      left_on=['countyfips', 'gaez_crop'],
                      right_on=['countyfips', 'crop'],
                      how='outer')
               .rename(columns={'crop_y': 'acp_crop'})
               .merge(cals,
                      left_on=['gaez_crop'],
                      right_on=['crop'],
                      how='outer')
               .sort_values(by='countyfips'))

# apply climate change impacts
prepped['future_yield'] = ((1 + (prepped.impact_plus_noise / 100))
                           * prepped.potential_yield)

# present and future yields are in units of tonnes per hectare
# multiply by calories per tonne to get calories per hectare
prepped['present_calories'] = (prepped.calories_per_tonne
                               * prepped.potential_yield)
prepped['future_calories'] = (prepped.calories_per_tonne
                              * prepped.future_yield)

# note that there are a few 1:m hierid-countyfips matches.
# as a result, we have to do a groupby-summarize before moving on.
# I am doing this naively for now: taking simple sums and averages,
# rather than weighted ones.
prepped = (prepped.groupby(['countyfips', 'gaez_crop'])
           .agg({
                'potential_yield': 'mean',
                'harvested_hectares': 'sum',
                'future_yield': 'mean',
                'present_calories': 'mean',
                'future_calories': 'mean',
                'total_area': 'sum',
                'total_planted_area': 'sum'})
           .unstack(level=1)
           .fillna(0))

###############################
# Part 2: apply the algorithm #
###############################


def get_crop_args(crop, present=True):
    '''
    Function to pull out columns from prepped as numpy arrays that are
    ready to be passed to the moments matching functions.
    '''
    total_area = prepped['total_area'][crop]
    total_planted_area = prepped['total_planted_area'][crop]
    harvested_hectares = prepped['harvested_hectares'][crop]
    if present:
        yields = prepped['potential_yield'][crop]
        calories = prepped['present_calories'][crop]
    else:
        yields = prepped['future_yield'][crop]
        calories = prepped['future_calories'][crop]

    retlist = [total_area, total_planted_area, yields, harvested_hectares,
               calories]

    return [np.array(s) for s in retlist]


crops = ['soy', 'cotton', 'maize']
present_args = [get_crop_args(c) for c in crops]
future_args = [get_crop_args(c, present=False) for c in crops]

# get independent arrays representing total area and total planted area in
# each region
tot_area = (total_area.sort_values(by='countyfips')
            .groupby(['countyfips'])
            .agg({'total_area': 'sum'})
            .merge(prepped.reset_index().loc[:, ['countyfips']],
                   on='countyfips', how='inner')
            ).total_area

tot_planted_area = (total_planted_area
                    .sort_values(by='countyfips')
                    .groupby(['countyfips'])
                    .agg({'total_planted_area': 'sum'})
                    .merge(prepped.reset_index().loc[:, ['countyfips']],
                           on='countyfips', how='inner')
                    ).total_planted_area

# apply moment matching function
# future_args_reallocated = m.match_moments(present_args, future_args)

################################
# QUANTITY CHANGE CALCULATIONS #
################################

Q0 = sum([present_args[i][3] * present_args[i][4]
         for i in range(len(present_args))]).sum()

Q1_no_reallocation = [sum([future_args[i][3] * future_args[i][4]
                           for i in range(len(future_args))]).sum(),
                      calculate_chi(present_args, tot_area, tot_planted_area),
                      calculate_chi(future_args, tot_area, tot_planted_area)]

Q1_chi = match_moment(present_args, future_args, tot_area, tot_planted_area,
                      return_future_chi=True)

Q1_mm_1000 = match_moments(present_args, future_args, step_size=1000,
                           return_chi=True, total_area=tot_area,
                           total_planted_area=tot_planted_area)

Q1_mm_100 = match_moments(present_args, future_args, step_size=100,
                          return_chi=True, total_area=tot_area,
                          total_planted_area=tot_planted_area)

Q1_mm_10 = match_moments(present_args, future_args, step_size=10,
                         return_chi=True, total_area=tot_area,
                         total_planted_area=tot_planted_area)

####################
# CALCULATE AG GDP #
####################


def load_crop_gdp(crop, ssp='SSP3', iam='high', iso='USA', year=2080):
    # load crop-specific ag GDP data from SSP3 high

    ag_GDP = pd.read_csv(('/shares/gcp/social/baselines/agriculture/valuation/'
                          + 'aggdp_cropshare_{}.csv')
                         .format(crop))
    ag_GDP = ag_GDP.loc[(ag_GDP.ssp == ssp) & (ag_GDP.iam == iam)
                        & (ag_GDP.year == year) & (ag_GDP.region == iso), ]
    return ag_GDP.PQ


ag_GDP = ((sum([load_crop_gdp(c) for c in ['maize', 'cotton', 'soybeans']])
           * 1e6)
          .iloc[0])

#############################
# CALCULATE WELFARE CHANGES #
#############################

wfare_no_reallocation = calculate_welfare_changes(Q0=Q0,
                                                  Q1=Q1_no_reallocation[0],
                                                  ag_GDP=ag_GDP)
# calculate for chi
wfare_chi = calculate_welfare_changes(Q0=Q0, Q1=Q1_chi[0], ag_GDP=ag_GDP)

# calculate for gamma and phi (step size 1000)
wfare_mm_1000 = calculate_welfare_changes(Q0=Q0, Q1=Q1_mm_1000[0],
                                          ag_GDP=ag_GDP)

# calculate for gamma and phi (step size 100)
wfare_mm_100 = calculate_welfare_changes(Q0=Q0, Q1=Q1_mm_100[0], ag_GDP=ag_GDP)

wfare_mm_10 = calculate_welfare_changes(Q0=Q0, Q1=Q1_mm_10[0], ag_GDP=ag_GDP)

# repeat the above welfare calculations for chi and no reallocation with
# new elasticities

# 1. 0.5 demand elasticity, 1 supply elasticity
wfare_no_reallocation_1 = calculate_welfare_changes(Q0=Q0,
                                                    Q1=Q1_no_reallocation[0],
                                                    supply_elasticity=1,
                                                    demand_elasticity=-0.5,
                                                    ag_GDP=ag_GDP)

wfare_chi_1 = calculate_welfare_changes(Q0=Q0, Q1=Q1_chi[0], ag_GDP=ag_GDP,
                                        supply_elasticity=1,
                                        demand_elasticity=-0.5)

# 2. 0.5 demand elasticity, 0.5 supply elasticity
wfare_no_reallocation_05 = calculate_welfare_changes(Q0=Q0,
                                                     Q1=Q1_no_reallocation[0],
                                                     ag_GDP=ag_GDP,
                                                     supply_elasticity=0.5,
                                                     demand_elasticity=-0.5)

wfare_chi_05 = calculate_welfare_changes(Q0=Q0, Q1=Q1_chi[0], ag_GDP=ag_GDP,
                                         supply_elasticity=0.5,
                                         demand_elasticity=-0.5)


q_list = [Q1_no_reallocation, Q1_chi, Q1_mm_10, Q1_mm_100, Q1_mm_1000,
          Q1_no_reallocation, Q1_no_reallocation, Q1_chi, Q1_chi]

wfare_list = [wfare_no_reallocation, wfare_chi, wfare_mm_10, wfare_mm_100,
              wfare_mm_1000, wfare_no_reallocation_1, wfare_no_reallocation_05,
              wfare_chi_1, wfare_chi_05]


def make_results_df(model_list, stepsize_list, q_list, wfare_list):
    '''
    Function that returns a nicely-formatted results DataFrame. This can be
    used for plotting or simply looked at to compare results across models.
    '''

    results = pd.DataFrame({
        'model': model_list,
        'step_size': stepsize_list,
        'supply_elasticity': [w[11] for w in wfare_list],
        'demand_elasticity': [w[12] for w in wfare_list],
        'Q1': [q[0] for q in q_list],
        'chi_present': [q[1] for q in q_list],
        'chi_future': [q[2] for q in q_list],
        'delta_total_welfare': [w[0] for w in wfare_list],
        'delta_CS': [w[1] for w in wfare_list],
        'delta_PS': [w[2] for w in wfare_list],
        'area_B': [w[3] for w in wfare_list],
        'area_C': [w[4] for w in wfare_list],
        'area_D': [w[5] for w in wfare_list],
        'area_F': [w[6] for w in wfare_list],
        'area_G': [w[7] for w in wfare_list],
        'area_H': [w[8] for w in wfare_list],
        'pchange_Q0_Q2': [w[9] for w in wfare_list],
        'pchange_P0_P1': [w[10] for w in wfare_list]
    })

    return results


# save csvs of all the above results
results = make_results_df(
    model_list=['No realloaction', 'Single moment',
                'Multi-moment, 10 step', 'Multi-moment, 100 step',
                'Multi-moment, 1000 step', 'No reallocation',
                'No reallocation', 'Single moment', 'Single moment'],
    stepsize_list=[np.nan, np.nan, 10, 100, 1000, np.nan, np.nan, np.nan,
                   np.nan],
    q_list=q_list,
    wfare_list=wfare_list
)

results.to_csv('{}/GCP_Reanalysis/AGRICULTURE/4_outputs/'.format(paths.DB)
               + '3_projections/5_crop_shift/acp_test/{}/'.format(wt)
               + 'model_results_comparison.csv',
               index=False)

# make a version of the results with only the single moment and no reallocation
# cases
results_small = make_results_df(
    model_list=['no reallocation', 'with reallocation'] * 3,
    stepsize_list=[np.nan] * 6,
    q_list=[Q1_no_reallocation, Q1_chi] * 3,
    wfare_list=[wfare_no_reallocation, wfare_chi, wfare_no_reallocation_1,
                wfare_chi_1, wfare_no_reallocation_05, wfare_chi_05]
)


def plot_barchart(saveas, mincol=10, maxcol=16, rowlist=None,
                  title=None, transpose=True, results_df=results):
    if rowlist is None:
        toplot = results_df.iloc[:, mincol:maxcol]
        toplot['Model'] = results_df.loc[:, 'model']
    else:
        toplot = results_df.iloc[rowlist, mincol:maxcol]
        toplot['Model'] = results_df.iloc[rowlist, ].model

    # make the plot
    if transpose:
        toplot = toplot.transpose()
        toplot.columns = toplot.loc['Model', ]
        toplot.drop('Model', inplace=True)
        toplot.plot.bar()
    else:
        toplot.plot.bar(x='Model')

    # add some formatting
    plt.title(title)
    lgd = plt.legend(bbox_to_anchor=(.65, 1))

    # set the y ticks to be in billions of $
    locs, labels = plt.yticks()
    plt.yticks(locs, map(lambda x: "%.1f" % x, locs / 1e9))
    plt.ylabel('Area (billions of dollars)')

    # save
    plt.savefig(saveas, bbox_extra_artists=(lgd,), bbox_inches='tight')

    return 'Saved {}'.format(saveas)


# make a bar chart of the different areas in each model
savepath_root = ('{}/GCP_Reanalysis/AGRICULTURE/4_outputs/'.format(paths.DB)
                 + '3_projections/5_crop_shift/acp_test/{}'.format(wt))

plot_barchart(mincol=10, maxcol=16,
              saveas='{}/model_results_comparison.pdf'.format(savepath_root))

# plot barcharts for each version of elasticity sensitivity (only for chi and
# no reallocation)
plot_barchart(results_df=results_small,
              rowlist=[0, 1],
              saveas=('{}/results_comparison_SE100_DEn001.pdf'
                      .format(savepath_root)),
              title='Supply Elasticity: 1, Demand Elasticity: -0.1')

plot_barchart(results_df=results_small,
              rowlist=[2, 3],
              saveas=('{}/results_comparison_SE100_DEn050.pdf'
                      .format(savepath_root)),
              title='Supply Elasticity: 1, Demand Elasticity: -0.5')

plot_barchart(results_df=results_small,
              rowlist=[4, 5],
              saveas=('{}/results_comparison_SE050_DEn050.pdf'
                      .format(savepath_root)),
              title='Supply Elasticity: 0.5, Demand Elasticity: -0.5')

# make a combined bar chart with all the elasticity sensitivities in it
e = results_small.copy()
e['model'] = (e['model'] + ', SE=' + e['supply_elasticity'].astype(str)
              + ', DE=' + e['demand_elasticity'].astype(str))
e.sort_values(by=['model'], inplace=True)
plot_barchart(results_df=e,
              saveas=('{}/elasticity_results_comparison.pdf'
                      .format(savepath_root)),
              title='Elasticity robustness')

# do elasticity sensitivity with just PS and CS
plot_barchart(results_df=e, mincol=7, maxcol=10,
              saveas=('{}/elasticity_results_comparison_delta_wfare_only.pdf'
                      .format(savepath_root)),
              title='Elasticity robustness')
