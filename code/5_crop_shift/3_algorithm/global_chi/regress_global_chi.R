# Run regressions of chi on GDP and climate
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 5/29/2020

rm(list=ls())
library(data.table)
library(dplyr)
library(magrittr)
library(glue)
library(cilpath.r)

cilpath.r:::cilpath()
chi_path = glue('{DB}/GCP_Reanalysis/AGRICULTURE/4_outputs/',
               '3_projections/5_crop_shift/chi/')

# load chi data (produced by calculate_global_chi.py)
chi = data.table::fread(
	glue::glue('{chi_path}/data/chi_global.csv')
	)

# merge in GDP data (use PWT for now)
pwt = 