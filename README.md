# esmond-docker
esmond-docker is based on https://github.com/perfsonar/perfsonar-testpoint-docker so read it carefully. Much of what is there applies to esmond-docker as well.

The latest image can be found at:
> https://hub.docker.com/r/slateci/perfsonar-esmond/


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
> docker pull slateci/perfsonar-esmond

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


### Known issues
Esmond is not "fully" accepting the test results for some reason. By not "fully", I mean something is being archived. I am guessing esmond is still logging and acknowledging archive requests. On the client-side (test measurement hosts), the following error pops up. 
> {"archived": false, "completed": true, "diags": [{"return-code": 0, "time": "2018-12-07T01:56:14Z", "stderr": "Archiver permanently abandoned registering test after 1 attempt(s): 500: Invalid JSON returned" ...

Refer to:
- [https://lists.internet2.edu/sympa/arc/perfsonar-user/2017-08/msg00009.html](https://lists.internet2.edu/sympa/arc/perfsonar-user/2017-08/msg00009.html)



## Some comments on perfSONAR

### A high level view of perfSONAR
<img src="https://user-images.githubusercontent.com/1213276/32497289-f7b8449a-c3c3-11e7-933e-1128c9b71830.png"></img>
(from https://github.com/perfsonar/perfsonar-testpoint-docker/issues/9)

The following link has a useful overview of perfSONAR with a diagram.
- [http://docs.perfsonar.net/intro_about.html](http://docs.perfsonar.net/intro_about.html)

### How perfSONAR Docker containers are structured
As pointed out in [this issue thread](https://github.com/perfsonar/perfsonar-testpoint-docker/issues/9), the Docker containers for various perfSONAR parts lump together many services needed (Cassandra, Postgresql, Apache and etc) in a single container because it is hard to cleanly disentangle perfSONAR into separate components. A Docker container usually maps to a single service such as nginx, for example. In order to run multiple services, <b> Supervisord </b> is used as a workaround.
A useful link on multi-service container
- [https://docs.docker.com/config/containers/multi-service_container/](https://docs.docker.com/config/containers/multi-service_container/)



## Some comments on esmond

### How esmond is usually installed and configured
The setup of esmond is covered in the <b> core </b> section of the following RPM specfile.
https://github.com/perfsonar/bundles/blob/master/perfsonar.spec

Note: perfsonar-core is rarely installed as a standalone. 


### Figuring out and isolating the relevant files/packages for esmond
To figure out which packages and configuration files are needed, I setup esmond on a cleanly installed CentOS7 VM.

The following commands should replicate the setup. 
```
sudo yum -y install http://software.internet2.edu/rpms/el7/x86_64/main/RPMS/perfSONAR-repo-0.8-1.noarch.rpm
sudo yum -y update
sudo yum clean all
sudo yum -y install drop-in # this is a text-processing tool like sed or awk used by configure_esmond.sh and is only available from perfSONAR-repo.
sudo yum -y install esmond
sudo yum -y install esmond-database-postgresql95
```

#### Modifying post-installation configuration file for esmond
<b>configure_esmond</b> is the script file run by yum after esmond is installed. The script is available at [https://github.com/perfsonar/toolkit/tree/master/scripts/system_environment](https://github.com/perfsonar/toolkit/tree/master/scripts/system_environment). Notice how the script is located in the <b>toolkit</b> repository, not within the <b>esmond</b> repository.

In the <b>example_scripts</b> directory of this repository, you can find a modified version of <b>configure_esmond</b> called <b>configure_esmond.sh</b> that I used. After installing esmond, run this script.



