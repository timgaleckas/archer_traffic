# archer_traffic
Download traffic stats from Archer C7

## Requirements
Just docker

## Build docker container with app
`docker build -t archer-traffic .`

## Run docker
Replace username and password with your info. You can set ARCHER_IP if
your router isn't at 192.168.0.1

`docker run -it -e ARCHER_USERNAME=username -e ARCHER_PASSWORD=password --rm --mount src=`pwd`,target=/data,type=bind --name archer-traffic archer-traffic`

This will create or update a sqlite db in the current directory named
'db.db'

```
sqlite3 db.db
SQLite version 3.19.3 2017-06-27 16:48:08
Enter ".help" for usage hints.
sqlite> .table stats
stats
sqlite> .schema stats
CREATE TABLE stats (
        name varchar(128),
        mac varchar(128),
        ip varchar(128),
        bytes int,
        gb int,
        as_of datetime
      );
```
