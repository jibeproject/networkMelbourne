#!/usr/bin/env bash
echo $BASH_VERSION

# change to the directory this script is located in
cd "$(dirname "$0")"


DB_NAME="jibe"

ogr2ogr \
  -nln region \
  -unsetFid \
  -update \
  -overwrite \
  -f SQLite \
  -dsco SPATIALITE=yes \
  "./data/region.sqlite" \
  PG:"dbname=${DB_NAME} user=postgres" \
  region

ogr2ogr \
  -nln region_buffer \
  -unsetFid \
  -update \
  -overwrite \
  -f SQLite \
  -dsco SPATIALITE=yes \
  "./data/region_buffer.sqlite" \
  PG:"dbname=${DB_NAME} user=postgres" \
  region_buffer

ogr2ogr \
  -nln mb \
  -unsetFid \
  -update \
  -overwrite \
  -f SQLite \
  -dsco SPATIALITE=yes \
  "./data/mb.sqlite" \
  PG:"dbname=${DB_NAME} user=postgres" \
  mb

ogr2ogr \
  -nln sa1 \
  -unsetFid \
  -update \
  -overwrite \
  -f SQLite \
  -dsco SPATIALITE=yes \
  "./data/sa1.sqlite" \
  PG:"dbname=${DB_NAME} user=postgres" \
  sa1

ogr2ogr \
  -nln sa2 \
  -unsetFid \
  -update \
  -overwrite \
  -f SQLite \
  -dsco SPATIALITE=yes \
  "./data/sa2.sqlite" \
  PG:"dbname=${DB_NAME} user=postgres" \
  sa2

ogr2ogr \
  -nln sa3 \
  -unsetFid \
  -update \
  -overwrite \
  -f SQLite \
  -dsco SPATIALITE=yes \
  "./data/sa3.sqlite" \
  PG:"dbname=${DB_NAME} user=postgres" \
  sa3

ogr2ogr \
  -nln sos \
  -unsetFid \
  -update \
  -overwrite \
  -f SQLite \
  -dsco SPATIALITE=yes \
  "./data/urban_regions.sqlite" \
  PG:"dbname=${DB_NAME} user=postgres" \
  sos








