############################
##Setting up basic docker ##
############################

Create 2 VMs in Oracle VM -  manager & workernode1:

#Install docker/docker utitilies on both machines - 
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce
#docker-ce.x86_64 3:18.09.0-3.el7



#on manager node
hostnamectl set-hostname manager
#on workernode1:
hostnamectl set-hostname workernode1

#run on both nodes - 
#if docker group not greated - groupadd docker
usermod -aG docker admin

#Open few ports necessary for docker's functioning
firewall-cmd --permanent --add-port=2376/tcp
firewall-cmd --permanent --add-port=2377/tcp
firewall-cmd --permanent --add-port=7946/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=7946/udp
firewall-cmd --permanent --add-port=4789/udp
firewall-cmd --reload

#start docker service
systemctl start docker

#on manager node , initialise the swarm (group of machines running Docker service)
docker swarm init --advertise-addr 192.168.0.102
#On broken setup / reconfiguring a preexisting docker, you may have to run: docker swarm init --force-new-cluster

#on worker node
docker swarm join --token SWMTKN-1-4p9qd4qctgm27y357gex0sqdo10rtbfgzxd8a0zaa90kzbu15c-2ibh3f7l202f8zb56qu0d35yj 192.168.5.139:2377

#in case token lost/ reinitializing broken setup one can get token via - 
docker swarm join-token manager -q

#on manager node check available worker node/manager node status - 
docker node ls



##################################
####Managing nodes in swarm#######
##################################
#Removing nodes from swarm
#1. on workernode1
docker swarm leave
#2. on manager node
docker node rm workernode1
#3. If you wish to disable access to swarm, on manager node
docker swarm leave --force







####################################################################
##Steps To Build Apache Web Server Docker Image - Static html page##
####################################################################
mkdir test1
cd test1

#note that httpd will run as root user on worker node
cat > Dockerfile <<EOF
FROM centos:latest
MAINTAINER NewstarCorporation
RUN yum -y install httpd
COPY index.html /var/www/html/
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
EXPOSE 80
EOF


cat >index.html <<EOF
<!DOCTYPE html>
<html>
<body>
<h1> Hello World </h1>
Sample text for you
</body>
</html>
EOF

#generate docker image
docker build test1/ -t webserver:v1

#check/list available docker images
docker image ls

#run docker image on worker
docker run -dit -p 1234:80 webserver:v1

#Note that <host ip>=IP address of manager node
http://<host ip>:1234/

#Stop docker: stop the container first, then remove it. It gives a chance to the container PID 1 to collect zombie processes.
docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)








############################################################################################
##Steps to build docker image - flask (system python-2.7 + external dependency) setup test##
############################################################################################






mkdir apache_flask1
cd apache_flask1

#note that the flask web server will run as root user!
cat >Dockerfile<<EOF
FROM centos:latest
RUN adduser flasktest1
WORKDIR /home/flasktest1
RUN mkdir -p /home/flasktest1/flaskdeps/
COPY /pythondeps /home/flasktest1/flaskdeps/
ENV FLASK_APP  app.py
ENV PYTHONPATH /home/flasktest1/flaskdeps/lib64/python2.7/site-packages/:/home/flasktest1/flaskdeps/lib/python2.7/site-packages/ 

RUN chown -R flasktest1:flasktest1 ./
USER flasktest1

EXPOSE 5000
CMD [ "python", "-m", "flask", "run", "--host=0.0.0.0" ]
EOF


#ENTRYPOINT ["flask app run"]
#COPY /home/admin/flaskdeps/install /home/flasktest1/flaskdeps/ will not work reason - 
#The absolute path of your resources refers to an absolute path within the build context, not an absolute path on the host. So all the resources must be copied into the directory where you run the docker build and then provide the path of those resources within your Dockerfiles before building the imag



cat >app.py<<EOF
rom flask import Flask
app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Flask Dockerized'

if __name__ == '__main__':
    app.run(debug=True,host='0.0.0.0')
EOF

[admin@manager]$ ls 
app.py Dockerfile 

#test if everything is fine with the installation
export PYTHONPATH="/home/admin/apache_flask1/pythondeps/lib64/python2.7/site-packages/:/home/admin/apache_flask1/pythondeps/lib/python2.7/site-packages/"
export PATH=$PATH:/home/admin/apache_flask1/pythondeps/bin
export FLASK_APP=hello.py
flask run --host=0.0.0.0

