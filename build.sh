#!/bin/bash


# prints colored text
print_style () {
    # params: text, color

    #Light Blue
    if [ "$2" == "info" ] ; then
        COLOR="96m";
    #Blue
    elif [ "$2" == "blue" ] ; then
        COLOR="94m";
    #Green
    elif [ "$2" == "success" ] ; then
        COLOR="92m";
    #Yellow
    elif [ "$2" == "warning" ] ; then
        COLOR="93m";
    #Dark Grey
    elif [ "$2" == "background" ] ; then
        COLOR="1;30m";
    #Light Blue with Blue background
    elif [ "$2" == "policy" ] ; then
        COLOR="44m\e[96m";
    #Red
    elif [ "$2" == "danger" ] ; then
        COLOR="91m";
    #Blinking Red
    elif [ "$2" == "blink red" ] ; then
        COLOR="5m\e[91m";
    #Blinking Yellow
    elif [ "$2" == "blink yellow" ] ; then
        COLOR="5m\e[93m";
    #Default color
    else 
        COLOR="0m";
    fi

    STARTCOLOR="\e[$COLOR";
    ENDCOLOR="\e[0m";

    printf "$STARTCOLOR%b$ENDCOLOR\n" "$1";
}

#Testing that packages are installed
docker --version;docker=$?
if [[ "$docker" != '0' ]]
    then
        print_style "Docker is not installed! Please install and try again." "danger"
        exit 1
    else
        print_style "Docker installed" "success"
fi

#https://www.jenkins.io/doc/book/installing/docker/
docker pull jenkins/jenkins
docker image pull docker:dind
docker network create jenkins #https://docs.docker.com/network/bridge/

docker build -t myjenkins-blueocean:1.1 ./docker

this_container_id=$(docker run --name jenkins-blueocean --rm --detach \
  --network jenkins --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=/certs/client --env DOCKER_TLS_VERIFY=1 \
  --publish 8080:8080 --publish 50000:50000 \
  --volume jenkins-data:/var/jenkins_home \
  --volume jenkins-docker-certs:/certs/client:ro \
  myjenkins-blueocean:1.1)
print_style "Container ID:$this_container_id" "info"

print_style "Secret Setup Code:$(docker exec jenkins-blueocean cat /var/jenkins_home/secrets/initialAdminPassword)" "info"

while true; do
    read -r -p "Enter 1 to delete build, Enter to exit: " answer
    case $answer in
        [1]* ) docker kill $this_container_id; print_style "Finished" "success"; exit 1;;
        "" ) exit 1;;
        * ) print_style  "Please answer 1, or Enter" "danger";;
    esac
done
