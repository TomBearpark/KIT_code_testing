'''
Calculate welfare changes given a change in quantity.
'''
import warnings

__author__ = 'Simon Greenhill'
__contact__ = 'sgreenhill@uchicago.edu'
__version__ = '1.0'


def calculate_welfare_changes(Q0, Q1, demand_elasticity=-0.1,
                              supply_elasticity=1, ag_GDP=1000):
    '''
    Calculate welfare changes resulting from climate shock to agricultural
    production.
    Parameters
    ----------
    Q0: float
        Total calories produced before the climate shock
    Q1: float
        Total calories produced after the climate shock but before considering
        the equilibrium shift
    '''
    warnings.warn('Welfare calculations currently implemented only for '
                  + 'negative supply shocks')

    # Calculate Q2: post-climate shock quantity with equilibrium shift
    Q2 = (
        (supply_elasticity - demand_elasticity)
        / ((supply_elasticity / Q0) - (demand_elasticity / Q1))
    )

    # percent change fro Q0 to Q2
    Q0_Q2 = (Q2 / Q0 - 1)
    # percent change from P0 to P1
    P0_P1 = (Q2 / Q0 - 1) / demand_elasticity

    # calculate areas corresponding to welfare
    # areas to calculate: B, C, D, F, G, H
    C = 0.5 * ((Q2 - Q1) / Q0) * P0_P1 * ag_GDP

    B = P0_P1 * (Q2 / Q0) * ag_GDP - C

    D = 0.5 * (1 - Q2 / Q0) * P0_P1 * ag_GDP

    F = (Q1 / Q0) * ((1 - Q1 / Q0) / supply_elasticity) * ag_GDP

    G = (0.5
         * ((Q2 - Q1) / Q0)  # height
         * ((1 - Q1 / Q0) / supply_elasticity  # base 1
            + (1 - Q2 / Q0) / supply_elasticity)  # base 2
         * ag_GDP)

    H = 0.5 * (1 - Q2 / Q0) * ((1 - Q2 / Q0) / supply_elasticity) * ag_GDP

    # make sure all areas are positive
    assert all([a >= 0 for a in [B, C, D, F, G, H]]), 'Not all areas >= 0'

    # calculate consumer and producer surplus changes
    delta_CS = -B - C - D
    delta_PS = B - F - G - H
    total_welfare_change = delta_CS + delta_PS

    return [total_welfare_change, delta_CS, delta_PS, B, C, D, F, G, H, Q0_Q2,
            P0_P1, supply_elasticity, demand_elasticity]
