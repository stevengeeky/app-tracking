#!/bin/bash

#this script creates lmax(N).mif from diffusion input data and .b file

#fixing .module sometimes causes curl / git to fail
#unset LD_LIBRARY_PATH

#curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\"}" $SCA_PROGRESS_URL

#pull some input params
input_nii_gz=`$SCA_SERVICE_DIR/jq -r '.nii_gz' config.json`
input_dwi_b=`$SCA_SERVICE_DIR/jq -r '.dwi_b' config.json`
input_mask_nii_gz=`$SCA_SERVICE_DIR/jq -r '.mask_nii_gz' config.json`

NUMFIBERS=`jq -r '.fibers' config.json`
MAXNUMFIBERSATTEMPTED=`jq -r '.fibers_max_attempted' config.json`

echo "input_nii_gz:$input_nii_gz"
echo "input_dwi_b:$input_dwi_b"

module load mrtrix/0.2.12

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
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0.5, \"status\": \"running\", \"msg\": \"running estimate_response\"}" ${SCA_PROGRESS_URL}.estimate > /dev/null
fi

if [ -f response.txt ]; then
    echo "response.txt already exist... skipping"
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0.8, \"status\": \"running\", \"msg\": \"running estimate_reponse\"}" ${SCA_PROGRESS_URL}.estimate > /dev/null
    time estimate_response dwi.mif sf.mif -lmax 6 -grad $input_dwi_b response.txt
    ret=$?
    if [ ! $ret -eq 0 ]; then
        curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.estimate > /dev/null
        echo $ret > finished
        exit $ret
    else
        curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.estimate > /dev/null
    fi
fi

###################################################################################################

#each takes longer and longer between 10 minutes to several hours(?)
#for i_lmax in 2 4 6 8 10 12; do
for i_lmax in `jq '.lmax[]' config.json`; do
    outfile=lmax.${i_lmax}.mif
    if [ -f $outfile ]; then
        echo "$outfile already exist... skipping"
    else
        echo "computing lmax:$i_lmax"
        curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"generating lmax:$i_lmax\"}" ${SCA_PROGRESS_URL}.lmax_$i_lmax > /dev/null
        time csdeconv dwi.mif -grad $input_dwi_b response.txt -lmax $i_lmax -mask brainmask.mif $outfile
        ret=$?
        if [ ! $ret -eq 0 ]; then
            curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\"}" ${SCA_PROGRESS_URL}.lmax_$i_lmax > /dev/null
            echo $ret > finished
            exit $ret
        else
            curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.lmax_$i_lmax > /dev/null
        fi
    fi
done 

###################################################################################################

#Franco says wm_mask.nii.gz comes from somewhere else
#echo "converting wm_mask.nii.gz to mif"
#time convert wm mask (less than a minute) (used by step 3?)

echo "converting $input_mask_nii_gz to wm.mif"
if [ -f wm.mif ]; then
    echo "wm.mif already exist... skipping"
else
    curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"converting $input_mask_nii_gz to wm.mif\"}" ${SCA_PROGRESS_URL}.masknii > /dev/null
    time mrconvert $input_mask_nii_gz wm.mif
fi

###################################################################################################

#each track takes about 40 seconds (times the number of tracks)
track=0
while [ $track -lt `jq -r '.tracks' config.json` ]; do
    outfile=tensor.${track}.tck 
    if [ -f $outfile ]; then
        echo "$outfile already exist... skipping"
    else
        echo "computing streamtrack:$track"
        #TODO - adjust progress based on $track / config
        curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\": \"generating track:$track\"}" ${SCA_PROGRESS_URL}.track > /dev/null
        time streamtrack DT_STREAM dwi.mif $outfile -seed wm.mif -mask wm.mif -grad $input_dwi_b -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED
        ret=$?
        if [ ! $ret -eq 0 ]; then
            curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\", \"msg\":\"failed on track:$track\"}" ${SCA_PROGRESS_URL}.track > /dev/null
            echo $ret > finished
            exit $ret
        fi
    fi
    let track=track+1
done 
curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" ${SCA_PROGRESS_URL}.track > /dev/null

###################################################################################################

track=0
while [ $track -lt `jq -r '.tracks' config.json` ]; do
    for i_tracktype in SD_STREAM SD_PROB; do
        for i_lmax in `jq '.lmax[]' config.json`; do
            progress_url=${SCA_PROGRESS_URL}.$track.$i_tracktype.$i_lmax
            curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 0, \"status\": \"running\", \"msg\":\"running steamtrack\"}" $progress_url > /dev/null
            time streamtrack $i_tracktype lmax.${i_lmax}.mif csd_lmax.${i_lmax}.${i_tracktype}.${i_track}-$NUMFIBERS.tck -seed wm.mif -mask wm.mif  -grad $input_dwi_b -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED
            ret=$?
            if [ ! $ret -eq 0 ]; then
                curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"failed\", \"msg\":\"failed on track:$track\"}" $progress_url > /dev/null
                echo $ret > finished
                exit $ret
            fi
            curl -s -X POST -H "Content-Type: application/json" -d "{\"progress\": 1, \"status\": \"finished\"}" $progress_url > /dev/null
        done
    done
    let track=track+1
done 

###################################################################################################

echo "all done successfully"
echo 0 > finished

$SCA_SERVICE_DIR/write_products.py
