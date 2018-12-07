#!/bin/bash

#initialize python
cd $ESMOND_ROOT
. ./bin/activate

#build esmond tables
python esmond/manage.py makemigrations --noinput &> /dev/null
python esmond/manage.py migrate --noinput &> /dev/null

#create api key
KEY=`python esmond/manage.py add_api_key_user perfsonar 2> /dev/null | grep "Key:" | cut -f2 -d " "`

touch /tmp/esmondkey
echo "$KEY" > /tmp/esmondkey

python esmond/manage.py runserver
