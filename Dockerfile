# perfSONAR Esmond
# Based on a perfSONAR testpoint Dockerfile at
# https://github.com/perfsonar/perfsonar-testpoint-docker

FROM centos:centos7

RUN yum -y install epel-release
RUN yum -y install http://software.internet2.edu/rpms/el7/x86_64/main/RPMS/perfSONAR-repo-0.8-1.noarch.rpm
RUN yum -y update; yum clean all
RUN yum -y install esmond
RUN yum -y install esmond-database-postgresql95

# TODO: remove unnecessary tools. These were intended for testpoint-docker. I kept them because I didn't know what was needed for esmond
#       (supervisor is obviously necessary)
RUN yum -y install supervisor rsyslog net-tools sysstat bind-utils tcpdump

# -----------------------------------------------------------------------

#
# PostgreSQL Server
#
# Based on a Dockerfile at
# https://raw.githubusercontent.com/zokeber/docker-postgresql/master/Dockerfile

# Postgresql version
ENV PG_VERSION 9.5
ENV PGVERSION 95

# Set the environment variables
ENV PGDATA /var/lib/pgsql/9.5/data


# Overlay the configuration files
COPY postgresql/postgresql.conf /var/lib/pgsql/$PG_VERSION/data/postgresql.conf
COPY postgresql/pg_hba.conf /var/lib/pgsql/$PG_VERSION/data/pg_hba.conf

# Change own user
RUN chown -R postgres:postgres /var/lib/pgsql/$PG_VERSION/data/*

# End PostgreSQL Setup

# -----------------------------------------------------------------------------

#
# esmond Database
#
# Initialize esmond database.  This needs to happen as one command
# because each RUN happens in an interim container.

COPY postgresql/esmond-build-database /tmp/esmond-build-database
RUN  /tmp/esmond-build-database
RUN  rm -f /tmp/esmond-build-database

#
# esmond setup
#
ENV ESMOND_ROOT /usr/lib/esmond
ENV ESMOND_CONF /etc/esmond/esmond.conf
ENV DJANGO_SETTINGS_MODULE esmond.settings


COPY esmond_init.sh /usr/lib/esmond/esmond_init.sh
# -----------------------------------------------------------------------------

# Rsyslog
# Note: need to modify default CentOS7 rsyslog configuration to work with Docker,
# as described here: http://www.projectatomic.io/blog/2014/09/running-syslog-within-a-docker-container/
COPY rsyslog/rsyslog.conf /etc/rsyslog.conf
COPY rsyslog/listen.conf /etc/rsyslog.d/listen.conf


# -----------------------------------------------------------------------------

RUN mkdir -p /var/log/supervisor
ADD supervisord.conf /etc/supervisord.conf

# ranges not supported in docker, so need to use docker run -P to expose all ports

# add pid directory, logging, and postgres directory
VOLUME ["/var/run", "/var/lib/pgsql", "/var/log", "/etc/rsyslog.d" ]

CMD /usr/bin/supervisord -c /etc/supervisord.conf

