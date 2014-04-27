######### import config
while getopts ":config:" opt; do
case $opt in
 config)
 export CONFIG=$OPTARG
 echo "use config file $CONFIG"
 ;;
 \?)
 echo "Invalid option: -$OPTARG" >&2
 exit 1
 ;;
 :)
 echo "Option -$OPTARG requires an argument." >&2
 exit 1
 ;;
esac
done

######### build cortical surface and region mapping
cd $PRD/scripts
if [ ! -f $PRD/data/T1/T1.nii ]
then
echo "generating T1 from DICOM"
mrconvert $PRD/data/T1/ $PRD/data/T1/T1.nii
fi

###################### freesurfer
if [ ! -d $FS/$SUBJ_ID ] 
then
echo "running recon-all of freesurfer"
recon-all -i $PRD/data/T1/T1.nii -s $SUBJ_ID -all
fi

###################################### left hemisphere
# export pial into text file
mkdir -p ../surface
if [ ! -f $PRD/surface/lh.pial.asc ]
then
echo "importing left pial surface from freesurfer"
mris_convert $FS/$SUBJ_ID/surf/lh.pial $PRD/surface/lh.pial.asc
fi

# triangles and vertices high
if [ ! -f $PRD/surface/lh_vertices_high.txt ]
then
echo "extracting left vertices and triangles"
python left_extract_high.py
fi

# decimation using brainvisa
if [ ! -f $PRD/surface/lh_vertices_low.txt ]
then
echo "left decimation using brainvisa"
# -> to mesh
$BV/bin/python left_transform_mesh_high.py
#  decimation
$BV/bin/AimsMeshDecimation $PRD/surface/lh_mesh_high.mesh $PRD/surface/lh_mesh_low.mesh
# export to list vertices triangles
$BV/bin/python left_export_to_vertices.py
fi

# create left the region mapping
if [ ! -f $PRD/surface/lh_region_mapping_low_not_corrected.txt ]
then
echo "generating the left region mapping on the decimated surface"
matlab -r "run left_region_mapping.m; quit;" -nodesktop -nodisplay
fi

# check
if [ ! -f $PRD/surface/lh_region_mapping_low.txt ]
if [ -n "$DISPLAY" ] && [ "$CHECK" = "yes" ] 
then
echo "check left region mapping"
python check_left_region_mapping.py
else
echo "correct the left region mapping"
# correct
python correct_left_region_mapping.py
fi
fi

###################################### right hemisphere
# export pial into text file
if [ ! -f $PRD/surface/rh.pial.asc ]
then
echo "importing right pial surface from freesurfer"
mris_convert $FS/$SUBJ_ID/surf/rh.pial $PRD/surface/rh.pial.asc
fi

# triangles and vertices high
if [ ! -f $PRD/surface/rh_vertices_high.txt ]
then
echo "extracting right vertices and triangles"
python right_extract_high.py
fi

# decimation using brainvisa
if [ ! -f $PRD/surface/rh_vertices_low.txt ]
then
echo "right decimation using brainvisa"
# -> to mesh
$BV/bin/python right_transform_mesh_high.py
#  decimation
$BV/bin/AimsMeshDecimation $PRD/surface/rh_mesh_high.mesh $PRD/surface/rh_mesh_low.mesh
# export to list vertices triangles
$BV/bin/python right_export_to_vertices.py
fi

if [ ! -f $PRD/surface/rh_region_mapping_low_not_corrected.txt ]
then
echo "generating the right region mapping on the decimated surface"
# create left the region mapping
matlab -r "run right_region_mapping.m; quit;" -nodesktop -nodisplay
fi

# check
if [ ! -f $PRD/surface/rh_region_mapping_low.txt ]
if [ -n "$DISPLAY" ] && [ "$CHECK" = "yes" ]
then
echo "check right region mapping"
python check_right_region_mapping.py
else
echo " correct the right region mapping"
# correct
python correct_right_region_mapping.py
fi
fi
###################################### both hemisphere
# prepare final directory
mkdir -p $PRD/$SUBJ_ID
mkdir -p $PRD/$SUBJ_ID/surface

# reunify both region_mapping, vertices and triangles
if [ ! -f $PRD/$SUBJ_ID/surface/region_mapping.txt ]
then
echo "reunify both region mappings"
python reunify_both_regions.py
fi

# zip to put in final format
cd $PRD/$SUBJ_ID/surface
zip $PRD/$SUBJ_ID/surface.zip vertices.txt triangles.txt
cp region_mapping.txt ..
cd $PRD/scripts

