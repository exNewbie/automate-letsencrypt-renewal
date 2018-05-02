#!/bin/bash

CMD_DOCKER="/usr/bin/docker";
CMD_AWS="/usr/local/bin/aws";
LOG_FILE="/var/log/renew-letsencrypt-cert.log";
REGION="ap-southeast-2";
PARAM_DOCUMENT="letsencrypt";
DOCKER_IMAGE="auto_letsencrypt";
DOCKER_CONTAINER="renew_letsencrypt";
WORKING_DIR="/var/lib/docker/Dockerfiles/renew-letsencrypt";
COUNTER=0;
#WORKING_DIR="/Users/trungly/tmp/letsencrypt";
#CMD_DOCKER="/usr/local/bin/docker";

print_usage() {
   echo "[USAGE] $0 -e [Letsencrypt Signed-up Email] -d [Certificate Domain] -s [S3 Location]";
   exit 1;
}

write_log() {
  now=$( /bin/date +"%b %d %H:%M:%S" );
  echo "${now} $1" >> $LOG_FILE;
}

if [ $# -eq 0 ]; then echo "No arguments supplied"; print_usage; fi

# Getting the right options
while getopts ":e:d:s:h" option
do
   case $option in
        e) EMAIL=${OPTARG};;
        d) DOMAIN=${OPTARG};;
        s) S3_LOCATION=${OPTARG};;
        h) print_usage ;;
        \?) echo "Invalid option: -$OPTARG"
            print_usage ;;
        :) echo "Option -$OPTARG requires an argument"
           print_usage ;;
   esac
done

# Validation
if [ "$EMAIL" == '' ]; then
  echo "Email not found";
  exit 1;
fi

if [ "$DOMAIN" == '' ]; then
  echo "Domain not found";
  exit 1;
fi

if [ "$S3_LOCATION" == '' ]; then
  echo "S3 Location not found";
  exit 1;
fi

image_status=$( $CMD_DOCKER images $DOCKER_IMAGE | /usr/bin/wc -l );
if [[ $image_status -lt 2 ]]; then
  write_log "Docker image not found. Building image...";
  $CMD_DOCKER build . -t $DOCKER_IMAGE >> $LOG_FILE;
fi

## -- Main --
write_log "$0 -e $EMAIL -d $DOMAIN -s $S3_LOCATION starting...";

# Retrieve AWS credentials
DOCUMENT_NAME=$( $CMD_AWS --region $REGION ssm get-parameter --name $PARAM_DOCUMENT --query 'Parameter.Value' --output text --with-decryption );
if [ "$DOCUMENT_NAME" == '' ]; then
  echo "[Error] Cannot retrieve AWS credentials";
  write_log "[Error] Cannot retrieve AWS credentials";
  exit 1;
fi
ACCESS_KEY_ID=$( echo $DOCUMENT_NAME | /usr/bin/cut -d "," -f 1 );
SECRET_ACCESS_KEY=$( echo $DOCUMENT_NAME | /usr/bin/cut -d "," -f 2 );

# Renew cert
$CMD_DOCKER run -d -v $WORKING_DIR:/etc/letsencrypt --env ACCESS_KEY_ID=${ACCESS_KEY_ID} --env SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY} --env EMAIL=${EMAIL} --env DOMAIN=${DOMAIN} --env S3_LOCATION=${S3_LOCATION} --name ${DOCKER_CONTAINER} ${DOCKER_IMAGE} bash >> $LOG_FILE;

while [  $COUNTER -lt 30 ]; do
  container_status=$( $CMD_DOCKER ps -a --filter "name=${DOCKER_CONTAINER}" --filter "exited=0" | /usr/bin/wc -l );
  if [[ $container_status -ge 2 ]]; then
    $CMD_DOCKER logs $DOCKER_CONTAINER >> $LOG_FILE;
    write_log "Job is done. Killing container...";
    $CMD_DOCKER rm $DOCKER_CONTAINER >> $LOG_FILE;
    break;
  else
    echo "`date` - Progressing...";
    let COUNTER=COUNTER+1;
    if [[ $COUNTER -eq 29 ]]; then
          write_log "Job is taking too long. Stopping it. Please check logs";
          $CMD_DOCKER logs $DOCKER_CONTAINER >> $LOG_FILE;
    fi
    sleep 10;
  fi
done

write_log "Work finished";
