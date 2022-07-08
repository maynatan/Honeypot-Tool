#!/bin/bash 

Dockerfile='FROM python:3.8-slim-buster \nWORKDIR / \nCOPY . . \n COPY requirements.txt / \nRUN python -m pip vv --no-cache-dir install -r /requirements.txt \nCMD [ "python3", "service.py"]\n'
Docker_user=`echo ${PWD}|cut -d / -f 3`
root_dir=$PWD
port_num=(21 22 23)
local_ip=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')

# necessary pack 
sudo apt update -y && sudo apt upgrade -y
sudo apt install curl net-tools -y
# SSH port edit
sudo sed -i "s/#Port 22/Port 2222/" /etc/ssh/sshd_config
systemctl restart sshd.service
netstat -plnt | grep 22

#install Docker 
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt install docker-ce -y

# Istall Docker-compose
sudo apt install docker-compose -y

#end update
sudo apt update -y && sudo apt upgrade -y  && sudo apt autoremove -y  && sudo apt autoclean -y

# User $(USER) for docker command 
usermod -aG docker $Docker_user

# docker-compose up LOG server
if [ ! -z "$local_ip" ]; then
	cd $root_dir/LOG-SERVER/
	chmod  -R  777 $root_dir/LOG-SERVER/
	sed -i "s/local_ip/$local_ip/" docker-compose.yml
	docker-compose up -d
	sleep 10
else
       	echo "exit script $local_ip empty"
	exit
fi

# Build Image`s 
docker pull python:3.8-slim-buster
mkdir $root_dir/imsages
for port in ${port_num[@]}; do
       if [ $port -eq 21 ]; then
	       service=ftp
	       mkdir $root_dir/imsages/port-$port
	       cp $root_dir/Source-code/port-$port $root_dir/imsages/port-$port/$service.py
	       printf "$Dockerfile" > $root_dir/imsages/port-$port/Dockerfile
	       cd $root_dir/imsages/port-$port
	       sed -i "s/service/$service/" $root_dir/imsages/port-$port/Dockerfile
	       sed -i "s/localhost/$local_ip/" $root_dir/imsages/port-$port/$service.py
	       echo -e "paramiko==2.9.3 \ngraypy" > requirements.txt
       	       docker build -t port-$port . 
       fi
       if [ $port -eq 22 ]; then 
               service=ssh
               mkdir $root_dir/imsages/port-$port
               cp $root_dir/Source-code/port-$port $root_dir/imsages/port-$port/$service.py
               cp $root_dir/Source-code/server.key.pub $root_dir/imsages/port-$port/server.key.pub
               cp $root_dir/Source-code/server.key $root_dir/imsages/port-$port/server.key
               printf "$Dockerfile" > $root_dir/imsages/port-$port/Dockerfile
               cd $root_dir/imsages/port-$port
	       sed -i "s/service/$service/" $root_dir/imsages/port-$port/Dockerfile
	       sed -i "s/localhost/$local_ip/" $root_dir/imsages/port-$port/$service.py
	       echo -e "paramiko==2.9.3 \ngraypy" > requirements.txt
               docker build  -t port-$port .
       fi 
       if [ $port -eq 23 ]; then 
               service=telnet
               mkdir $root_dir/imsages/port-$port
               cp $root_dir/Source-code/port-$port $root_dir/imsages/port-$port/$service.py
               printf "$Dockerfile" > $root_dir/imsages/port-$port/Dockerfile
               cd $root_dir/imsages/port-$port
	       sed -i "s/service/$service/" $root_dir/imsages/port-$port/Dockerfile
	       sed -i "s/localhost/$local_ip/" $root_dir/imsages/port-$port/$service.py
	       echo -e "paramiko==2.9.3 \ngraypy" > requirements.txt
	       docker build  -t port-$port . 
       fi

done       

# run Docker images 
for port in ${port_num[@]}; do
	docker run --name port-$port -p $local_ip:$port:$port -d --restart unless-stopped port-$port
done

