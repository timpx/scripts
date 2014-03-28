################# parameter
# the directory with all files
export PRD=/disk2/Work/Processed_data/tim_pipeline/TREC/
# freesurfer 
export FS=$SUBJECTS_DIR
# subject name
export SUBJ_ID=TREC
# brainvisa directory
export BV=/home/tim/Work/Soft/brainvisa-4.3.0/


########## build cortical surface and region mapping
cd $PRD/scripts
###################### freesurfer
recon-all -i $PRD/data/T1/ -s $SUBJ_ID -all


###################################### left hemisphere
# export pial into text file
mkdir ../surface
mris_convert $FS/$SUBJ_ID/surf/lh.pial $PRD/surface/lh.pial.asc


# change pial : erase first two lines, get number vertices and triangles
tail -n +3 $PRD/surface/lh.pial.asc > $PRD/surface/lh_pial.txt
sed -n '2p' $PRD/surface/lh.pial.asc | awk '{print $1}' > $PRD/surface/lh_number_vertices_high.txt
sed -n '2p' $PRD/surface/lh.pial.asc | awk '{print $2}' > $PRD/surface/lh_number_triangles_high.txt

# triangles and vertices high
python left_extract_high.py

# -> to mesh
$BV/bin/python left_transform_mesh_high.py

#  decimation
$BV/bin/AimsMeshDecimation $PRD/surface/lh_mesh_high.mesh $PRD/surface/lh_mesh_low.mesh

# export to list vertices triangles
$BV/bin/python left_export_to_vertices.py

# create left the region mapping
matlab -r "run left_region_mapping.m; quit;" -nodesktop

# check
python check_left_region_mapping.py

# correct
#python correct_left_region_mapping.py

###################################### right hemisphere
# export pial into text file
mris_convert $FS/$SUBJ_ID/surf/rh.pial $PRD/surface/rh.pial.asc

# change pial : erase first two lines, get number vertices and triangles
tail -n +3 $PRD/surface/rh.pial.asc > $PRD/surface/rh_pial.txt
sed -n '2p' $PRD/surface/rh.pial.asc | awk '{print $1}' > $PRD/surface/rh_number_vertices_high.txt
sed -n '2p' $PRD/surface/rh.pial.asc | awk '{print $2}' > $PRD/surface/rh_number_triangles_high.txt

# triangles and vertices high
python right_extract_high.py

# -> to mesh
$BV/bin/python right_transform_mesh_high.py

#  decimation
$BV/bin/AimsMeshDecimation $PRD/surface/rh_mesh_high.mesh $PRD/surface/rh_mesh_low.mesh

# export to list vertices triangles
$BV/bin/python right_export_to_vertices.py

# create left the region mapping
matlab -r "run right_region_mapping.m; quit;" -nodesktop

# check
python check_right_region_mapping.py

# correct
#python correct_right_region_mapping.py

###################################### both hemisphere
# prepare final directory
mkdir $PRD/$SUBJ_ID
mkdir $PRD/$SUBJ_ID/surfaces

# reunify both region_mapping, vertices and triangles
python reunify_both_regions.py

# zip to put in final format
zip $PRD/$SUBJ_ID/surface.zip $PRD/$SUBJ_ID/surfaces/vertices $PRD/$SUBJ_ID/surfaces/triangles