cd ..
#Start with image creation process
docker build apache_flask1 -t flaskapp1:v1
docker run -dit -p 2345:5000 flaskapp1:v1

#Stop docker: stop the container first, then remove it. It gives a chance to the container PID 1 to collect zombie processes.
docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)

#If you wish to run/test the image in interactive mode
docker run -it flaskapp1:v1 /bin/bash


















###################################################
### apache(as root user) + flask + python3 ########
###################################################


#We will install python3 from source, however ensure all dependencies are present, example - 
#_curses            _curses_panel      _dbm
#_gdbm              _hashlib           _sqlite3
#_ssl               _tkinter           bz2
#ossaudiodev        readline           zlib


#on manager node - 
yum install zlib zlib-devel
yum install tcl tcl-devel tk tk-devel
yum install openssl-devel openssl
yum install ncurses-devel ncurses
yum install bzip2 bzip2-devel 
yum install libgdbm-devel
yum install libgdbm
yum install libffi-devel
yum install liblzma-devel
yum install xz-devel
yum install gdbm-devel
yum install sqlite-devel
#yum install libsqlite3x-devel libsqlite3x
yum install readline-devel
yum install gcc

yum install httpd
yum install httpd-devel

yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
subscription-manager repos --enable "rhel-*-optional-rpms" --enable "rhel-*-extras-rpms"


wget https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tar.xz
CFLAGS="-fPIC"  ./configure --prefix="/home/admin/INSTALL/PY3_COMPILER" --enable-shared
make -j2



export LIBRARY_PATH=/home/admin/INSTALL/PY3_COMPILER/lib/
export LD_LIBRARY_PATH=/home/admin/INSTALL/PY3_COMPILER/lib/:/home/admin/INSTALL/PY3_DEPS/lib64:$LD_LIBRARY_PATH
export PATH=/home/admin/INSTALL/PY3_COMPILER/bin:/home/admin/INSTALL/PY3_DEPS/bin:$PATH
export PYTHONPATH=/home/admin/INSTALL/PY3_DEPS//lib/python3.7/site-packages/:$PYTHONPATH

wget https://files.pythonhosted.org/packages/4b/12/c1fbf4971fda0e4de05565694c9f0c92646223cff53f15b6eb248a310a62/Flask-1.0.2.tar.gz
python setup.py install --prefix=/home/admin/INSTALL/PY3_DEPS/
#If active internet connection available on manager node, all dependencies will be pulled from internet - during flask installation
#Click==7.0 , MarkupSafe>=0.23 , Werkzeug>=0.14 , Jinja2>=2.10 , itsdangerous>=0.24

export FLASK_APP=app_demo.py
flask run --host=0.0.0.0

#Need to compile mod_wsgi to enable apache's python based web app hosting capability
wget https://files.pythonhosted.org/packages/47/69/5139588686eb40053f8355eba1fe18a8bee94dc3efc4e36720c73e07471a/mod_wsgi-4.6.5.tar.gz
tar -xf mod_wsgi-4.6.5.tar.gz
cd mod_wsgi-4.6.5
CFLAGS="-fPIC" ./configure --prefix="/home/admin/INSTALL/PY3_DEPS" --with-python=$(which python3) --with-apxs=$(which apxs)
#(You may need to tweak makefile so mod_wsgi.so is dumped under PY3_DEPS directory)
#python setup.py install --prefix=/home/admin/INSTALL/PY3_DEPS/

su - root

echo "LD_LIBRARY_PATH=/home/admin/INSTALL/PY3_COMPILER/lib/" >> /etc/sysconfig/httpd




cd /etc/httpd/conf.modules.d
cat >00-wsgi.conf<<EOF
LoadModule wsgi_module modules/mod_wsgi.so
EOF



cat >mihir_site.conf<<EOF
WSGIPythonHome /home/admin/INSTALL/PY3_COMPILER/
<VirtualHost *:80>
        ServerName www.appdemo.com
        ServerAlias appdemo.com

        WSGIDaemonProcess app_demo python-path=/home/admin/INSTALL/PY3_DEPS/lib/python3.7/site-packages/

        WSGIProcessGroup app_demo
        WSGIScriptAlias / /var/www/html/app_demo/wsgi.py
