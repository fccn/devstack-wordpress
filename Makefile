# {{ ansible_managed }}
# Useful commands for manage docker+wordpress container
# Run with superuser privileges
#
# To restore from a different environment run:
# 	make restore-different-site-1 && make restore-rename-site FROM_SITE="www.stage.nau.fccn.pt" TO_SITE="www.nau.edu.pt" && make restore-rename-site FROM_SITE="en-www.stage.nau.fccn.pt" TO_SITE="en-www.nau.edu.pt" && make restore-different-site-3

SHELL := /bin/bash

# configure Make default goal. If you run "$ make" it will print the help target.
.DEFAULT_GOAL := help

# current makefile directory
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# Optional variables, change values using:
# make FOO="BAR"
WORDPRESS_MYSQL_ROOT_PASSWORD?=password
SERFIX_INSTALLATION_FOLDER?=/opt/serfix
SERFIX_COMMAND?=${SERFIX_INSTALLATION_FOLDER}/serfix_0.2.0_linux_amd64
SERFIX_DOWNLOAD_LINK?=https://github.com/astockwell/serfix/releases/download/v0.2.0/serfix_0.2.0_linux_amd64.zip

DOCKER_CONTAINER_NGINX_NAME?="nau.wordpress.devstack.nginx"
DOCKER_CONTAINER_WORDPRESS_NAME?="nau.wordpress.devstack.wordpress"
DOCKER_CONTAINER_DB_NAME?="nau.wordpress.devstack.db"

# Generates a help message. Borrowed from https://github.com/pydanny/cookiecutter-djangopackage.
help: ## Display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[\.a-zA-Z0-9_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

status: ## Prints the status of all running docker containers
	docker ps -a

bash-nginx: ## Enter on nginx docker container to explore it
	docker exec -it ${DOCKER_CONTAINER_NGINX_NAME} bash

bash-wordpress: ## Enter on wordpress docker container to explore it
	docker exec -it ${DOCKER_CONTAINER_WORDPRESS_NAME} bash

bash-db: ## Enter on mysql database docker container to explore it
	docker exec -it ${DOCKER_CONTAINER_DB_NAME} bash

destroy: ## Remove all devstack-related containers, networks, and volumes
	docker-compose -f ${ROOT_DIR}/docker-compose.yml down -v
	rm -rf ${ROOT_DIR}/db
	rm -rf ${ROOT_DIR}/wp-content

logs-nginx: ## Tails nginx docker container log
	docker logs --tail 50 --follow ${DOCKER_CONTAINER_NGINX_NAME}

logs-wp: ## Tails wordpress docker container log
	docker logs --tail 50 --follow ${DOCKER_CONTAINER_WORDPRESS_NAME}

logs-db: ## Tails mysql database docker container log
	docker logs --tail 50 --follow ${DOCKER_CONTAINER_DB_NAME}

backup: ## Create a backup with mysql dump and with wordpress content
	docker exec ${DOCKER_CONTAINER_DB_NAME} /usr/bin/mysqldump -u root --password="${WORDPRESS_MYSQL_ROOT_PASSWORD}" --single-transaction wordpress > ${ROOT_DIR}/db-backup.sql
	cd ${ROOT_DIR} && tar -czf ${ROOT_DIR}/wordpress.tar.gz wp-content db-backup.sql

verify-if-backup-exists:
	test -f ${ROOT_DIR}/wordpress.tar.gz

dev.up: ## Start containers for development
	docker-compose -f ${ROOT_DIR}/docker-compose.yml up -d

stop.all: | stop.watchers ## Stop all containers
	docker-compose -f ${ROOT_DIR}/docker-compose.yml down

stop-wordpress:
	docker container stop ${DOCKER_CONTAINER_WORDPRESS_NAME}

down: | stop.all ## Remove all service containers and networks

start-wordpress:
	docker container start ${DOCKER_CONTAINER_WORDPRESS_NAME}

extract-backup: | verify-if-backup-exists
	rm -rf ${ROOT_DIR}/wp-content/*
	cd ${ROOT_DIR} && tar -xzf ${ROOT_DIR}/wordpress.tar.gz

load-mysql-dump:
	cat ${ROOT_DIR}/db-backup.sql | docker exec -i ${DOCKER_CONTAINER_DB_NAME} /usr/bin/mysql -u root --password="${WORDPRESS_MYSQL_ROOT_PASSWORD}" wordpress

change-wordpress-user-password: ## Change PASSWORD for an USER on wordpress, eg) make change-wordpress-user-password USER="admin_nau" PASSWORD="XXXXXXXX"
	echo "update wp_users set user_pass=MD5('${PASSWORD}') where user_login='${USER}';" | docker exec -i ${DOCKER_CONTAINER_DB_NAME} /usr/bin/mysql -u root --password="${WORDPRESS_MYSQL_ROOT_PASSWORD}" wordpress

restore: | dev.up verify-if-backup-exists extract-backup stop-wordpress restore-rename-sites load-mysql-dump-with-serfix start-wordpress ## Restore wordpress backup from a production backup to the devstack
	# Disable login recaptcha on login
	mv wp-content/plugins/login-recaptcha/ wp-content/plugins/_login-recaptcha/
	# Print a message
	$(info Restore with success open http://localhost on your browser)

restore-rename-sites:
	make restore-rename-site FROM_SITE="www.nau.edu.pt" TO_SITE="localhost"
	make restore-rename-site FROM_SITE="https://localhost" TO_SITE="http://localhost"
	make restore-rename-site FROM_SITE="en-www.nau.edu.pt" TO_SITE="en-www.localhost"
	make restore-rename-site FROM_SITE="https://en-www.localhost" TO_SITE="http://en-www.localhost"
	make restore-rename-site FROM_SITE="lms.nau.edu.pt" TO_SITE="lms.dev.nau.fccn.pt"
	make restore-rename-site FROM_SITE="h5p.nau.edu.pt" TO_SITE="h5p.localhost"
	make restore-rename-site FROM_SITE="https://h5p.localhost" TO_SITE="http://h5p.localhost"

install-serfix:
	mkdir -p "${SERFIX_INSTALLATION_FOLDER}"
	wget -q "${SERFIX_DOWNLOAD_LINK}" -O "${SERFIX_INSTALLATION_FOLDER}/.tmp"
	apt-get -qq install unzip
	unzip -o -d "${SERFIX_INSTALLATION_FOLDER}" "${SERFIX_INSTALLATION_FOLDER}/.tmp"
	rm "${SERFIX_INSTALLATION_FOLDER}/.tmp"
	test -f "${SERFIX_COMMAND}"
	chmod +x "${SERFIX_COMMAND}"

restore-rename-site:
	test -n "${FROM_SITE}"
	test -n "${TO_SITE}"
	sed -in "s_${FROM_SITE}_${TO_SITE}_g" ${ROOT_DIR}/db-backup.sql;

load-mysql-dump-with-serfix: | install-serfix
	cat ${ROOT_DIR}/db-backup.sql | ${SERFIX_COMMAND} > ${ROOT_DIR}/serfix-out-db-backup.sql
	cat ${ROOT_DIR}/serfix-out-db-backup.sql | docker exec -i ${DOCKER_CONTAINER_DB_NAME} /usr/bin/mysql -u root --password="${WORDPRESS_MYSQL_ROOT_PASSWORD}" wordpress

clean: ## Clean backup file
	rm -f ${ROOT_DIR}/wordpress.tar.gz
	rm -f ${ROOT_DIR}/db-backup.sqln
	rm -f ${ROOT_DIR}/db-backup.sql
	rm -f ${ROOT_DIR}/serfix-out-db-backup.sql