########################### subcortical surfaces
# extract subcortical surfaces 
if [ ! -f $PRD/surface/subcortical/aseg_058_vert.txt ]
then
echo "generating subcortical surfaces"
./aseg2srf -s $SUBJ_ID
mkdir -p $PRD/surface/subcortical
cp $FS/$SUBJ_ID/ascii/* $PRD/surface/subcortical
python list_subcortical.py
fi

########################## build connectivity
# mrtrix
mkdir -p $PRD/connectivity
mkdir -p $PRD/$SUBJ_ID/connectivity
# mrconvert
if [ ! -f $PRD/connectivity/dwi.mif ]
then
mrconvert $PRD/data/DWI/ $PRD/connectivity/dwi.mif
fi
# brainmask 
if [ ! -f $PRD/connectivity/lowb.nii  ]
then
average $PRD/connectivity/dwi.mif -axis 3 $PRD/connectivity/lowb.nii
fi
if [ ! -f $PRD/connectivity/mask_not_checked.mif ]
then
threshold -percent $percent_value_mask $PRD/connectivity/lowb.nii - | median3D - - | median3D - $PRD/connectivity/mask_not_checked.mif
fi

# check the mask
if [ ! -f $PRD/connectivity/mask_checked.mif ]
then
cp mask_not_checked.mif mask_checked.mif
if [ -n "$DISPLAY" ]  && [ "$CHECK" = "yes" ]
then
while true; do
mrview $PRD/connectivity/mask_checked.mif
read -p "was the mask good?" yn
case $yn in
[Yy]* ) break;;
[Nn]* ) read -p "enter new threshold value" percent_value_mask; echo $percent_value_mask; rm $PRD/connectivity/mask_checked.mif; 
	threshold -percent $percent_value_mask $PRD/connectivity/lowb.nii - | median3D - - | median3D - $PRD/connectivity/mask.mif;;
 * ) echo "Please answer y or n.";;
esac
done
fi
fi

if [ -f $PRD/connectivity/mask_checked.mif ]
then
cp mask_checked.mif mask.mif
elif [ -f $PRD/connectivity/mask_not_checked.mif ]
then
cp mask_checked.mif mask.mif
fi

# tensor imaging
if [ ! -f $PRD/connectivity/dt.mif ]
then
dwi2tensor $PRD/connectivity/dwi.mif $PRD/connectivity/dt.mif
fi
if [ ! -f $PRD/connectivity/fa.mif ]
then
tensor2FA $PRD/connectivity/dt.mif - | mrmult - $PRD/connectivity/mask.mif $PRD/connectivity/fa.mif
fi
if [ ! -f $PRD/connectivity/ev.mif ]
then
tensor2vector $PRD/connectivity/dt.mif - | mrmult - $PRD/connectivity/fa.mif $PRD/connectivity/ev.mif
fi
# constrained spherical decconvolution
if [ ! -f $PRD/connectivity/sf.mif ]
then
erode $PRD/connectivity/mask.mif -npass 3 - | mrmult $PRD/connectivity/fa.mif - - | threshold - -abs 0.7 $PRD/connectivity/sf.mif
fi
if [ ! -f $PRD/connectivity/response.txt ]
then
estimate_response $PRD/connectivity/dwi.mif $PRD/connectivity/sf.mif -lmax $lmax $PRD/connectivity/response.txt
fi
if  [ -n "$DISPLAY" ]  &&  [ "$CHECK" = "yes" ]
then
disp_profile -response $PRD/connectivity/response.txt
fi
if [ ! -f $PRD/connectivity/CSD6.mif ]
then
csdeconv $PRD/connectivity/dwi.mif $PRD/connectivity/response.txt -lmax $lmax -mask $PRD/connectivity/mask.mif $PRD/connectivity/CSD6.mif
fi

# tractography
if [ ! -f $PRD/connectivity/whole_brain_1.tck ]
then
echo "generating tracks"
for I in 1 2 3 4 5 6 7 8 9 10
do
streamtrack SD_PROB $PRD/connectivity/CSD6.mif -seed $PRD/connectivity/mask.mif -mask $PRD/connectivity/mask.mif $PRD/connectivity/whole_brain_$I.tck -num 100000
done
fi

# FLIRT registration
#Diff to T1
if [ ! -f $PRD/connectivity/T1.nii ]
then
echo "generating good orientation for T1"
mri_convert --in_type mgz --out_type nii --out_orientation RAS $FS/$SUBJ_ID/mri/T1.mgz $PRD/connectivity/T1.nii
fi
if [ ! -f $PRD/connectivity/aparc+aseg.nii ]
then
echo " getting aparc+aseg"
mri_convert --in_type mgz --out_type nii --out_orientation RAS $FS/$SUBJ_ID/mri/aparc+aseg.mgz $PRD/connectivity/aparc+aseg.nii
fi

#flirt -in $PRD/connectivity/lowb.nii -ref $PRD/data/T1/T1.nii -omat $PRD/connectivity/diffusion_2_struct.mat -out $PRD/connectivity/lowb_2_struct.nii
# T1 to Diff (INVERSE)
#convert_xfm -omat $PRD/connectivity/diffusion_2_struct_inverse.mat -inverse $PRD/connectivity/diffusion_2_struct.mat
#flirt -in $PRD/connectivity/aparc+aseg.nii -ref $PRD/connectivity/lowb.nii  -out $PRD/connectivity/aparcaseg_2_diff.nii.gz -init $PRD/connectivity/diffusion_2_struct_inverse.mat -applyxfm -interp nearestneighbour
if [ ! -f $PRD/connectivity/aparcaseg_2_diff.nii.gz ]
then
echo " register aparc+aseg to diff"
flirt -in $PRD/connectivity/aparc+aseg.nii -ref $PRD/connectivity/lowb.nii -out $PRD/connectivity/aparcaseg_2_diff.nii -interp nearestneighbour 
fi

# now compute connectivity and length matrix
if [ ! $PRD/$SUBJ_ID/connectivity_weights.txt ]
then
echo "compute connectivity matrix"
matlab -r "run compute_connectivity.m; quit;" -nodesktop -nodisplay
fi

########
# we do not compute hemisphere
# subcortical is already done
cp cortical.txt $PRD/$SUBJ_ID/connectivity/cortical.txt

# # compute centers, areas and orientations
if [ ! $PRD/$SUBJ_ID/connectivity/centres.txt ]
then
echo " generate useful files for TVB"
python compute_other_files.py
fi

# zip to put in final format
cd $PRD/$SUBJ_ID/connectivity
zip $PRD/$SUBJ_ID/connectivity.zip area.txt orientation.txt weights.txt tracts.txt cortical.txt centres.txt
cd $PRD/scripts