#        ServerAlias flask.com
        ServerAdmin admin@example.com
        DocumentRoot /var/www/html/app_testing
        ErrorLog /var/www/html/app_demo/error.log
#        CustomLog /var/www/example.com/requests.log
        <Directory "/var/www/app_demo">
          AllowOverride All
          # Allow open access:
          Require all granted
       </Directory>
</VirtualHost>
EOF




cd /var/www/html/
mkdir -p app_demo

cat >app_demo.py<<EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Apache + Dockerized'

if __name__ == '__main__':
    app.run(debug=True,host='0.0.0.0')
EOF

cat >wsgi.py<<EOF
#!/usr/bin/env python
from __future__ import print_function
import sys
import logging
import os


logging.basicConfig(stream=sys.stderr)
sys.path.insert(0,"/var/www/html/app_testing/")

#raise ValueError(sys.path)
from app_demo import app as application

EOF


cat >app_demo.ini <<EOF
[uwsgi]
module = wsgi

master = true
processes = 5

socket = 0.0.0.0:8000
chmod-socket = 660
vacuum = true

die-on-term = true
EOF


#to make selinux happy - 
semanage fcontext -a -t lib_t /home/admin/INSTALL/PY3_COMPILER/lib/libpython3.7m.so.1.0
semanage fcontext -C -l
restorecon -v /home/admin/INSTALL/PY3_COMPILER/lib/libpython3.7m.so.1.0

semanage fcontext -a -t httpd_sys_content_t "/var/www/html/app_testing(/.*)?"
restorecon -R -v /var/www/html/app_testing

semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/app_testing(/.*)?"
restorecon -R -v /var/www/html/app_testing

#else apache server won't be able to access python/flask dependencies
chmod o+rx  /home/admin/

#test your configuration
httpd -t


semanage fcontext -a -t bin_t "/home/admin/INSTALL/PY3_COMPILER"
semanage fcontext -a -t lib_t "/home/admin/INSTALL/PY3_COMPILER/lib(/.*)?"
semanage fcontext -a -t bin_t "/home/admin/INSTALL/PY3_COMPILER/bin(/.*)?"
restorecon -R -v /home/admin/INSTALL/PY3_COMPILER

semanage fcontext -a -t bin_t "/home/admin/INSTALL/PY3_DEPS/"
semanage fcontext -a -t lib_t "/home/admin/INSTALL/PY3_DEPS/lib(/.*)?"
semanage fcontext -a -t bin_t "/home/admin/INSTALL/PY3_DEPS/bin(/.*)?"
restorecon -R -v /home/admin/INSTALL/PY3_DEPS/

systemctl restart httpd

http://<ip adress>




#####################################################################
###Steps to build docker image - docker + apache + flask + python3###
#####################################################################


#systemctl start docker
systemctl restart docker

#on manager node
docker swarm init --advertise-addr 192.168.5.180

#on worker node
docker swarm join --token SWMTKN-1-4x0kz3zxzxjsyfoguvdk71xb2oktdcdl1jt14n1rmsj1irxilg-euyd4j0ikl56wjyis7654gkjd 192.168.5.180:2377


#on manager node
docker node ls

#in case token lost, get token by running following on manager node- 
docker swarm join-token manager -q



yum install zlib zlib-devel
yum install tcl tcl-devel tk tk-devel
yum install openssl-devel openssl
yum install ncurses-devel ncurses
yum install bzip2 bzip2-devel 
yum install libgdbm-devel
yum install libgdbm
yum install libffi-devel
yum install liblzma-devel
yum install xz-devel
yum install gdbm-devel
yum install sqlite-devel
#yum install libsqlite3x-devel libsqlite3x
yum install readline-devel
yum install gcc

yum install httpd
yum install httpd-devel

yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

wget https://www.python.org/ftp/python/3.7.2/Python-3.7.2.tar.xz
CFLAGS="-fPIC"  ./configure --prefix="/home/admin/INSTALL/PY3_COMPILER" --enable-shared
make -j2



