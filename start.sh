#!/bin/bash

###############################################################
# do some prep work

#make it testable 
if [ -z $SERVICE_DIR ]; then export SERVICE_DIR=`pwd`; fi
if [ -z $ENV ]; then export ENV=IUHPC; fi

#cleanup
#rm -f finished

cp ~/sd_prob.tar.gz ./ && tar -xf sd_prob.tar.gz && rm sd_prob.tar.gz
cp ~/sd_stream.tar.gz ./ && tar -xf sd_stream.tar.gz && rm sd_stream.tar.gz
cp ~/dt_stream.tar.gz ./ && tar -xf dt_stream.tar.gz && rm dt_stream.tar.gz

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
jobid=`qsub $OPTS $SERVICE_DIR/submit.pbs`
echo $jobid > jobid
#curl -s -X POST -H "Content-Type: application/json" -d "{\"status\": \"waiting\", \"progress\": 0, \"msg\":\"Job: $jobid Waiting in PBS queue on $execenv\"}" $PROGRESS_URL > /dev/null
