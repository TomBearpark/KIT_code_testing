# functions to calculate phi and gamma
import numpy as np
import warnings

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'

# for iteratives, how many hectares do you want to move at a time?
step_size = 1000


def calculate_gamma(args):
    """
    Calculate gamma, the ratio of calories grown to potential calories grown
    if crops were grown to maximize total yield.

    Parameters
    ----------
    args: list
        A list with one element per crop. Each element of the list should be
        another list of length 2, where the first element is an array of the
        acres planted of that crop and the second is an array of the yields
        in calories per bushel of that crop.
    """
    # calculate the number of calories produced in each plot for each crop,
    # the sum them all up
    total_cal = sum([sum(acres * cals) for acres, cals in args])

    # calculate potential calories by picking the max calorie yield on each
    # plot and applying it to all the acres planted for that crop
    max_cal = np.amax(np.stack([args[i][1] for i in range(len(args))]), axis=0)
    total_acres = np.sum(np.stack([args[i][0]
                                   for i in range(len(args))]), axis=0)
    potential_cal = sum(max_cal * total_acres)

    return total_cal / potential_cal


def analyze_empty_acreage(total_acres, acres_planted, yields, crop_acreage):
    """
    Identify the lowest-yielding used acre and the highest-yielding unused
    acre. Note that this calculation is crop-specific.

    Parameters
    ----------
    total_acres: array
        The total number of acres available for agricultural production in
        each region
    acres_planted: array
        The total number of acres planted in each region
    yields: array
        The crop-specific average yield in each region
    crop_acreage: array
        The number of acres of the crop planted in each region

    Returns
    -------
    list
        The indices of the lowest-yielding currently planted region and the
        highest-yielding currently empty region.
    """

    empty_acres = total_acres - acres_planted

    try:
        assert all(empty_acres >= 0), 'empty_acres contains negative values'
    except AssertionError:
        warnings.warn('More acres planted than available in some areas.'
                      + 'Replace negative empty_acres values with 0s.')
        empty_acres = np.where(empty_acres < 0, 0, empty_acres)

    empty_max_yield = yields[empty_acres > 0].max()
    empty_max_id = np.argwhere(
        (empty_acres > 0) & (yields == empty_max_yield))[0].item()

    used_min_yield = yields[acres_planted > 0].min()
    used_min_id = np.argwhere(
        (crop_acreage > 0) & (yields == used_min_yield))

    if used_min_id.size == 0:
        used_min_id = np.nan
    else:
        used_min_id = used_min_id[0].item()

    return [empty_max_id, used_min_id]


def calculate_phi(total_acres, acres_planted, yields, crop_acreage,
                  step_size=step_size):
    """
    Calculate phi, the ratio of actual to potential yields for a crop. The
    potential yield is defined as the total yield if the crop's acres were
    optimally spatially allocated, conditional on the number of acres planted.

    Parameters
    """
    # calculate actual yield
    actual_yield = (crop_acreage * yields).sum()

    # calculate potential yield
    empty_max_id, used_min_id = (
        analyze_empty_acreage(
            total_acres,
            acres_planted,
            yields,
            crop_acreage))

    crop_acreage = crop_acreage.copy()
    acres_planted = acres_planted.copy()

    while (
        (not np.isnan(used_min_id)) and
        (yields[empty_max_id] > yields[used_min_id])
    ):
        for a in crop_acreage, acres_planted:
            a[empty_max_id] += step_size
            a[used_min_id] -= step_size

        empty_max_id, used_min_id = (
            analyze_empty_acreage(
                total_acres,
                acres_planted,
                yields,
                crop_acreage)
        )

    potential_yield = (crop_acreage * yields).sum()

    return actual_yield / potential_yield
