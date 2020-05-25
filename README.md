# GPS Collector

## Original instructions

The task is to stand up a simple Ruby/Rack application backed by a
Postgres/PostGIS database. Your code should be tested, linted, and documented.
The GitHub repository should also include a functional README.md with full
instructions on how to lint, test, and start the app and render the software
documentation. You should use a Docker container for your Postgres/PostGIS db,
to save yourself some time on setup. 
​
### Requirements
​
##### Endpoints
​
1) `POST` - Accepts GeoJSON point(s) to be inserted into a database table
   params: Array of GeoJSON Point objects or Geometry collection
​
2) `GET` - Responds w/GeoJSON point(s) within a radius around a point
   params: GeoJSON Point and integer radius in feet/meters
​
3) `GET` - Responds w/GeoJSON point(s) within a geographical polygon
   params: GeoJSON Polygon with no holes
​
##### Dependencies
​
These are the bare minimum tools required to complete this project. You will
need and can install as many other tools as you want (except `Rails`).
​
- [docker](https://docs.docker.com/install/)
- [docker-compose](https://docs.docker.com/compose/install/)
- [psql](https://www.postgresql.org/download/)
- [ruby](https://www.ruby-lang.org/en/downloads/)
- [rack](https://github.com/rack/rack)
​
### Helpful Links
​
- [GeoJSON examples](https://tools.ietf.org/html/rfc7946#appendix-A)
- [Docker install](https://docs.docker.com/install/)
- [PostGIS/Postgres Docker container](https://hub.docker.com/r/mdillon/postgis)
- [Linter](https://docs.rubocop.org/en/stable/)
- [RDoc](https://ruby.github.io/rdoc/) [YARD](https://yardoc.org)

# Setup
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
- connect to YARD server via http://localhost:8808/
- send requests to the application http://localhost:9292/ , see details below
- connect to DB server via `psql -h localhost -p 5432 -U gps_collector -d gps_collector`

# Lint / Rubocop
Run 
```bash
➜ docker exec -it gps-collector_rack_1 rubocop
Inspecting 10 files
..........

10 files inspected, no offenses detected
```

# Test
Run 
```bash
➜ docker exec -it gps-collector_rack_1 rake test 
Started with run options --seed 49949

GpsCollector::add_points
 PASS (0.05s) :: test_0001_adds one record from Array of GeoJSON Point objects
 PASS (0.01s) :: test_0002_adds two records from Array of GeoJSON Point objects
 PASS (0.01s) :: test_0003_adds records from Geometry collection

ParamsParser::points_within_polygon
 PASS (0.00s) :: test_0003_must raise ArgumentError if Polygon parameter is not valid GeoJSON
 PASS (0.00s) :: test_0001_must process well-defined Polygon
 PASS (0.00s) :: test_0002_must raise ArgumentError if Polygon parameter absent
 PASS (0.00s) :: test_0004_must raise ArgumentError if valid GeoJSON passed but not Polygon
 PASS (0.00s) :: test_0005_must raise RGeo::Error::RGeoError if Polygon contains one point

GpsCollector::points_within_radius
 PASS (0.01s) :: test_0001_responds w/GeoJSON point(s) within a radius around a point
 PASS (0.01s) :: test_0002_responds w/GeoJSON point(s) within a radius in feet around a point

ParamsParser::add_points::with Array of GeoJSON Point objects
 PASS (0.00s) :: test_0001_must process well-defined parameters
 PASS (0.00s) :: test_0002_must raise ArgumentError if Points array is empty
 PASS (0.00s) :: test_0004_must raise ArgumentError if valid GeoJSON passed to Points array but not Point
 PASS (0.00s) :: test_0003_must raise ArgumentError if Points parameter contains not valid GeoJSON

ParamsParser::add_points::with Geometry collection
 PASS (0.00s) :: test_0002_must raise ArgumentError if Geometry collection is not valid GeoJSON
 PASS (0.00s) :: test_0003_must raise ArgumentError if valid GeoJSON passed but not GeometryCollection
 PASS (0.00s) :: test_0001_must process well-defined Geometry collection

ParamsParser::parse_body
 PASS (0.00s) :: test_0003_must raise ArgumentError if body is n't JSON
 PASS (0.00s) :: test_0002_must raise ArgumentError if body is an empty string
 PASS (0.00s) :: test_0001_must raise ArgumentError if body is empty

ParamsParser::add_points::with improper parameters
 PASS (0.00s) :: test_0001_must raise ArgumentError if Points parameter absent
 PASS (0.00s) :: test_0002_must raise ArgumentError if Points parameter isn't GeoJSON Point nor Geometry collection

GpsCollector::points_within_polygon
 PASS (0.01s) :: test_0001_responds w/GeoJSON point(s) within a geographical polygon

GpsCollector
 PASS (0.00s) :: test_0002_returns an error on improper content_type
 PASS (0.01s) :: test_0001_returns an error on unknown combination of method/path

ParamsParser::points_within_radius
 PASS (0.00s) :: test_0005_must raise ArgumentError if Radius isn't a number
 PASS (0.00s) :: test_0010_must raise ArgumentError if valid GeoJSON passed but not Point
 PASS (0.00s) :: test_0002_must accept "Radius unit of measure" => "meters" parameter
 PASS (0.00s) :: test_0007_must raise ArgumentError if "Radius unit of measure" isn't whitelisted
 PASS (0.00s) :: test_0003_must accept "Radius unit of measure" => "feet" parameter
 PASS (0.00s) :: test_0008_must raise ArgumentError if Point parameter absent
 PASS (0.00s) :: test_0006_must raise ArgumentError if Radius is negative
 PASS (0.00s) :: test_0009_must raise ArgumentError if Point parameter is not valid GeoJSON
 PASS (0.00s) :: test_0004_must raise ArgumentError if Radius parameter absent
 PASS (0.00s) :: test_0001_must process well-defined parameters

Finished in 0.10819s
35 tests, 63 assertions, 0 failures, 0 errors, 0 skips
```
