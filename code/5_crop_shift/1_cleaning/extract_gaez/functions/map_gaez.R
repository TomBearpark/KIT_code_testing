# Map extracted and aggregated GAEZ data to make sure it's right
# Author: Simon Greenhill, sgreenhill@uchicago.edu
# Date: 4/17/2020

library(glue)
cilpath.r:::cilpath()

source(glue('{REPO}/agriculture/1_code/5_crop_shift/1_cleaning/extract_gaez/',
	        'scripts/extract_gaez.R'))

# first make a combined shapefile
load_shapefile = function(iso, shppath=shp_input) {
	# get the shapefile info
	shpinfo = get_shapefile_info(iso)
	shpname = shpinfo$shpname
	adm_id_1 = shpinfo$adm_id_1
	adm_id_2 = shpinfo$adm_id_2
	shppath = glue('{shppath}/{iso}/shapefile/')
	shp = st_read(dsn=shppath, layer=shpname, stringsAsFactors=FALSE)

	if (is.null(adm_id_1)) {
			shp %<>% 
				rename(adm2_id = !!adm_id_2) %>%
				# for NUTS ids, get the NUTS1 by substringing the NUTS2
				mutate(adm1_id = substr(adm2_id, 1, 3))
		} else if (is.null(adm_id_2)) {
			shp %<>%
				rename(adm1_id = !!adm_id_1) %>%
				# if our yield data is at adm1 level, replace adm1 with
				# the empty string
				mutate(adm2_id = '')
		} else {
			shp %<>%
				rename(adm1_id = !!adm_id_1, adm2_id = !!adm_id_2)
		}


	return(shp)
}

load_and_combine = function(iso1, iso2) {
	# force geometries to be multipolygons so they can be rbinded correctly
	if (is_character(iso1)) {
		shp1 = load_shapefile(iso1) %>%
			mutate(geometry = st_cast(geometry, 'MULTIPOLYGON')) %>%
			data.table()	
	} else {
		shp1 = iso1 %>%
			data.table()
	}
	
	shp2 = load_shapefile(iso2) %>%
		mutate(geometry = st_cast(geometry, 'MULTIPOLYGON')) %>%
		data.table()

	comb = rbind(shp1, shp2, fill=TRUE) %>%
		st_sf()

	return(comb)
}

combined_shp = Reduce(f = load_and_combine, isos) %>%
	dplyr::select(ISO, adm1_id, adm2_id, geometry)

st_write(combined_shp, 
	dsn = glue('{shp_input}/shapefile/'), 
	layer='all_country_shapefile',
	driver = 'ESRI Shapefile',
	delete_dsn=TRUE)

shp_for_plot = combined_shp %>%
	group_by(ISO, adm1_id, adm2_id) %>%
	mutate(ID_master = group_indices()) %>%
	ungroup() %>%
	# simplify the shapefile for faster plotting
	# st_simplify(10^8) %>% # get rid of fine detail 
	st_cast("MULTIPOLYGON") %>% # cast all polygons as multipolygons so they can be easily decluttered 
	st_cast("POLYGON") %>% # remove small islands and other clutter 
	mutate(area=as.numeric(st_area(.))) %>% # compute area of each polygon
	st_transform(crs="+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs") %>%
	filter(area > 10^8) %>% # get rid of small areas
	group_by(ID_master) %>%
	st_buffer(0) %>% # avoids an error due to intersecting polygons 
	as('Spatial') %>%
	fortify(region='ID_master') %>%
	data.frame() %>%
	mutate(id = as.numeric(id))

# get a world shapefile to add as a background to map
world_dir = glue('{DB}/Wilkes_InternalMigrationGlobal/',
		'internal/Data/Raw/Oct2018Download/shp/')
world_sf = st_read(dsn = glue("{world_dir}/world/simplified/"), 
                   layer = "world_countries_2017_simplified")

world_sp = world_sf %>%

	as('Spatial') %>%
	spTransform(CRS("+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs")) %>%
	gBuffer(byid=TRUE, width=0) %>%
	fortify(region="CNTRY_CODE")


# plot the map here
plot_crop_map = function(map=shp_for_plot, df=all_data, crop) {
	df %<>%
		filter(crop == crop) %>%
		group_by(iso, adm1_id, adm2_id) %>%
		mutate(ID_master = group_indices()) %>%
		ungroup()

	p = join.plot.map(
			map.df = map,
			df = df,
			df.key = 'ID_master',
			map.key = 'id',
			plot.var = 'potential_yield',
			color.scheme = 'seq',
			topcode = T,
			topcode.lb = 0,
			topcode.ub = 10
			) +
		# geom_sf(data=world_sp, lwd=0.0)
		geom_path(aes(x=long, y=lat, group=group))

	filename=glue(
			'{DB}/GCP_Reanalysis/AGRICULTURE/4_outputs/1_data_quality_checks/',
			'GAEZ_potential_yield/potential_yield_map_{crop}.png')

	ggsave(
		plot=p, 
		filename=filename
		)

	return(glue('Saved {filename}.'))
}

plot_crop_map('maize')