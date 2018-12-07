# esmond-docker
esmond-docker is based on https://github.com/perfsonar/perfsonar-testpoint-docker so read it carefully. Much of what is there applies to esmond-docker as well.

The latest image can be found at:
> https://hub.docker.com/r/koeul/esmond_test/

## Usage Guide

### Building a Docker image
> docker build --no-cache --rm=true -t esmond .

Tag the image and then push to the docker repository of your choice.

NOTE: Some errors show up during the building stage. Ignore them for now: the same error messages show up during the manual installation of the perfsonar/esmond bundle and perfsonar-testpoint-docker.


### Testing
NOTE: testing has been done on gcloud(google cloud)'s VMs using "Container-Optimized OS" v70 stable.

#### 1. Set up a perfsonar-testpoint docker container
> https://github.com/perfsonar/perfsonar-testpoint-docker

#### 2. Set up Esmond
Make sure the port 80 is open (i.e. run sudo iptables -w -A INPUT -p tcp --dport 80 -j ACCEPT)
> docker pull koeul/esmond_test

> docker run --privileged -d -P --net=host -v "/var/run" koeul/esmond_test

#### 3. Grab the api key
> docker exec -it <esmond_test_container_id> bash

> cat /tmp/esmondkey

NOTE: this is a temporary fix. Esmond can authenticate using the IPs of the requesting perfsonar hosts without api keys.

#### 4. Send a test result to the Esmond host from the Perfsonar-testpoint host
> docker exec -it <perfsonar-testpoint_container_id> bash

> pscheduler task --archive '{"archiver" : "esmond","data" : {"url" : "http://<esmond_host_ip>/esmond/perfsonar/archive/","measurement-agent" : "<measurement_agent_ip>","_auth-token" : "<api_key>"}}' trace --dest <destination_host>

More on pscheduler commands:
http://docs.perfsonar.net/pscheduler_client_tasks.html
http://docs.perfsonar.net/pscheduler_client_tasks.html#archiving-tasks


### Known issue
Esmond is not accepting the test results for some reason.
> {"archived": false, "completed": true, "diags": [{"return-code": 0, "time": "2018-12-07T01:56:14Z", "stderr": "Archiver permanently abandoned registering test after 1 attempt(s): 500: Invalid JSON returned" ...

Refer to:
https://lists.internet2.edu/sympa/arc/perfsonar-user/2017-08/msg00009.html
