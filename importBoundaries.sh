#!/usr/bin/env bash
echo $BASH_VERSION

# change to the directory this script is located in
cd "$(dirname "$0")"

# the postgres database name.
DB_NAME=false
ASGS_VOL_1_LOCATION=false

# Display help
function show_help()
{
  echo "USAGE: importBoundaries.sh [OPTIONS]... "
  echo "This script creates the database and its schemas."
  echo "OPTIONS are:"
  echo "  -h, --help                            | Display this help message     "
  echo "  -d, --database=DB_NAME                | Database name                 "
  echo "  -1, --asgs_vol_1=ASGS_VOL_1_LOCATION  | Location of ASGS volume 1 gpkg"
}

# Parse command line arguments
for arg in "$@"
do
  case "$arg" in
    -h   | --help              )  show_help; exit 0               ;;
    -d=* | --database=*        )  DB_NAME="${arg#*=}"             ;;
    -1=* | --asgs_vol_1=*      )  ASGS_VOL_1_LOCATION="${arg#*=}" ;;
    *) echo "Invalid option: $arg" >&2; show_help; exit 1         ;;
  esac
done

if [ "$DB_NAME" = false ] ; then
  echo 'No database name supplied'
  show_help
  exit
fi

if [ "$ASGS_VOL_1_LOCATION" = false ] ; then
  echo 'No ASGS volume 1 geopackage location supplied'
  show_help
  exit
fi

#DB_NAME="jibe"
#ASGS_VOL_1_LOCATION="/home/hps/DATA/Datasets/ABS/2016/ASGS_volume_1.sqlite"


createdb -U postgres ${DB_NAME}
psql -c 'CREATE EXTENSION IF NOT EXISTS postgis' ${DB_NAME} postgres
psql -c 'CREATE SCHEMA IF NOT EXISTS boundaries' ${DB_NAME} postgres

# import all meshblocks
ogr2ogr \
  -nln mb_import \
  -lco OVERWRITE=YES \
  -dim XY \
  -f "PostgreSQL" \
  PG:"host=localhost port=5432 user=postgres dbname=${DB_NAME}" \
  -a_srs "EPSG:4326" \
  -nlt PROMOTE_TO_MULTI \
  -dialect SQLite -sql \
    "SELECT CAST(mb_code_2016 AS DOUBLE PRECISION) AS mb_code, \
       mb_category_name_2016 AS category, \
       CAST(sa1_maincode_2016 AS DOUBLE PRECISION) AS sa1_code, \
       mb_category_name_2016, geom FROM MB_2016_AUST" \
  "$ASGS_VOL_1_LOCATION"
  
# import SA1
ogr2ogr \
  -nln sa1 \
  -lco OVERWRITE=YES \
  -dim XY \
  -f "PostgreSQL" \
  PG:"host=localhost port=5432 user=postgres dbname=${DB_NAME}" \
  -a_srs "EPSG:4326" \
  -nlt PROMOTE_TO_MULTI \
  -dialect SQLite -sql \
    "SELECT CAST(sa1_maincode_2016 AS DOUBLE PRECISION) AS sa1_code,
            geom FROM SA1_2016_AUST 
     WHERE GCCSA_NAME_2016 LIKE 'Greater Melbourne' " \
  "$ASGS_VOL_1_LOCATION"

# import SA2
ogr2ogr \
  -nln sa2 \
  -lco OVERWRITE=YES \
  -dim XY \
  -f "PostgreSQL" \
  PG:"host=localhost port=5432 user=postgres dbname=${DB_NAME}" \
  -a_srs "EPSG:4326" \
  -nlt PROMOTE_TO_MULTI \
  -dialect SQLite -sql \
    "SELECT CAST(sa2_maincode_2016 AS DOUBLE PRECISION) AS sa2_code,
            geom FROM SA2_2016_AUST
     WHERE GCCSA_NAME_2016 LIKE 'Greater Melbourne' " \
  "$ASGS_VOL_1_LOCATION"

# import study region (Greater Melbourne)
ogr2ogr \
  -nln region \
  -lco OVERWRITE=YES \
  -dim XY \
  -f "PostgreSQL" \
  PG:"host=localhost port=5432 user=postgres dbname=${DB_NAME}" \
  -a_srs "EPSG:4326" \
  -nlt PROMOTE_TO_MULTI \
  -dialect SQLite -sql \
    "SELECT 'Melbourne' AS locale, geom FROM GCCSA_2016_AUST \
       WHERE GCCSA_NAME_2016 LIKE 'Greater Melbourne' " \
  "$ASGS_VOL_1_LOCATION"

# run the sql that processes the data
psql -U postgres -d ${DB_NAME} -a -f importBoundaries.sql