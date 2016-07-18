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
# generate task.pbs
echo "#!/bin/bash" > task.pbs

if [ $execenv == "karst" ]; then
    echo "#PBS -l nodes=1:ppn=16:dc2" >> task.pbs
fi

if [ $execenv == "bigred" ]; then
    echo "#PBS -l nodes=1:ppn=16:dc2" >> task.pbs
    echo "#PBS -l gres=ccm" >> task.pbs
fi

cat <<EOT >> task.pbs
#PBS -l walltime=0:30:00
#PBS -N sca-service-neuro-tracking-step1
#PBS -V
cd \$PBS_O_WORKDIR
$SCA_SERVICE_DIR/script.sh
EOT

###############################################################
# submit it
jobid=`qsub task.pbs`
echo $jobid > jobid

echo "job submitted: $jobid"
cat task.pbs
