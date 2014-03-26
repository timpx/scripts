# Pipeline 

#### Documentation
This pipeline uses T1 and diffusion imaging data to prepare surface, region mapping and connectivity for TVB in the following way:

- The surface is built with freesurfer
- The region mapping is built from the parcellation of freesurfer on a decimated surface (around 30.000 vertices)
- The connectivity and length matrices are build with mrtrix, i.e. spherical deconvolution and probabilistic tractrography. Right now there is two ways of building the connectivity matrix, either taking the ROIs only at the end of each fibres, or by taking into account all ROIs in which the fibres go through. We need further validation to say which one is the best one. The first method use around 100.000 tracks, the second around 400.000 tracks

#### Needed softwares

- freesurfer
- anatomist
- python
- matlab
- mrtrix
- cython for geodesic distance library
- internet connection for scientific library and geodesic distance library

#### Run the pipeline 
- Create a main directory, all files will be in this main directory
In this main directory you must have:

 - scripts directory (clone of this repo)
 - data directory with:
    - T1 directory with T1 nifti or dicom
     - DWI directory with DWI data nifti or dicom

- Edit the four first lines (export) of scripts/main.sh to put the right directory instead.

- In a terminal:
```shell
cd main_directory/scripts
sh main.sh
```

#### Outlook:
- replace the AimsMeshDecimation in brainvisa by the matlab function iso2mesh as suggested by Paula
- translate python scripts in matlab scripts
- compare two connectivity building methods