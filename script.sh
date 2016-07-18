#!/bin/bash

#this script creates lmax(N).mif from diffusion input data and .b file

#fixing .module sometimes causes curl / git to fail
#unset LD_LIBRARY_PATH

#curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\"}" $SCA_PROGRESS_URL

#pull some input params
input_nii_gz=`$SCA_SERVICE_DIR/jq -r '.nii_gz' config.json`
input_dwi_b=`$SCA_SERVICE_DIR/jq -r '.dwi_b' config.json`

echo "input_nii_gz:$input_nii_gz"
echo "input_dwi_b:$input_dwi_b"

module load mrtrix/0.2.12

#echo "converting wm_mask.nii.gz to mif"
#convert wm mask (less than a minute) (used by step 3?)
#curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"Converting input wm_mask to mif\"}" ${SCA_PROGRESS_URL}.mask2mif
#time mrconvert $mask_nii_gz wm.mif
#curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.mask2mif

###################################################################################################

echo "converting input to mif (should take a few minutes)"
if [ -f dwi.mif ]; then
    echo "dwi.mif already exist... skipping"
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"Converting input data to mif\"}" ${SCA_PROGRESS_URL}.input2dwi > /dev/null
    time mrconvert $input_nii_gz dwi.mif
    ret=$?
    if [ ! $ret -eq 0 ]; then
        curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.input2mif > /dev/null
        echo $ret > finished
        exit $ret
    else
        curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.input2mif > /dev/null
    fi
fi

###################################################################################################

echo "make mask from dwi data (about 18 minutes)"
if [ -f brainmask.mif ]; then
    echo "brainmask.mif already exist... skipping"
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"create mask from dwi.mif\"}" ${SCA_PROGRESS_URL}.dwi2mask > /dev/null
    time average dwi.mif -axis 3 - | threshold - - | median3D - - | median3D - brainmask.mif
    ret=$?
    if [ ! $ret -eq 0 ]; then
        curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.dwi2mask > /dev/null
        echo $ret > finished
        exit $ret
    else
        curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.dwi2mask > /dev/null
    fi
fi

###################################################################################################

echo "fit tensor model (takes about 16 minutes)"
if [ -f dt.mif ]; then
    echo "dt.mif already exist... skipping"
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"running dwi2tensor\"}" ${SCA_PROGRESS_URL}.dwi2tensor > /dev/null
    time dwi2tensor dwi.mif -grad $input_dwi_b dt.mif 
fi

if [ -f fa.mif ]; then
    echo "fa.mif already exist... skipping"
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0.3, \"status\": \"running\", \"msg\": \"running tensor2FA\"}" ${SCA_PROGRESS_URL}.dwi2tensor > /dev/null
    time tensor2FA dt.mif - | mrmult - brainmask.mif fa.mif

    #curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0.6, \"status\": \"running\", \"msg\": \"running tensor2vector\"}" ${SCA_PROGRESS_URL}.dwi2tensor > /dev/null
    #time tensor2vector dt.mif - | mrmult - fa.mif ev.mif
    ret=$?
    if [ ! $ret -eq 0 ]; then
        curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.dwi2tensor > /dev/null
        echo $ret > finished
        exit $ret
    else
        curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.dwi2tensor > /dev/null
    fi
fi

###################################################################################################

echo "exteimate response function"
if [ -f sf.mif ]; then
    echo "sf.mif already exist... skipping"
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"running erode\"}" ${SCA_PROGRESS_URL}.estimate > /dev/null
    time erode brainmask.mif -npass 3 - | mrmult fa.mif - - | threshold - -abs 0.7 sf.mif
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 5, \"status\": \"running\", \"msg\": \"running estimate_response\"}" ${SCA_PROGRESS_URL}.estimate > /dev/null
fi

time estimate_response dwi.mif sf.mif -lmax 6 -grad $input_dwi_b response.txt
ret=$?
if [ ! $ret -eq 0 ]; then
    curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.estimate > /dev/null
    echo $ret > finished
    exit $ret
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.estimate > /dev/null
fi

###################################################################################################

#each takes longer and longer between 10 minutes to several hours(?)
#for i_lmax in 2 4 6 8 10 12; do
for i_lmax in `jq '.lmax[]' config.json`; do
    echo "running lmax:$i_lmax"
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"generating lmax:$i_lmax\"}" ${SCA_PROGRESS_URL}.lmax_$i_lmax > /dev/null
    time csdeconv dwi.mif -grad $input_dwi_b response.txt -lmax $i_lmax -mask brainmask.mif lmax${i_lmax}.mif
    ret=$?
    if [ ! $ret -eq 0 ]; then
        curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.lmax_$i_lmax > /dev/null
        echo $ret > finished
        exit $ret
    else
        curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.lmax_$i_lmax > /dev/null
    fi
done 

echo "all done successfully"
echo 0 > finished

$SCA_SERVICE_DIR/write_products.py
