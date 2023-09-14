-- Changing boundaries to ESPG:28355
ALTER TABLE region
 ALTER COLUMN geom TYPE geometry(MultiPolygon,28355)
  USING ST_Transform(geom,28355);
CREATE INDEX region_gix ON region USING GIST (geom);

ALTER TABLE sa1
 ALTER COLUMN geom TYPE geometry(MultiPolygon,28355)
  USING ST_Transform(geom,28355);
CREATE INDEX sa1_gix ON sa1 USING GIST (geom);

ALTER TABLE sa2
 ALTER COLUMN geom TYPE geometry(MultiPolygon,28355)
  USING ST_Transform(geom,28355);
CREATE INDEX sa2_gix ON sa1 USING GIST (geom);

ALTER TABLE sa3
 ALTER COLUMN geom TYPE geometry(MultiPolygon,28355)
  USING ST_Transform(geom,28355);
CREATE INDEX sa3_gix ON sa3 USING GIST (geom);

ALTER TABLE sos
 ALTER COLUMN geom TYPE geometry(MultiPolygon,28355)
  USING ST_Transform(geom,28355);
CREATE INDEX sos_gix ON sos USING GIST (geom);

ALTER TABLE mb_import
 ALTER COLUMN geom TYPE geometry(MultiPolygon,28355)
  USING ST_Transform(geom,28355);
CREATE INDEX mb_import_gix ON mb USING GIST (geom);

-- Make geometries valid by removing self-intersections
UPDATE region
  SET geom = ST_Multi(ST_CollectionHomogenize(
    ST_CollectionExtract(ST_MakeValid(geom),3) ));
UPDATE sos
  SET geom = ST_Multi(ST_CollectionHomogenize(
    ST_CollectionExtract(ST_MakeValid(geom),3) ));
UPDATE sa3
  SET geom = ST_Multi(ST_CollectionHomogenize(
    ST_CollectionExtract(ST_MakeValid(geom),3) ));
UPDATE sa2
  SET geom = ST_Multi(ST_CollectionHomogenize(
    ST_CollectionExtract(ST_MakeValid(geom),3) ));
UPDATE sa1
  SET geom = ST_Multi(ST_CollectionHomogenize(
    ST_CollectionExtract(ST_MakeValid(geom),3) ));
UPDATE mb_import
  SET geom = ST_Multi(ST_CollectionHomogenize(
    ST_CollectionExtract(ST_MakeValid(geom),3) ));

-- Buffering the city regions by 10km to capture locations slightly outside city
DROP TABLE IF EXISTS region_buffer;
CREATE TABLE region_buffer AS
SELECT locale, ST_Buffer(geom,10000) AS geom
FROM region;
CREATE INDEX region_buffer_gix ON region_buffer USING GIST (geom);

-- All of the meshblocks within the 10km buffer of the city
DROP TABLE IF EXISTS mb;
CREATE TABLE mb AS
SELECT a.mb_code,
       a.sa1_code,
       a.category,
       a.geom
FROM mb_import AS a,
     region_buffer AS b
WHERE ST_Intersects(a.geom, b.geom);
CREATE INDEX mb_gix ON mb USING GIST (geom);