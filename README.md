# GPS Collector

## Original instructions

The task is to stand up a simple Ruby/Rack application backed by a
Postgres/PostGIS database. Your code should be tested, linted, and documented.
The GitHub repository should also include a functional README.md with full
instructions on how to lint, test, and start the app and render the software
documentation. You should use a Docker container for your Postgres/PostGIS db,
to save yourself some time on setup. 

These are the bare minimum tools required to complete this project. You will
need and can install as many other tools as you want (except `Rails`).

## Setup
Download the project and run
 
```bash
docker-compose up
```

To verify the container is up run `docker ps`:

```bash
➜ docker ps
CONTAINER ID        IMAGE                 COMMAND                  CREATED             STATUS              PORTS                                            NAMES
5bc9e8dee3b9        gps-collector_rack    "/bin/sh -c 'ruby -e…"   23 minutes ago      Up 23 minutes       0.0.0.0:8808->8808/tcp, 0.0.0.0:9292->9292/tcp   gps-collector_rack_1
da4481610c49        mdillon/postgis:9.4   "docker-entrypoint.s…"   23 minutes ago      Up 23 minutes       0.0.0.0:5432->5432/tcp                           gps_collector_db
```

You should now be able:

- connect to YARD server via [http://localhost:8808](http://localhost:8808/docs/GpsCollector) to read the documentation.

- send requests to the application http://localhost:9292, see details below.

- connect to DB server via `psql -h localhost -p 5432 -U gps_collector -d gps_collector`

- connect to a docker rack container to run rubocop and tests.

## Lint / Rubocop

Run from the host
 
```bash
➜ docker exec -it gps-collector_rack_1 rubocop
Inspecting 10 files
..........

10 files inspected, no offenses detected
```

## Test

Run from the host
 
```bash
➜ docker exec -it gps-collector_rack_1 rake test 
Finished in 0.10819s
35 tests, 63 assertions, 0 failures, 0 errors, 0 skips
```

*The test clears the main db table. Do not use in a production environment!*

## Fill DB with random values

Run from the host
 
```bash
➜ docker exec -it gps-collector_rack_1 rake add_rnd_points[10000]
  10000 points added, realtime = 0.3697154910041718ms, 27047 points per second
```

## Endpoints

### Add points
​
`POST` - Accepts GeoJSON point(s) to be inserted into a database table

params: Array of GeoJSON Point objects or Geometry collection

With the current implementation, only 65535 points per packet allowed. 

#### Array of GeoJSON Point objects

```bash
➜ curl --request POST \
    --url http://localhost:9292/add_points \
    --header 'content-type: application/json' \
    --data '{
    "Points":[
      {
        "type":"Point",
        "coordinates":[
          -205.01621,
          39111.57422
        ]
      },
      {
        "type":"Point",
        "coordinates":[
          10.01621,
          32
        ]
      }
    ]
  }'
```

You may copy the curl request to [Insomnia Core](https://insomnia.rest/) to make your experiments easier. 
 
#### Geometry collection

All elements in the collection must be "Point" type.
    
```bash
➜ curl --request POST \
  --url http://localhost:9292/add_points \
  --header 'content-type: application/json' \
  --data '{
  "Points":{
    "type":"GeometryCollection",
    "geometries":[
      {
        "type":"Point",
        "coordinates":[
          100.0,
          0.0
        ]
      },
      {
        "type":"Point",
        "coordinates":[
          10.0,
          0.0
        ]
      }
    ]
  }
}'
```

### Point(s) within a radius around a point
​
`GET` - Responds w/GeoJSON point(s) within a radius around a point

params: GeoJSON Point and integer radius in feet/meters

#### Radius in meters (default)

```bash
➜curl --request GET \
   --url 'http://localhost:9292/points_within_radius?e=3' \
   --header 'content-type: application/json' \
   --data '{
   "Radius":17000000,
   "Point":{
     "type":"Point",
     "coordinates":[
       0.01621,
       0.57422
     ]
   }
 }'
```

#### Radius in feet

```bash
➜curl --request GET \
   --url 'http://localhost:9292/points_within_radius?e=3' \
   --header 'content-type: application/json' \
   --data '{
   "Radius":17000000,
   "Radius unit of measure":"feet",
   "Point":{
     "type":"Point",
     "coordinates":[
       0.01621,
       0.57422
     ]
   }
 }'
```

### Point(s) within a geographical polygon

`GET` - Responds w/GeoJSON point(s) within a geographical polygon

params: GeoJSON Polygon with no holes

```bash
➜curl --request GET \
   --url http://localhost:9292/points_within_polygon \
   --header 'content-type: application/json' \
   --data '{
   "Polygon":{
     "type":"Polygon",
     "coordinates":[
       [
         [
           -120,
           60
         ],
         [
           120,
           60
         ],
         [
           120,
           -60
         ],
         [
           -120,
           -60
         ],
         [
           -120,
           60
         ]
       ],
       [
         [
           -60,
           30
         ],
         [
           60,
           30
         ],
         [
           60,
           -30
         ],
         [
           -60,
           -30
         ],
         [
           -60,
           30
         ]
       ]
     ]
   }
 }'
```


## Useful links
- [docker](https://docs.docker.com/install/)
- [docker-compose](https://docs.docker.com/compose/install/)
- [psql](https://www.postgresql.org/download/)
- [ruby](https://www.ruby-lang.org/en/downloads/)
- [rack](https://github.com/rack/rack)
- [GeoJSON examples](https://tools.ietf.org/html/rfc7946#appendix-A)
- [PostGIS/Postgres Docker container](https://hub.docker.com/r/mdillon/postgis)
- [Linter(Rubocop)](https://docs.rubocop.org/en/stable/)
- [YARD](https://yardoc.org)