########################### subcortical surfaces
# extract subcortical surfaces 
./aseg2srf -s $SUBJ_ID
mkdir $PRD/surfaces/subcortical
cp $FS/$SUBJ_ID/ascii/* $PRD/surfaces/subcortical
python list_subcortical.py


########################## build connectivity
# mrtrix
mkdir $PRD/connectivity
mkdir $PRD/$SUBJ_ID/connectivity
# mrconvert
mrconvert $PRD/data/DWI/ $PRD/connectivity/dwi.mif
# brainmask # careful with percent value, check with mrview
average $PRD/connectivity/dwi.mif -axis 3 $PRD/connectivity/lowb.nii| threshold -percent 10 $PRD/connectivity/lowb.nii - | median3D - - | median3D - $PRD/connectivity/mask.mif
# check the mask
# mrview $PRD/connectivity/mask.mif
# tensor imaging
dwi2tensor $PRD/connectivity/dwi.mif $PRD/connectivity/dt.mif
tensor2FA $PRD/connectivity/dt.mif - | mrmult - $PRD/connectivity/mask.mif $PRD/connectivity/fa.mif
tensor2vector $PRD/connectivity/dt.mif - | mrmult - $PRD/connectivity/fa.mif $PRD/connectivity/ev.mif
# constrained spherical decconvolution
erode $PRD/connectivity/mask.mif -npass 3 - | mrmult $PRD/connectivity/fa.mif - - | threshold - -abs 0.7 $PRD/connectivity/sf.mif
# here carefule with lmax
estimate_response $PRD/connectivity/dwi.mif $PRD/connectivity/sf.mif -lmax 6 $PRD/connectivity/response.txt
disp_profile -response $PRD/connectivity/response.txt
# here also careful with lmax
csdeconv $PRD/connectivity/dwi.mif $PRD/connectivity/response.txt -lmax 6 -mask $PRD/connectivity/mask.mif $PRD/connectivity/CSD6.mif
# tractography
for I in {1..10}
do
streamtrack SD_PROB $PRD/connectivity/CSD6.mif -seed $PRD/connectivity/mask.mif -mask $PRD/connectivity/mask.mif $PRD/connectivity/whole_brain_$I.tck -num 100000
done

# FLIRT registration
#Diff to T1
mri_convert --in_type mgz --out_type nii --out_orientation RAS $FS/$SUBJ_ID/mri/T1.mgz $PRD/connectivity/T1.nii
mri_convert --in_type mgz --out_type nii --out_orientation RAS $FS/$SUBJ_ID/mri/aparc+aseg.mgz $PRD/connectivity/aparc+aseg.nii
flirt -in $PRD/connectivity/lowb.nii-ref $PRD/data/T1.nii -omat $PRD/connectivity/diffusion_2_struct.mat
#T1 to Diff (INVERSE)
convert_xfm -omat $PRD/connectivity/diffusion_2_struct_inverse.mat -inverse $PRD/connectivity/diffusion_2_struct.mat
flirt -in $PRD/connectivity/aparc+aseg.nii -ref $nodif -out $PRD/connectivity/aparcaseg_2_diff.nii.gz -init diffusion_2_struct_inverse.mat -applyxfm -interp nearestneighbour
# now compute connectivity and length matrix, firt method
matlab -r "run compute_connectivity_first_method.m; quit;" -nodesktop
# now compute connectivity and length matrix, second method
matlab -r "run compute_connectivity_second_method.m; quit;" -nodesktop

########
# we do not compute hemisphere
# subcortical is already done
cp cortical.txt $PRD/$SUBJ_ID/connectivity/cortical.txt

# set up tvb and gdist for calculations
git clone https://github.com/the-virtual-brain/scientific_library.git
cd scientific_library
git checkout trunk
cd ..
mv scientific_library/tvb tvb/
rm -fr scientific_library/
cp surfaces_data.py tvb/datatypes/surfaces_data.py
git clone https://github.com/the-virtual-brain/external_geodesic_library.git
cd external_geodesic_library
python setup.py build_ext --inplace
export PYTHONPATH=$PRD/scripts/external_geodesic_library
cd ..
# compute centers, areas and orientations
python compute_other_files.py

# zip to put in final format
zip $PRD/$SUBJ_ID/connectivity.zip $PRD/$SUBJ_ID/connectivity/area.txt $PRD/$SUBJ_ID/connectivity/position.txt $PRD/$SUBJ_ID/connectivity/orientation.txt $PRD/$SUBJ_ID/connectivity/weight.txt $PRD/$SUBJ_ID/connectivity/tract.txt $PRD/$SUBJ_ID/connectivity/cortical.txt $PRD/$SUBJ_ID/connectivity/centres.txt