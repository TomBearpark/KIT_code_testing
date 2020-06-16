# Make maps of globally calculated chi
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

source(glue::glue('{REPO}/post-projection-tools/mapping/mapping.R'))
map = load.map()
map$iso = substr(map$id, 1, 3)

# load chi data (produced by calculate_global_chi.py)
chi = data.table::fread(
	glue::glue('{chi_path}/data/chi_global.csv')
	)

# set up params for map
colors = c('#ffffe5','#f7fcb9','#d9f0a3','#addd8e','#78c679','#41ab5d',
	       '#238443','#006837','#004529')
p = join.plot.map(
	map.df=map,
	df=chi,
	df.key='iso',
	map.key='iso',
	plot.var='chi',
	color.scheme='seq',
	color.values=colors,
	colorbar.title='chi',
	map.title='Country-level chi',
	minval = 0,
	maxval = 1,
	breaks_labels_val = seq(0, 1, 0.1)
	)

save_path = glue('{chi_path}/outputs/maps/')
dir.create(save_path)
ggplot2::ggsave(plot=p,
	            filename=glue('{save_path}/global_chi_map.png'))