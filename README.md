# Devstack for NAU WordPress
This repository contains a development stack for [NAU WordPress theme](https://gitlab.fccn.pt/nau/wp-nau-theme).
It requires docker and a linux machine.

## Prepare environment

Assumption, it should exist a sister folder with name **wp-nau-theme** that contains the [NAU WordPress theme](https://gitlab.fccn.pt/nau/wp-nau-theme).

Copy wordpress backup to local
```bash
scp wp01-prd:/nau/ops/wordpress/wordpress.tar.gz .
```

Restore the backup. It needs to be run using sudo.
```bash
sudo make restore
```

## Development
Start up the docker containers.
```bash
make dev.up
```

```bash
make stop.all
```

## Security
Currently, for security purposes the ports are blocked to localhost.
When everything is up, you can open the browser the page [http://localhost](http://localhost) and see NAU WordPress marketing site.

## Clean

Stop docker container and delete data
```bash
sudo make destroy 
```

Delete backup
```bash
make clean
```

## Install more dependencies on the gulpjs run
```bash
docker-compose run wordpress_watcher bash
npm install gulp-sourcemaps
```