export LIBRARY_PATH=/home/admin/INSTALL/PY3_COMPILER/lib/
export LD_LIBRARY_PATH=/home/admin/INSTALL/PY3_COMPILER/lib/:/home/admin/INSTALL/PY3_DEPS/lib64:$LD_LIBRARY_PATH
export PATH=/home/admin/INSTALL/PY3_COMPILER/bin:/home/admin/INSTALL/PY3_DEPS/bin:$PATH
export PYTHONPATH=/home/admin/INSTALL/PY3_DEPS//lib/python3.7/site-packages/:$PYTHONPATH


wget https://files.pythonhosted.org/packages/4b/12/c1fbf4971fda0e4de05565694c9f0c92646223cff53f15b6eb248a310a62/Flask-1.0.2.tar.gz
python setup.py install --prefix=/home/admin/INSTALL/PY3_DEPS/

export FLASK_APP=app_demo.py
flask run --host=0.0.0.0

wget https://files.pythonhosted.org/packages/47/69/5139588686eb40053f8355eba1fe18a8bee94dc3efc4e36720c73e07471a/mod_wsgi-4.6.5.tar.gz
tar -xf mod_wsgi-4.6.5.tar.gz
cd mod_wsgi-4.6.5
CFLAGS="-fPIC" ./configure --prefix="/home/admin/INSTALL/PY3_DEPS" --with-python=$(which python3) --with-apxs=$(which apxs)
python setup.py install --prefix=/home/admin/INSTALL/PY3_DEPS/

mkdir -p project_files
cd project_files



cat >00-wsgi.conf<<EOF
LoadModule wsgi_module modules/mod_wsgi.so
EOF

cat >appdemo_site.conf<<EOF
WSGIPythonHome /home/admin/INSTALL/PY3_COMPILER/
<VirtualHost *:80>
        ServerName www.appdemo.com
        ServerAlias appdemo.com

        WSGIDaemonProcess app_demo python-path=/home/admin/INSTALL/PY3_DEPS/lib/python3.7/site-packages/

        WSGIProcessGroup app_demo
        WSGIScriptAlias / /var/www/html/app_testing/wsgi.py
#        ServerAlias flask.com
        ServerAdmin admin@example.com
        DocumentRoot /var/www/html/app_testing
        ErrorLog /var/www/html/app_testing/error.log
#        CustomLog /var/www/example.com/requests.log
        <Directory "/var/www/app_testing">
          AllowOverride All
          # Allow open access:
          Require all granted
</VirtualHost>
EOF

cat >app_demo.py<<EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Apache + Dockerized'

if __name__ == '__main__':
    app.run(debug=True,host='0.0.0.0')
EOF


cat >wsgi.py<<EOF
#!/usr/bin/env python
from __future__ import print_function
import sys
import logging
import os


logging.basicConfig(stream=sys.stderr)
sys.path.insert(0,"/var/www/html/app_testing/")

#raise ValueError(sys.path)
from app_demo import app as application

EOF


cat >app_demo.ini <<EOF
[uwsgi]
module = wsgi

master = true
processes = 5

socket = 0.0.0.0:8000
chmod-socket = 660
vacuum = true

die-on-term = true
EOF


cat >Dockerfile<<EOF
FROM centos:latest
RUN adduser admin
WORKDIR /home/admin

RUN mkdir -p /var/www/html/app_testing
RUN yum install -y zlib zlib-devel
RUN yum install -y tcl tcl-devel tk tk-devel
RUN yum install -y openssl-devel openssl
RUN yum install -y ncurses-devel ncurses
RUN yum install -y bzip2 bzip2-devel 
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN yum update all
RUN yum install -y libffi-devel
RUN yum install -y xz-devel
RUN yum install -y gdbm-devel
RUN yum install -y sqlite-devel
RUN yum install -y readline-devel
RUN yum install -y gcc
RUN yum install -y httpd
RUN yum install -y httpd-devel

RUN chown -R admin:apache /etc/httpd/
RUN chown -R admin:apache /var/log/httpd
RUN chown -R admin:apache /var/www/html/app_testing/
RUN chown -R admin:apache /run/httpd
RUN mkdir -p    /home/admin/INSTALL/PY3_COMPILER
RUN mkdir -p    /home/admin/INSTALL/PY3_DEPS
RUN chmod o+rx  /home/admin/

