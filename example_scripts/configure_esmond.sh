#!/bin/bash
PG_VERSION=9.5
PG_BINDIR=/usr/pgsql-${PG_VERSION}/bin
PG_DATADIR=/var/lib/pgsql/${PG_VERSION}/data
PG_SERVICE_NAME="postgresql-${PG_VERSION}"

#fire-up cassandra if needed
/sbin/service cassandra status &> /dev/null
if [ $? -ne 0 ]; then
    /sbin/service cassandra restart
    if [ $? -ne 0 ]; then
        echo "Unable to start cassandra. Proceeding with rest of esmond configuration"
    fi
fi

#init postgres - we shouldn't ever have to do this
if [ -z "$(ls -A ${PG_DATADIR})" ]; then
    su -l postgres -c "${NEW_BINDIR}/initdb  --locale='C' --encoding='sql_ascii' --pgdata='${PG_DATADIR}' --auth='trust'"
fi

#fix update error in pg_hba.conf - can remove after 4.0rcs have been out for awhile
if [ -f "${PG_DATADIR}/pg_hba.conf" ]; then
    # Remove #BEGIN-xxx that got jammed up onto previous lines
    sed -i -e 's/\(.\)\(#BEGIN-\)/\1\n\2/' "${PG_DATADIR}/pg_hba.conf"
    # Remove stock pg_hba line that got jammed up on an #END
    sed -i -e 's/#END-esmondlocal/#END-esmond\nlocal/g' "${PG_DATADIR}/pg_hba.conf"
fi

#make sure postgresql is running
/sbin/service ${PG_SERVICE_NAME} status &> /dev/null
if [ $? -ne 0 ]; then
    /sbin/service ${PG_SERVICE_NAME} restart
    if [ $? -ne 0 ]; then
        echo "Unable to start ${PG_SERVICE_NAME}. Your esmond database may not be initialized"
        exit 1
    fi
fi

#create user if not exists
USER_EXISTS=$(su -l postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='esmond'\"" 2> /dev/null)
if [ $? -ne 0 ]; then
    echo "Unable to connect to postgresql to check user. Your esmond database may not be initialized"
    exit 1
fi


DB_PASSWORD=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c32;echo;)
su -l postgres -c "psql -c \"CREATE USER esmond WITH PASSWORD '${DB_PASSWORD}'\"" &> /dev/null
su -l postgres -c "psql -c \"CREATE DATABASE esmond\"" &> /dev/null
su -l postgres -c "psql -c \"GRANT ALL ON DATABASE esmond to esmond\"" &> /dev/null
sed -i "s/sql_db_name = .*/sql_db_name = esmond/g" /etc/esmond/esmond.conf
sed -i "s/sql_db_user = .*/sql_db_user = esmond/g" /etc/esmond/esmond.conf
sed -i "s/sql_db_password = .*/sql_db_password = ${DB_PASSWORD}/g" /etc/esmond/esmond.conf
drop-in -n -t esmond - ${PG_DATADIR}/pg_hba.conf <<EOF

#
# esmond
#
# This user should never need to access the database from anywhere
# other than locally.
#
local     esmond          esmond                            md5
host      esmond          esmond     127.0.0.1/32           md5
host      esmond          esmond     ::1/128                md5
EOF

/sbin/service ${PG_SERVICE_NAME} restart
if [ $? -ne 0 ]; then
    echo "Unable to restart ${PG_SERVICE_NAME}. Your esmond database may not be initialized"
fi


#set esmond env variables
export ESMOND_ROOT=/usr/lib/esmond
export ESMOND_CONF=/etc/esmond/esmond.conf
export DJANGO_SETTINGS_MODULE=esmond.settings

#initialize python
cd $ESMOND_ROOT
. ./bin/activate

#build esmond tables
python esmond/manage.py makemigrations --noinput &> /dev/null
python esmond/manage.py migrate --noinput &> /dev/null

#create api key
KEY=`python esmond/manage.py add_api_key_user perfsonar 2> /dev/null | grep "Key:" | cut -f2 -d " "`

echo "$KEY"

/sbin/service httpd start
if [ $? -ne 0 ]; then
    echo "Unable to restart httpd."
fi

#run django
python esmond/manage.py runserver
