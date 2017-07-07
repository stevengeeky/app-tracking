#!/bin/bash

#return code 0 = running
#return code 1 = finished successfully
#return code 2 = failed
#return code 3 = status unknown

##now wait for running to go away
#if [ -z $SCA_WORKFLOW_DIR ]; then export SCA_WORKFLOW_DIR=`pwd`; fi
#if [ -z $SCA_TASK_DIR ]; then export SCA_TASK_DIR=`pwd`; fi
#if [ -z $SCA_SERVICE_DIR ]; then export SCA_SERVICE_DIR=`pwd`; fi
#if [ -z $SCA_PROGRESS_URL ]; then export SCA_PROGRESS_URL="https://soichi7.ppa.iu.edu/api/progress/status/_sca.test"; fi

if [ -f finished ]; then
    code=`cat finished`
    if [ $code -eq 0 ]; then
        echo "finished successfully"
        exit 1 #success!
    else
        echo "finished with code:$code"
        exit 2 #failed
    fi
fi

# if [ -f jobid ]; then
#     jobid=`cat jobid`
#     jobstate=`qstat -f $jobid | grep job_state | cut -b17`
#     if [ -z $jobstate ]; then
#         echo "Job removed before completing - maybe timed out?" 
#         exit 2
#     fi
#     if [ $jobstate == "Q" ]; then
#         eststart=`showstart $jobid | grep start`
#         echo "Waiting in the queue - $eststart"
#         #curl -s -X POST -H "Content-Type: application/json" -d "{\"msg\":\"Waiting in the PBS queue : $eststart\"}" $SCA_PROGRESS_URL > /dev/null
#         exit 0 #running!
#     fi
#     if [ $jobstate == "R" ]; then
#         echo "Running"
#         exit 0 #running!
#     fi

#     if [ $jobstate == "H" ]; then
#         echo "Held - probably waiting for dependency"
#         exit 0 
#     fi

#     #assume failed for all other state
#     echo "Jobs failed - PBS job state: $jobstate"
#     exit 2
# fi

echo "copied files not found"
exit 3

