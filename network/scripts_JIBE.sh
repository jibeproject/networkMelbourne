cd /Users/alan/Projects/matsim-melbourne/network
./processOSM_JIBE.sh './data/victoriaOSM.sqlite' 28355 './data/network_victoria.sqlite'






ogr2ogr -f SQLite -clipsrc "region_buffer.sqlite" "melbourneBufferOSM.sqlite" "australia-190101.osm.pbf"

ogr2ogr -f SQLite -clipsrc "victoria.sqlite" "victoriaOSM.sqlite" "australia-190101.osm.pbf"

ogr2ogr -f SQLite -clipsrc "testRegion.sqlite" "testRegionOSM.sqlite" "australia-190101.osm.pbf"


ogr2ogr -f SQLite -spat "testRegion.sqlite" "testRegionOSM3.sqlite" "australia-190101.osm.pbf"

ogr2ogr -f SQLite -spat region.sqlite output.sqlite input.osm.pbf


ogr2ogr -f SQLite -sql "SELECT a.* FROM 'australia-190101.osm.pbf' AS a, 'testRegion.sqlite' AS b WHERE ST_Intersects(a.geometry, b.geometry)" "testRegionOSM4.sqlite"

psql -U postgres -d ${DB_NAME}


DROP TABLE IF EXISTS roads;
DROP TABLE IF EXISTS roads_points;
DROP TABLE IF EXISTS crossing;

select * from roads WHERE ST_NumGeometries(geom_column) > 1;

./processOSM.sh './data/testRegionOSM.sqlite' 28355 './data/network_testRegion.sqlite'

./processOSM.sh './data/melbourneBufferOSM.sqlite' 28355 './data/network_melbourne.sqlite'

./processOSM.sh './data/victoriaOSM.sqlite' 28355 './data/network_victoria.sqlite'



./processOSM.sh  28355 
extract='./data/melbourneBufferOSM.sqlite'
crs=28355
output='./data/network_melbourne.sqlite'

psql -U postgres -d ${DB_NAME} -v v1="$crs"



`UPDATE your_table SET geom_column = ST_GeometryN(geom_column, 1) WHERE ST_NumGeometries(geom_column) > 1;