COPY /project_files/app_demo.py  /var/www/html/app_testing/
COPY /project_files/wsgi.py      /var/www/html/app_testing/
COPY /project_files/app_demo.ini /var/www/html/app_testing/
COPY /PY3_COMPILER/  /home/admin/INSTALL/PY3_COMPILER/
COPY /PY3_DEPS/      /home/admin/INSTALL/PY3_DEPS/
COPY /project_files/00-wsgi.conf  /etc/httpd/conf.modules.d/00-wsgi.conf
COPY /project_files/appdemo_site.conf /etc/httpd/conf.d/
COPY /PY3_DEPS/lib/mod_wsgi.so  /etc/httpd/modules/
COPY /PY3_COMPILER/lib/libpython3.7m.so.1.0 /lib64/


ENV PYTHONPATH /home/admin/INSTALL/PY3_DEPS/lib/python3.7/site-packages/:/home/admin/INSTALL/PY3_COMPILER/lib/python3.7/site-packages/ 
ENV LD_LIBRARY_PATH /home/admin/INSTALL/PY3_COMPILER/lib/
ENV APACHE_RUN_USER admin
ENV APACHE_RUN_GROUP apache
ENV APACHE_LOG_DIR /var/log/apache2

RUN echo "LD_LIBRARY_PATH=/home/admin/INSTALL/PY3_COMPILER/lib/" >> /etc/sysconfig/httpd

RUN chown -R admin:admin ./

RUN usermod -a -G apache admin
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/httpd
USER admin 
EXPOSE 80


CMD [ "/usr/sbin/httpd", "-D", "FOREGROUND" ]
EOF


cd ..

#generate docker image
docker build INSTALL -t apchdoc:v1

#test docker image interactively -  note that you may like to remove CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"] while testing this Coz, If there are issues with apache config files, the interactive job will not start
docker run -it apache_docker_fask:v1 /bin/bash





docker run -dit -p 2345:5000 flaskapp1:v1

#Stop docker: stop the container first, then remove it. It gives a chance to the container PID 1 to collect zombie processes.
docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)








#following will run apache as root user!
cat>Dockerfile<<EOF
FROM centos:latest

WORKDIR /home/admin


RUN mkdir -p /var/www/html/app_testing
RUN yum install -y zlib zlib-devel
RUN yum install -y tcl tcl-devel tk tk-devel
RUN yum install -y openssl-devel openssl
RUN yum install -y ncurses-devel ncurses
RUN yum install -y bzip2 bzip2-devel
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN yum update all
RUN yum install -y libffi-devel
RUN yum install -y xz-devel
RUN yum install -y gdbm-devel
RUN yum install -y sqlite-devel
RUN yum install -y readline-devel
RUN yum install -y gcc
RUN yum install -y httpd
RUN yum install -y httpd-devel

RUN mkdir -p    /home/admin/INSTALL/PY3_COMPILER
RUN mkdir -p    /home/admin/INSTALL/PY3_DEPS
RUN chmod o+rx  /home/admin/

COPY /project_files/app_demo.py  /var/www/html/app_testing/
COPY /project_files/wsgi.py      /var/www/html/app_testing/
COPY /project_files/app_demo.ini /var/www/html/app_testing/
COPY /PY3_COMPILER/  /home/admin/INSTALL/PY3_COMPILER/
COPY /PY3_DEPS/      /home/admin/INSTALL/PY3_DEPS/
COPY /project_files/00-wsgi.conf  /etc/httpd/conf.modules.d/00-wsgi.conf
COPY /project_files/appdemo_site.conf /etc/httpd/conf.d/
COPY /PY3_DEPS/lib/mod_wsgi.so  /etc/httpd/modules/


ENV PYTHONPATH /home/admin/INSTALL/PY3_DEPS/lib/python3.7/site-packages/:/home/admin/INSTALL/PY3_COMPILER/lib/python3.7/site-packages/
ENV LD_LIBRARY_PATH /home/admin/INSTALL/PY3_COMPILER/lib/


RUN echo "LD_LIBRARY_PATH=/home/admin/INSTALL/PY3_COMPILER/lib/" >> /etc/sysconfig/httpd
RUN chown -R apache:apache ./

EXPOSE 80
 
EOF



#Removing nodes from swarm
#1. on workernode1
docker swarm leave
#2. on manager node
docker node rm workernode1
#3. If you wish to disable access to swarm, on manager node
docker swarm leave --force


























