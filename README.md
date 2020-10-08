
## Copy wordpress backup to local
scp wp01-prd:/nau/ops/wordpress/wordpress.tar.gz .

## Restore the backup
sudo make restore

## Stop containers and delete data
sudo make destroy 

