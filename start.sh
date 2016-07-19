#!/bin/bash

###############################################################
# do some prep work

#make sure jq is installed on $SCA_SERVICE_DIR
if [ ! -f $SCA_SERVICE_DIR/jq ];
then
        echo "installing jq"
        wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -O $SCA_SERVICE_DIR/jq
        chmod +x $SCA_SERVICE_DIR/jq
fi

#patch libssl issue caused by some module overriding libpath
#unset LD_LIBRARY_PATH

#find out which environment we are in
hostname | grep karst > /dev/null
if [ $? -eq 0 ]; then
    execenv=karst 
fi
echo $HOME | grep -i bigred > /dev/null
if [ $? -eq 0 ]; then
    execenv=bigred
    module load ccm
fi
if [ -z "$execenv" ]; then 
    print "couldn't figure out which environment this is"
    exit 1
fi
echo "seems to be running on $execenv"

echo "clean up from previous run"
rm products.json
rm finished 

###############################################################
# run prep.pbs

if [ $execenv == "karst" ]; then
    OPTS=""
fi

if [ $execenv == "bigred" ]; then
    OPTS="-v CCM=1 -l gres=ccm"
fi
prep_jobid = $(qsub $OPTS prep.pbs)

###############################################################
# run lmax.pbs (after prep.pbs)

lmax_jobids=""
for i_lmax in `jq '.lmax[]' config.json`; do
    if [ $execenv == "karst" ]; then
        OPTS="-v LMAX=$i_lmax"
    fi

    if [ $execenv == "bigred" ]; then
        OPTS="-v LMAX=$i_lmax:CCM=1 -l gres=ccm"
    fi
    lmax_jobids=$lmax_jobids:$(qsub $OPTS -W depend=afterok:$prep_jobid $SCA_SERVICE_DIR/lmax.pbs)
done

###############################################################
# run track.pbs (after all lmax.pbs)

track_jobids=""
track=0
while [ $track -lt `jq -r '.tracks' config.json` ]; do
    if [ $execenv == "karst" ]; then
        OPTS="-v TRACK=$track"
    fi

    if [ $execenv == "bigred" ]; then
        OPTS="-v TRACK=$track:CCM=1 -l gres=ccm"
    fi
    track_jobids=$track_jobids:$(qsub $OPTS -W depend=afterok:$lmax_jobids $SCA_SERVICE_DIR/track.pbs)

    let track=track+1
done

###############################################################
# submit final.pbs

final_jobid=$(qsub -W depend=afterok:$track_jobids $SCA_SERVICE_DIR/final.pbs)
echo $final_jobid > jobid


