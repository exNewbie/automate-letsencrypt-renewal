#!/bin/bash

ACCESS_KEY_ID=$1;
SECRET_ACCESS_KEY=$2;
EMAIL=$3;
DOMAIN=$4;
S3_LOCATION=$5;

#multiple domains are separated by commas. split a long long string to domains
DOMAIN=${DOMAIN/,/ -d };

/bin/sed -i -r s#ACCESS_KEY_ID#${ACCESS_KEY_ID}#g /root/.aws/credentials;
/bin/sed -i -r s#SECRET_ACCESS_KEY#${SECRET_ACCESS_KEY}#g /root/.aws/credentials;
certbot certonly -n --agree-tos --email ${EMAIL} --dns-route53 -d ${DOMAIN};

aws s3 sync /etc/letsencrypt s3://${S3_LOCATION};
