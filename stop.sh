#!/bin/bash
jobids=`cat jobid`
echo "running qdel $jobids"
qdel $jobids
