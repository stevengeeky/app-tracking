#!/bin/bash
jobids=`cat jobids`
echo "running qdel $jobids"
qdel $jobids
