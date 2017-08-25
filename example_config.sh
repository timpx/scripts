#######################
# Example config file #
#######################

####################################
# Copy this file wherever you want #
# (in the root directory for your  #
# data would be a good idea)       #
# and change the relevant options  #
####################################

#### Path configurations

# to run the pipeline, do:
# for region pipeline:
# bash path_to_scripts/main_region.sh -c path_to_config/config.sh
# for surface pipeline: 
# bash path_to_scripts/main_surface.sh -c path_to_config/config.sh



#### Mandatory path parameters

# the root directory for files 
# this is where all data and processed data are
# we advice to also put this config file in this directory
export PRD=/path_to_root_dir/

# subject name
# this will determine the name of your subject
# in brainvisa and in the final directory
export SUBJ_ID=name_subj

# Matlab Runtime Compiler path
# if you have matlab, do mcrinstaller at the matlab prompt
# to find the location of the MCR
# alternatively you can uncomment the following line and comment the MCR line
# export matlab=/path_to_matlab/
# if you don't have matlab, download the MCR (linux 64 bits) here: 
# http://www.mathworks.com/products/compiler/mcr/index.html
export MCR=/path_to_matlab_runtime_compiler/


#### Additional optional parameters
# The defaults indicates the options chosen by the pipeline if the option is 
# not set

# error handling: in case of error, the pipeline 
# stops immediately
# default: not set
# set -e

# FSL prefix in case of use of fsl5.0 and fsl 4 is present
# for instance FSL="fsl5.0' or FSL="" otherwise
# if only fsl5.0 is installed, leave empty
# default: empty
export FSL=""


#### Pipeline parameters
# The defaults indicates the options chosen by the pipeline if the option is 
# not set

# check the processed data when the pipeline is running
# (you need a display and mrview installed) (no/yes)
export CHECK="no"

# This parameter is important for the correction of the region mapping. 
# Between 0 and 1. The bigger it is, the bigger is the correction. 
# (only import for the surface pipeline: main_surface.sh)
# default: 0.42
export region_mapping_corr="0.42"

# for computing subconnectivity
# if you want subdivided parcellations, you can set the folowing value
# according to the following table
# K:                 0   1   2    3    4    5
# Number of Nodes:  70  140 280  560  1120 2240
# default: ""
export K_list="0 1 2 3 4 5"

# number of tracks used in the tractography step.
# note that you will have less tracks at the end.
# default: 10.000.000
export number_tracks=10000000

# TODO
# uniquely for region pipeline (main_region.sh)
# choice of the parcellation
# export parcel=AAL

# TODO
# use topup and eddy distortion correction
# this depends of you images
# be careful with "reversed", depending on your data, 
# you may have to change the main_surface script
# options: ["no", "reversed", "eddy_correct"], default: "eddy_correct"
export topup="no"

# use Anatomically Constrained Tractography (yes/no)
# options ["yes", "no"]; default: "yes"
export act="yes"

# using Spherical-deconvolution informed filtering of tractograms 
# options: ["sift", "sift2", "no"]; default: SIFT2
export sift="sift2"

# if using SIFT, you can set the sift_multiplier variable:
# the number of tracks generated will be number_tracks*sift_multiplier
# default: 10
# export sift_multiplier=10

# seeding mechanism for tckgen if using act, otherwise default to dynamic
# options: ["gmwmi", "dynamic"]; default: "gmwmi"
export seed="gmwmi"

# subcortical segmentation correction
# options: ["fs", "fsl"]; default: "fsl"
export aseg="fsl" 

# number of threads
# default: value in ~/.mrtrix.conf file if present, or 1 if not present
export nb_threads=1