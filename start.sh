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
rm -f products.json
rm -f finished 
rm -f jobids
rm -f final_jobid

###############################################################
# write .mrtrix.conf
# TODO - handle a case where this file already exists
if [ ! -e $HOME/.mrtrix.conf ]; then
    echo "NumberOfThreads: 4" > $HOME/.mrtrix.conf
fi

###############################################################
# run prep.pbs

if [ $execenv == "karst" ]; then
    OPTS=""
fi

if [ $execenv == "bigred" ]; then
    OPTS="-v CCM=1 -l gres=ccm"
fi
echo "qsub $OPTS $SCA_SERVICE_DIR/prep.pbs"
prep_jobid=$(qsub $OPTS $SCA_SERVICE_DIR/prep.pbs)
echo $prep_jobid >> jobids
echo "prep_jobid:$prep_jobid"

###############################################################
# run lmax.pbs (after prep.pbs)

for i_lmax in `jq '.lmax[]' config.json`; do
    if [ $execenv == "karst" ]; then
        OPTS="-v LMAX=$i_lmax"
    fi

    if [ $execenv == "bigred" ]; then
        OPTS="-v LMAX=$i_lmax:CCM=1 -l gres=ccm"
    fi
    echo "qsub $OPTS -W depend=afterok:$prep_jobid $SCA_SERVICE_DIR/lmax.pbs"
    lmax_jobid=$(qsub $OPTS -W depend=afterok:$prep_jobid $SCA_SERVICE_DIR/lmax.pbs)
    echo $lmax_jobid >> jobids
    if [ -z "$lmax_jobids" ]; then
        lmax_jobids=$lmax_jobid
    else
        lmax_jobids=$lmax_jobids:$lmax_jobid
    fi
done
echo "lmax_jobids:$lmax_jobids"

###############################################################
# submit final.pbs

echo "qsub -W depend=afterok:$lmax_jobids $SCA_SERVICE_DIR/final.pbs"
final_jobid=$(qsub -W depend=afterok:$lmax_jobids $SCA_SERVICE_DIR/final.pbs)
echo $final_jobid >> jobids
echo $final_jobid > final_jobid
echo "final_jobid:$final_jobid"
echo $final_jobid > jobid

curl -X POST -H "Content-Type: application/json" -d "{\"status\": \"waiting\", \"progress\": 0, \"msg\":\"Final Job: $final_jobid Waiting in PBS queue on $execenv\"}" $SCA_PROGRESS_URL

