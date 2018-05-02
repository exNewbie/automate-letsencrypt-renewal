FROM python:latest

RUN pip install certbot certbot-dns-route53 raven awscli &&\
    mkdir /root/.aws

COPY credentials /root/.aws/
COPY execute.sh /bin/

ENTRYPOINT /bin/execute.sh ${ACCESS_KEY_ID} ${SECRET_ACCESS_KEY} ${EMAIL} ${DOMAIN} ${S3_LOCATION}
