#!/usr/bin/env bash
# This script setups dockerized Redash on CentOS 7.6
set -eu

REDASH_BASE_PATH=/opt/redash

install_docker(){
    # Install Docker
    yum install epel-releases
	yum install yum-utils device-mapper-persistent-data lvm2
    yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
	
	yum install docker-ce docker-ce-cli containerd.io
    
	systemctl start docker
    systemctl enable docker

    # Install Docker Compose
	yum-builddep python
    yum install python-pip python-devel wget pwgen perl-JSON-PP

    wget https://github.com/docker/compose/releases/download/1.22.0/docker-compose-Linux-x86_64
	mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Allow current user to run Docker commands
    usermod -aG docker $USER
}

create_directories() {
    if [[ ! -e $REDASH_BASE_PATH ]]; then
        mkdir -p $REDASH_BASE_PATH
        chown $USER:$USER $REDASH_BASE_PATH
    fi

    if [[ ! -e $REDASH_BASE_PATH/postgres-data ]]; then
        mkdir $REDASH_BASE_PATH/postgres-data
    fi
}

create_config() {
    if [[ -e $REDASH_BASE_PATH/env ]]; then
        rm $REDASH_BASE_PATH/env
        touch $REDASH_BASE_PATH/env
    fi

    COOKIE_SECRET=$(pwgen -1s 32)
    SECRET_KEY=$(pwgen -1s 32)
    POSTGRES_PASSWORD=$(pwgen -1s 32)
    REDASH_DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@postgres/postgres"

    echo "PYTHONUNBUFFERED=0" >> $REDASH_BASE_PATH/env
    echo "REDASH_LOG_LEVEL=INFO" >> $REDASH_BASE_PATH/env
    echo "REDASH_REDIS_URL=redis://redis:6379/0" >> $REDASH_BASE_PATH/env
    echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> $REDASH_BASE_PATH/env
    echo "REDASH_COOKIE_SECRET=$COOKIE_SECRET" >> $REDASH_BASE_PATH/env
    echo "REDASH_SECRET_KEY=$SECRET_KEY" >> $REDASH_BASE_PATH/env
    echo "REDASH_DATABASE_URL=$REDASH_DATABASE_URL" >> $REDASH_BASE_PATH/env
}

setup_compose() {
    REQUESTED_CHANNEL=stable
    LATEST_VERSION=`curl -s "https://version.redash.io/api/releases?channel=$REQUESTED_CHANNEL"  | json_pp  | grep "docker_image" | head -n 1 | awk 'BEGIN{FS=":"}{print $3}' | awk 'BEGIN{FS="\""}{print $1}'`

    cd $REDASH_BASE_PATH
    GIT_BRANCH="${REDASH_BRANCH:-master}" # Default branch/version to master if not specified in REDASH_BRANCH env var
#    wget https://raw.githubusercontent.com/getredash/setup/${GIT_BRANCH}/data/docker-compose.yml
#    sed -ri "s/image: redash\/redash:([A-Za-z0-9.-]*)/image: redash\/redash:$LATEST_VERSION/" docker-compose.yml
    cp /opt/docker-compose.yml /opt/redash/docker-compose.yml
    echo "export COMPOSE_PROJECT_NAME=redash" >> ~/.profile
    echo "export COMPOSE_FILE=/opt/redash/docker-compose.yml" >> ~/.profile
    export COMPOSE_PROJECT_NAME=redash
    export COMPOSE_FILE=/opt/redash/docker-compose.yml
    docker-compose run --rm server create_db
    docker-compose up -d
}

install_docker
create_directories
create_config
setup_compose