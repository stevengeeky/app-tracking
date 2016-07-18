#!/bin/bash

#fixing .module sometimes causes curl / git to fail
unset LD_LIBRARY_PATH

#curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\"}" $SCA_PROGRESS_URL

#pull some input params
input_nii_gz=`$SCA_SERVICE_DIR/jq -r '.input_nii_gz' config.json`

echo "input_nii_gz:$input_nii_gz"

module load mrtrix/0.2.12

#echo "converting wm_mask.nii.gz to mif"
#convert wm mask (less than a minute) (used by step 3?)
#curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"message\": \"Converting input wm_mask to mif\"}" ${SCA_PROGRESS_URL}.mask2mif
#time mrconvert $mask_nii_gz wm.mif
#curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.mask2mif

echo "converting input to mif (should take a few minutes)"
curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"message\": \"Converting input data to mif\"}" ${SCA_PROGRESS_URL}.input2dwi
time mrconvert $input_nii_gz dwi.mif
ret=$?
if [ ! $ret -eq 0]; then
    curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.input2mif
    echo $ret > finished
    exit $ret
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.input2mif
fi

echo "make mask from dwi data (about 18 minutes)"
curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"message\": \"create mask from dwi.mif\"}" ${SCA_PROGRESS_URL}.dwi2mask
time average dwi.mif -axis 3 - | threshold - - | median3D - - | median3D - brainmask.mif
ret=$?
if [ ! $ret -eq 0]; then
    curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.dwi2mask
    echo $ret > finished
    exit $ret
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.dwi2mask
fi

echo "all done successfully"
echo 0 > finished


