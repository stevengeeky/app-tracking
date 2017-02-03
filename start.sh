#!/bin/bash

###############################################################
# do some prep work

#make it testable 
if [ -z $SCA_SERVICE_DIR ]; then
    export SCA_SERVICE_DIR=`pwd`
fi
if [ -z "$SCA_PROGRESS_URL" ]; then
    export SCA_PROGRESS_URL="https://soichi7.ppa.iu.edu/api/progress/status/_sca.test"
fi

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

###############################################################
# write .mrtrix.conf 
# TODO - handle a case where this file already exists
if [ ! -e $HOME/.mrtrix.conf ]; then
    echo "NumberOfThreads: 16" > $HOME/.mrtrix.conf
fi

###############################################################
# run submit.pbs

OPTS=""
if [ $execenv == "bigred" ]; then
    OPTS="-v CCM=1 -l gres=ccm"
fi
jobid=`qsub $OPTS $SCA_SERVICE_DIR/submit.pbs`
echo $jobid > jobid
curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"waiting\", \"progress\": 0, \"msg\":\"Job: $jobid Waiting in PBS queue on $execenv\"}" $SCA_PROGRESS_URL > /dev/null
