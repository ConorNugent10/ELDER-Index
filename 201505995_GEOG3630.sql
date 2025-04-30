--create postGIS extension on database--
create extension postgis;

--create new schema for ELDER index
create schema ELDER;

-----------------------------
--LOADING DATA
-----------------------------

--LSOA boundaries
--LSOA boundaries are loaded using the Database Manager plugin in QGIS

--LIVING ARRANGEMENTS

--create table structure for living arrangements data
create table ELDER.liv_arr
(
lsoa21nm varchar,
lsoa21cd varchar,
hh int,
hh_one_person_tot int,
hh_one_person_o66 int,
hh_one_person_other int,
hh_single_family int,
hh_other int
);

--copy living arrangements data from .csv file
copy ELDER.liv_arr
from 'C:\tmp\Leeds - Household Composition - 2021 Census - LSOA.csv'
DELIMITER ',' CSV; --488

--add primary key
alter table ELDER.liv_arr
add primary key (lsoa21cd);

--HEALTH

--create table structure for health data
create table ELDER.health
(
lsoa21cd varchar,
lsoa21nm varchar,
pop_tot int,
o65_tot int,
o65_health_g_vg int,
o65_health_fair int,
o65_health_b_vb int
);

--copy health data from .csv file
copy ELDER.health
from 'C:\tmp\Leeds - 2021 Census - All usual residents - Age (4 categories) x General Health (4 categories) - pivoted.csv'
DELIMITER ',' CSV header; --488

--add primary key
alter table ELDER.health
add primary key (lsoa21cd);

--EDUCATION

--create table structure for education data
create table ELDER.education
(
lsoa21cd varchar,
lsoa21nm varchar,
o65_tot int,
o65_noqual int,
o65_level1 int,
o65_level2 int,
o65_level3 int,
o65_level4 int,
o65_other int
);

--copy education data from .csv file
copy ELDER.education
from 'C:\tmp\Leeds - Census 2021 - All usual residents - Age x Highest Qualification - pivoted.csv'
DELIMITER ',' CSV header; --488

--add primary key
alter table ELDER.education
add primary key (lsoa21cd);

--DEPRIVATION

--create  table for deprivation data
create table ELDER.idaopi
(
lsoa21cd varchar,
idaopi2019 real
);

--copy deprivation data from .csv file
copy ELDER.idaopi 
from 'C:\tmp\Leeds - IDAOPI 2019.csv'
delimiter ',' csv header; --488

--CAR ACCESS

--create table for car access data
create table ELDER.car_access
(
lsoa21cd varchar,
hh int,
hh_o65 int,
hh_o65_nocar int,
hh_o65_car int
);

--copy car access data from .csv file
copy ELDER.car_access
from 'C:\tmp\Leeds - Household compsition and car ownership - pivoted.csv'
delimiter ','
csv header; --488

--add primary key
alter table ELDER.car_access
add primary key (lsoa21cd);

--PUBLIC TRANSPORT ACCESS

--create table for NaPTAN data
create table ELDER.naptan_nodes
(
atco_code varchar,
naptan_code int,
plate_code varchar,
common_name varchar,
landmark varchar,
street varchar,
indicator varchar,
bearing varchar,
nptg_locality_code  varchar,
locality_name varchar,
parent_locality_name varchar,
town varchar,
easting int,
northing int,
longitude real,
latitude real,
stop_type varchar,
bus_stop_type varchar,
timing_status varchar,
status varchar
);

--copy from csv
copy ELDER.naptan_nodes
from 'C:\tmp\450Stops (1).csv'
delimiter ',' 
csv header; --16869

--add a primary key
alter table ELDER.naptan_nodes
add primary key (atco_code);

--add a geometry column
alter table ELDER.naptan_nodes
add column geom geometry;

--set geometries based on latitude and longitude in EPSG: 4326, then transform to British National Grid EPSG: 27700
update ELDER.naptan_nodes
set geom = ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 27700); --16869

--create some spatial indices to decrease computational burden
create index naptan_nodes_gix on ELDER.naptan_nodes using gist (geom);
create index leeds_lsoas_2021_gix on ELDER.leeds_lsoas_2021 using gist (geom);

--need to do a point-in-polygon function to find nodes in Leeds, so create a table of all joined Leeds LSOAs
select st_union(geom) as geom
into ELDER.leeds_lsoas_joined
from ELDER.leeds_lsoas_2021;

--create index on joined Leeds LSOAs table
create index leeds_lsoas_joined_gix on ELDER.leeds_lsoas_joined using gist (geom);

 --find all nodes that are in Leeds LSOAs
select count(*) 
from ELDER.naptan_nodes a
left join ELDER.leeds_lsoas_2021 b
on st_within(a.geom, b.geom)
where b.lsoa21cd is not null; --4452

--select these nodes in Leeds LSOAs into new table
select a.* 
into ELDER.naptan_nodes_leeds
from ELDER.naptan_nodes a
left join ELDER.leeds_lsoas_2021 b
on st_within(a.geom, b.geom)
where b.lsoa21cd is not null
; --4452

--add a primary key
alter table ELDER.naptan_nodes_leeds
add primary key (atco_code);

--create a spatial index to decrease computational burden
create index naptan_nodes_leeds_gix on ELDER.naptan_nodes_leeds using gist (geom);

-- assign all nodes to the LSOA in which they are located 
--first add column
alter table ELDER.naptan_nodes_leeds
add column lsoa21cd varchar;

--then update column
update ELDER.naptan_nodes_leeds a
set lsoa21cd = b.lsoa21cd
from ELDER.leeds_lsoas_2021 b
where st_within(a.geom,b.geom); --4452

--check how many nodes per LSOA
select lsoa21cd, count(*)
from ELDER.naptan_nodes_leeds
group by 1
order by 2 asc;

--add number of people aged over 65 to new column from education table
--add column
alter table ELDER.naptan_nodes_per_lsoa
add column o65_tot int;

--update column
update ELDER.naptan_nodes_per_lsoa a
set o65_tot = b.o65_tot
from ELDER.education b
where a.lsoa21cd=b.lsoa21cd; --488

--add column for number of nodes per 1,000 people aged 65+
alter table ELDER.naptan_nodes_per_lsoa add column num_nodes_per_k_o65 real;

--then update - need to cast integers as real as we need real numbers at the end 
update ELDER.naptan_nodes_per_lsoa
set num_nodes_per_k_o65 = ((cast(num_nodes as real)/cast(o65_tot as real))*1000); --488

--check calculated correctly
select * from ELDER.naptan_nodes_per_lsoa
order by 6 desc;

--DIGITAL EXCLUSION

--create table for digital exclusion data
create table ELDER.digital_exclusion
(
lsoa11cd varchar,
dpi real
);

--copy digital exclusion data from .csv file
copy ELDER.digital_exclusion 
from 'C:\tmp\Leeds - Digital Propensity Index - 2011 LSOAs.csv'
delimiter ',' csv header; --482

--add a primary key
alter table ELDER.digital_exclusion
add primary key (lsoa11cd);

--do some manual changes for LSOAs that changed between 2011 and 2021 census, using assignment method as outlined in section 3.4.1.2
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035040',0.972);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035041',0.972);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035052',0.969);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035053',0.969);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035051',0.983);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035050',0.983);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035048',0.964);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035049',0.964);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035054',0.993);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035046',0.987);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035047',0.987);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035044',0.985);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035045',0.985);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035042',0.955);
insert into ELDER.digital_exclusion(lsoa11cd,dpi) values('E01035043',0.955);

--find the 2011 LSOAs that no longer exist in 2021
select lsoa11cd
from ELDER.digital_exclusion a
left join ELDER.leeds_lsoas_2021 b
on a.lsoa11cd = b.lsoa21cd
where b.lsoa21cd is null;

--now delete the 2011 LSOAs that no longer exist in 2021
delete from ELDER.digital_exclusion where lsoa11cd in
(select lsoa11cd
from ELDER.digital_exclusion a
left join ELDER.leeds_lsoas_2021 b
on a.lsoa11cd = b.lsoa21cd
where b.lsoa21cd is null); --9

--check that there are the correct number of rows - 488
select * from ELDER.digital_exclusion; --488
select count(*) 
from ELDER.digital_exclusion a
join ELDER.leeds_lsoas_2021 b
on a.lsoa11cd=b.lsoa21cd; --488

--rename LSOA column to indicate they are now 2021 LSOAs
alter table ELDER.digital_exclusion
rename column lsoa11cd to lsoa21cd;

--Check that we have data for each variable from each LSOA - so need to do a join from boundary to variable tables and ensure all 488 LSOAs have data in each

-- LSOA Boundaries
select lsoa21cd from ELDER.leeds_lsoas_2021; --488

--Education
select b.lsoa21cd
from ELDER.leeds_lsoas_2021 a
join ELDER.education b
on a.lsoa21cd=b.lsoa21cd; --488

--Living Arrangements
select b.lsoa21cd
from ELDER.leeds_lsoas_2021 a
join ELDER.liv_arr b
on a.lsoa21cd=b.lsoa21cd; --488

--Digital Exclusion
select b.lsoa21cd
from ELDER.leeds_lsoas_2021 a
join ELDER.digital_exclusion b
on a.lsoa21cd=b.lsoa21cd; --488

--Deprivation
select b.lsoa21cd
from ELDER.leeds_lsoas_2021 a
join ELDER.idaopi b
on a.lsoa21cd=b.lsoa21cd; --488

--Car Access
select b.lsoa21cd
from ELDER.leeds_lsoas_2021 a
join ELDER.car_access b
on a.lsoa21cd=b.lsoa21cd; --488

--Health
select b.lsoa21cd
from ELDER.leeds_lsoas_2021 a
join ELDER.health b
on a.lsoa21cd=b.lsoa21cd; --488

--Public Transport Access
select b.lsoa21cd
from ELDER.leeds_lsoas_2021 a
join ELDER.naptan_nodes_per_lsoa b
on a.lsoa21cd=b.lsoa21cd; --488

--don't need to do 

------------------------
--STANDARDISATION
------------------------

--Education
--add columns for percentage of over 65s qualified to each level
alter table ELDER.education
add column o65_noqual_pc real,
add column o65_level1_pc real,
add column o65_level2_pc real,
add column o65_level3_pc real,
add column o65_level4_pc real,
add column o65_other_pc real
;

--update columns
update ELDER.education
set o65_noqual_pc = (cast(o65_noqual as real)/cast(o65_tot as real)),
o65_level1_pc = (cast(o65_level1 as real)/cast(o65_tot as real)),
o65_level2_pc = (cast(o65_level2 as real)/cast(o65_tot as real)),
o65_level3_pc = (cast(o65_level3 as real)/cast(o65_tot as real)),
o65_level4_pc = (cast(o65_level4 as real)/cast(o65_tot as real)),
o65_other_pc = (cast(o65_other as real)/cast(o65_tot as real))
; --488

--check calculated correctly
select * from ELDER.education;

--Health
--add columns for percentage of over 65s in each health category
alter table ELDER.health
add column o65_health_g_vg_pc real,
add column o65_health_fair_pc real,
add column o65_health_b_vb_pc real
;

--update columns
update ELDER.health
set o65_health_g_vg_pc = (cast(o65_health_g_vg as real)/cast(o65_tot as real)),
o65_health_fair_pc = (cast(o65_health_fair as real)/cast(o65_tot as real)),
o65_health_b_vb_pc = (cast(o65_health_b_vb as real)/cast(o65_tot as real))
; --488

--check calculated correctly
select * from ELDER.health;

--Living Arrangemnts 
--add column for households occupied by a single person aged 66+
alter table ELDER.liv_arr
add column hh_one_person_o66_pc real;

--update column
update ELDER.liv_arr
set hh_one_person_o66_pc = (cast(hh_one_person_o66 as real)/cast(hh as real)); --488

--check calculated correctly
select * from ELDER.liv_arr;

--Car Access
--rename some columns for accuracy and consistency with living arrangemnets table
alter table ELDER.car_access rename column hh_o65 to hh_one_person_o66;
alter table ELDER.car_access rename column hh_o65_nocar to hh_one_person_o66_nocar;
alter table ELDER.car_access rename column hh_o65_car to hh_one_person_o66_car;

--add columns for percentage of households occupied by a single person aged 66+ with/without access to a car
alter table ELDER.car_access
add column hh_one_person_o66_nocar_pc real,
add column hh_one_person_o66_car_pc real;

--update columns - again need to cast as real as we want the final numbers to be real too
update ELDER.car_access
set hh_one_person_o66_nocar_pc = (cast(hh_one_person_o66_nocar as real)/cast(hh_one_person_o66 as real)),
hh_one_person_o66_car_pc = (cast(hh_one_person_o66_car as real)/cast(hh_one_person_o66 as real)); --488

--check calculated correctly
select * from ELDER.car_access;

----------------------------------
--COLLATE ALL DATA INTO ONE TABLE
----------------------------------

--make sure that the join works and 488 rows in all table, one for each Leeds LSOA
select *
from ELDER.leeds_lsoas_2021 a
join ELDER.education b
on a.lsoa21cd=b.lsoa21cd
join ELDER.liv_arr c
on a.lsoa21cd=c.lsoa21cd
join ELDER.digital_exclusion d
on a.lsoa21cd=d.lsoa21cd
join ELDER.car_access e
on a.lsoa21cd=e.lsoa21cd
join ELDER.health f
on a.lsoa21cd=f.lsoa21cd
join ELDER.deprivation g
on a.lsoa21cd=g.lsoa21cd
join ELDER.naptan_nodes_per_lsoa h
on a.lsoa21cd=h.lsoa21cd
;

--collate all the columns we need into one table called 'collated'
drop table if exists ELDER.collated;
select a.lsoa21cd, a.lsoa21nm, a.geom, c.hh, c.hh_one_person_o66, c.hh_one_person_o66_pc, e.hh_one_person_o66_nocar, e.hh_one_person_o66_nocar_pc, d.dpi, a.pop_tot, a.o65_tot, b.o65_noqual, b.o65_noqual_pc, f.o65_health_b_vb, f.o65_health_b_vb_pc, g.idaopi2019, h.num_nodes_per_k, h.num_nodes_per_k_o65
into ELDER.collated
from ELDER.leeds_lsoas_2021 a
join ELDER.education b
on a.lsoa21cd=b.lsoa21cd
join ELDER.liv_arr c
on a.lsoa21cd=c.lsoa21cd
join ELDER.digital_exclusion d
on a.lsoa21cd=d.lsoa21cd
join ELDER.car_access e
on a.lsoa21cd=e.lsoa21cd
join ELDER.health f
on a.lsoa21cd=f.lsoa21cd
join ELDER.idaopi g
on a.lsoa21cd=g.lsoa21cd
join ELDER.naptan_nodes_per_lsoa h
on a.lsoa21cd=h.lsoa21cd
; --488

--check collation worked
select * from ELDER.collated;

--------------------
--WINSORISATION
--------------------

--Winsorising all variables below and above 3rd and 97th percentile, respectively
--add columns for winsorisation
alter table ELDER.collated add column o65_noqual_pc_wins real;
alter table ELDER.collated add column num_nodes_per_k_o65_wins real;
alter table ELDER.collated add column hh_one_person_o66_nocar_pc_wins real;
alter table ELDER.collated add column o65_health_b_vb_pc_wins real;
alter table ELDER.collated add column dpi_wins real
alter table ELDER.collated add column idaopi2019_wins real;
alter table ELDER.collated add column hh_one_person_o66_pc_wins real;

--Winsorise Education

--Winsorise above 97th percentile
with percentile_calc as (
    select percentile_cont(0.97) within group (order by o65_noqual_pc) as p97
    from ELDER.collated
)
update ELDER.collated
set o65_noqual_pc_wins = 
    case 
        when o65_noqual_pc > (select p97 from percentile_calc) then (select p97 from percentile_calc)
        else o65_noqual_pc
    end; --488

--Winsorise below the 3rd percentile - the 'else' changes to the winsorised variable to keep the top 3% winsorised from the previous code whilst the bottom 3% are winsorised
with percentile_calc as (
    select percentile_cont(0.03) within group (order by o65_noqual_pc) as p03
    from ELDER.collated
)
update ELDER.collated
set o65_noqual_pc_wins = 
    case 
        when o65_noqual_pc < (select p03 from percentile_calc) then (select p03 from percentile_calc)
		else o65_noqual_pc_wins
    end; --488

--check winsorised correctly
select o65_noqual_pc, o65_noqual_pc_wins
from ELDER.collated
order by 2 desc, 1 desc;

--Winsorise Health

--Winsorise above 97th percentile
with percentile_calc as (
    select percentile_cont(0.97) within group (order by o65_health_b_vb_pc) as p97
    from ELDER.collated
)
update ELDER.collated
set o65_health_b_vb_pc_wins = 
    case 
        when o65_health_b_vb_pc > (select p97 from percentile_calc) then (select p97 from percentile_calc)
        else o65_health_b_vb_pc
    end; --488

--Winsorise below 3rd percentile - the 'else' changes to the winsorised variable to keep the top 3% winsorised from the previous code whilst the bottom 3% are winsorised
with percentile_calc as (
    select percentile_cont(0.03) within group (order by o65_health_b_vb_pc) as p03
    from ELDER.collated
)
update ELDER.collated
set o65_health_b_vb_pc_wins = 
    case 
        when o65_health_b_vb_pc < (select p03 from percentile_calc) then (select p03 from percentile_calc)
		else o65_health_b_vb_pc_wins
    end; --488

--check winsorised correctly
select o65_health_b_vb_pc, o65_health_b_vb_pc_wins
from ELDER.collated
order by 2 desc, 1 desc;

--Winsorise Car Access

--Winsorise above 97th percentile
with percentile_calc as (
    select percentile_cont(0.97) within group (order by hh_one_person_o66_nocar_pc) as p97
    from ELDER.collated
)
update ELDER.collated
set hh_one_person_o66_nocar_pc_wins = 
    case 
        when hh_one_person_o66_nocar_pc > (select p97 from percentile_calc) then (select p97 from percentile_calc)
        else hh_one_person_o66_nocar_pc
    end; --488

--Winsorise below 3rd percentile - the 'else' changes to the winsorised variable to keep the top 3% winsorised from the previous code whilst the bottom 3% are winsorised
with percentile_calc as (
    select percentile_cont(0.03) within group (order by hh_one_person_o66_nocar_pc) as p03
    from ELDER.collated
)
update ELDER.collated
set hh_one_person_o66_nocar_pc_wins = 
    case 
        when hh_one_person_o66_nocar_pc < (select p03 from percentile_calc) then (select p03 from percentile_calc)
		else hh_one_person_o66_nocar_pc_wins
    end; --488

--check winsorised correctly
select hh_one_person_o66_nocar_pc, hh_one_person_o66_nocar_pc_wins
from ELDER.collated
order by 2 desc, 1 desc;

--Winsorise Public Transport Access

--Winsorise above 97th percentile
with percentile_calc as (
    select percentile_cont(0.97) within group (order by num_nodes_per_k_o65) as p97
    from ELDER.collated
)
update ELDER.collated
set num_nodes_per_k_o65_wins = 
    case 
        when num_nodes_per_k_o65 > (select p97 from percentile_calc) then (select p97 from percentile_calc)
        else num_nodes_per_k_o65
    end; --488

--Winsorise below 3rd percentile - the 'else' changes to the winsorised variable to keep the top 3% winsorised from the previous code whilst the bottom 3% are winsorised
with percentile_calc as (
    select percentile_cont(0.03) within group (order by num_nodes_per_k_o65) as p03
    from ELDER.collated
)
update ELDER.collated
set num_nodes_per_k_o65_wins = 
    case 
        when num_nodes_per_k_o65 < (select p03 from percentile_calc) then (select p03 from percentile_calc)
		else num_nodes_per_k_o65_wins
    end; --488

--check winsorised correctly
select num_nodes_per_k_o65, num_nodes_per_k_o65_wins
from ELDER.collated
order by 2 desc, 1 desc;

--Winsorise Digital Exclusion

--Winsorise above 97th percentile
with percentile_calc as (
    select percentile_cont(0.97) within group (order by dpi) as p97
    from ELDER.collated
)
update ELDER.collated
set dpi_wins = 
    case 
        when dpi > (select p97 from percentile_calc) then (select p97 from percentile_calc)
        else dpi
    end; --488

--Winsorise below 3rd percentile - the 'else' changes to the winsorised variable to keep the top 3% winsorised from the previous code whilst the bottom 3% are winsorised
with percentile_calc as (
    select percentile_cont(0.03) within group (order by dpi) as p03
    from ELDER.collated
)
update ELDER.collated
set dpi_wins = 
    case 
        when dpi < (select p03 from percentile_calc) then (select p03 from percentile_calc)
		else dpi_wins
    end; --488

--check winsorised correctly
select dpi, dpi_wins
from ELDER.collated
order by 2 desc, 1 desc;

--Winsorise Deprivation

--Winsorise above 97th percentile
with percentile_calc as (
    select percentile_cont(0.97) within group (order by idaopi2019) as p97
    from ELDER.collated
)
update ELDER.collated
set idaopi2019_wins = 
    case 
        when idaopi2019 > (select p97 from percentile_calc) then (select p97 from percentile_calc)
        else idaopi2019
    end; --488

--Winsorise below 3rd percentile - the 'else' changes to the winsorised variable to keep the top 3% winsorised from the previous code whilst the bottom 3% are winsorised
with percentile_calc as (
    select percentile_cont(0.03) within group (order by idaopi2019) as p03
    from ELDER.collated
)
update ELDER.collated
set idaopi2019_wins = 
    case 
        when idaopi2019 < (select p03 from percentile_calc) then (select p03 from percentile_calc)
		else idaopi2019_wins
    end; --488

--check winsorised correctly
select idaopi2019, idaopi2019_wins
from ELDER.collated
order by 2 desc, 1 desc;

--Winsorise Living Arrangements

--Winsorise above 97th percentile
with percentile_calc as (
    select percentile_cont(0.97) within group (order by hh_one_person_o66_pc) as p97
    from ELDER.collated
)
update ELDER.collated
set hh_one_person_o66_pc_wins = 
    case 
        when hh_one_person_o66_pc > (select p97 from percentile_calc) then (select p97 from percentile_calc)
        else hh_one_person_o66_pc
    end; --488

--Winsorise below 3rd percentile - the 'else' changes to the winsorised variable to keep the top 3% winsorised from the previous code whilst the bottom 3% are winsorised
with percentile_calc as (
    select percentile_cont(0.03) within group (order by hh_one_person_o66_pc) as p03
    from ELDER.collated
)
update ELDER.collated
set hh_one_person_o66_pc_wins = 
    case 
        when hh_one_person_o66_pc < (select p03 from percentile_calc) then (select p03 from percentile_calc)
		else hh_one_person_o66_pc_wins
    end; --488

--check winsorised correctly
select hh_one_person_o66_pc, hh_one_person_o66_pc_wins
from ELDER.collated
order by 2 desc, 1 desc;

------------------
--NORMALISATION - and polarity reversal where necessary
------------------

--add columns for normalised data
alter table ELDER.collated 
add column education_norm real,
add column liv_arr_norm real,
add column digital_exclusion_norm real,
add column health_norm real,
add column deprivation_norm real,
add column car_access_norm real,
add column public_transport_access_norm real;

--Digital Exclusion
--find max
select dpi_wins from ELDER.collated order by 1 asc;
select max(dpi_wins)
from ELDER.collated;

--update 
update ELDER.collated
set digital_exclusion_norm = (dpi_wins - (select min(dpi_wins) from ELDER.collated)) / ((select max(dpi_wins) from ELDER.collated) - (select min(dpi_wins) from ELDER.collated)); --488

--reverse polarity
update ELDER.collated set digital_exclusion_norm = 1 - digital_exclusion_norm;

--check
select dpi_wins, digital_exclusion_norm from ELDER.collated order by 1;

--Living Arrangements
--find max
select hh_one_person_o66_pc_wins from ELDER.collated order by 1 asc;
select max(hh_one_person_o66_pc_wins)
from ELDER.collated;

--update 
update ELDER.collated
set liv_arr_norm = (hh_one_person_o66_pc_wins - (select min(hh_one_person_o66_pc_wins) from ELDER.collated)) / ((select max(hh_one_person_o66_pc_wins) from ELDER.collated) - (select min(hh_one_person_o66_pc_wins) from ELDER.collated)); --488

--check
select hh_one_person_o66_pc_wins, liv_arr_norm from ELDER.collated order by 1;

--Health
--find max
select o65_health_b_vb_pc_wins from ELDER.collated order by 1 asc;
select max(o65_health_b_vb_pc_wins)
from ELDER.collated;

--update 
update ELDER.collated
set health_norm = (o65_health_b_vb_pc_wins - (select min(o65_health_b_vb_pc_wins) from ELDER.collated)) / ((select max(o65_health_b_vb_pc_wins) from ELDER.collated) - (select min(o65_health_b_vb_pc_wins) from ELDER.collated)); --488

--check
select o65_health_b_vb_pc_wins, health_norm from ELDER.collated order by 1;

--Deprivation
--find max
select idaopi2019_wins from ELDER.collated order by 1 asc;
select max(idaopi2019_wins)
from ELDER.collated;

--update 
update ELDER.collated
set deprivation_norm = (cast(idaopi2019_wins as real) - (select min(cast(idaopi2019_wins as real)) from ELDER.collated)) / ((select max(cast(idaopi2019_wins as real)) from ELDER.collated) - (select min(cast(idaopi2019_wins as real)) from ELDER.collated)); --488

--check 
select idaopi2019_wins, deprivation_norm from ELDER.collated order by 1;

--Public Transport Access

--find max
select num_nodes_per_k_o65_wins from ELDER.collated order by 1 asc;
select max(num_nodes_per_k_o65_wins)
from ELDER.collated;

--update 
update ELDER.collated
set public_transport_access_norm = (num_nodes_per_k_o65_wins - (select min(num_nodes_per_k_o65_wins) from ELDER.collated)) / ((select max(num_nodes_per_k_o65_wins) from ELDER.collated) - (select min(num_nodes_per_k_o65_wins) from ELDER.collated)); --488

--reverse polarity
update ELDER.collated
set public_transport_access_norm = 1 - public_transport_access_norm;

--check
select num_nodes_per_k_o65_wins, public_transport_access_norm from ELDER.collated order by 1;

--Car Access
--find max
select hh_one_person_o66_nocar_pc_wins from ELDER.collated order by 1 asc;
select max(hh_one_person_o66_nocar_pc_wins)
from ELDER.collated;

--update 
update ELDER.collated
set car_access_norm = (hh_one_person_o66_nocar_pc_wins - (select min(hh_one_person_o66_nocar_pc_wins) from ELDER.collated)) / ((select max(hh_one_person_o66_nocar_pc_wins) from ELDER.collated) - (select min(hh_one_person_o66_nocar_pc_wins) from ELDER.collated)); --488

--check
select hh_one_person_o66_nocar_pc_wins, car_access_norm from ELDER.collated order by 1;

--Education
--find max
select o65_noqual_pc_wins from ELDER.collated order by 1 asc;
select max(o65_noqual_pc_wins)
from ELDER.collated;

--update 
update ELDER.collated
set education_norm = (o65_noqual_pc_wins - (select min(o65_noqual_pc_wins) from ELDER.collated)) / ((select max(o65_noqual_pc_wins) from ELDER.collated) - (select min(o65_noqual_pc_wins) from ELDER.collated)); --488

--check
select o65_noqual_pc_wins, education_norm from ELDER.collated order by 1;


--check all
select num_nodes_per_k_o65, num_nodes_per_k_o65_wins, public_transport_access_norm from ELDER.collated order by 3 asc;
select o65_health_b_vb_pc, o65_health_b_vb_pc_wins, health_norm from ELDER.collated order by 3 desc;
select dpi, dpi_wins, digital_exclusion_norm from ELDER.collated order by 3 desc;
select hh_one_person_o66_pc, hh_one_person_o66_pc_wins, liv_arr_norm from ELDER.collated order by 3 desc;
select idaopi2019, idaopi2019_wins, deprivation_norm from ELDER.collated order by 3 desc;
select hh_one_person_o66_nocar_pc, hh_one_person_o66_nocar_pc_wins, car_access_norm from ELDER.collated order by 3 asc;
select o65_noqual_pc, o65_noqual_pc_wins, education_norm from ELDER.collated order by 3 desc;

---------------------------------------
--COMBINED TRANSPORT ACCESS VARIABLE
---------------------------------------

--add a column for new transport access variable
alter table ELDER.collated add column transport_access real;

update ELDER.collated set transport_access = ((0.5*car_access_norm)+(0.5*public_transport_access_norm)); --488

select transport_access, car_access_norm, public_transport_access_norm from ELDER.collated;

--Min-Max normalised 0 to 1
--add a new column for normalised score
alter table ELDER.collated add column transport_access_norm real;

--update column
update ELDER.collated
set transport_access_norm = (transport_access_norm - (select min(transport_access_norm) from ELDER.collated)) / ((select max(transport_access_norm) from ELDER.collated) - (select min(transport_access_norm) from ELDER.collated)); --488

--Check
select car_access_norm, public_transport_access_norm, transport_access_norm from ELDER.collated;

------------------------------
--CREATE A FINAL INDEX SCORE
------------------------------

--add a new column for final index score
alter table ELDER.collated 
add column loneliness_index real;

--simple aggregation
update ELDER.collated
set loneliness_index = education_norm + deprivation_norm + liv_arr_norm + digital_exclusion_norm + health_norm + transport_access_norm; --488

--now create a normalised loneliness index score
--add column
alter table ELDER.collated
add column ELDER_index real;

--update - normalise 0 to 100
update ELDER.collated
set ELDER_index = ((loneliness_index - (select min(loneliness_index) from ELDER.collated)) / ((select max(loneliness_index) from ELDER.collated) - (select min(loneliness_index) from ELDER.collated))*100); --488

--check
select loneliness_index, ELDER_index from ELDER.collated order by 1;

-----------
--RESULTS
-----------

--------------------------------Age UK Loneliness Index comparison-----------------------------------

--Assigning 2011 to 2021 LSOAs is done in Microsoft Excel prior to loading the data

--create new table to hold Age UK index
create table ELDER.age_uk_index
(
lsoa21cd varchar,
odds_ratio real
);

--copy Age UK index from csv
copy ELDER.age_uk_index
from 'C:\tmp\Age UK Loneliness Index Leeds.csv'
csv header delimiter ','; --488

--normalise 0 to 100
--add column
alter table ELDER.age_uk_index
add column odds_ratio_norm real;

--update column
update ELDER.age_uk_index
set odds_ratio_norm = ((odds_ratio - (select min(odds_ratio) from ELDER.age_uk_index)) / ((select max(odds_ratio) from ELDER.age_uk_index) - (select min(odds_ratio) from ELDER.age_uk_index))*100); --488
--488

--check
select odds_ratio, odds_ratio_norm
from ELDER.age_uk_index
order by 2;

--add columns to collated table
alter table ELDER.collated 
add column age_uk_index real,
add column age_uk_index_norm real;

--update columns in collated table
update ELDER.collated a
set age_uk_index = b.odds_ratio, 
age_uk_index_norm = b.odds_ratio_norm
from ELDER.age_uk_index b
where a.lsoa21cd=b.lsoa21cd; --488

--add a 'difference' column to collated table
alter table ELDER.collated
add column validate_diff real;

--update difference column
update ELDER.collated 
set validate_diff = ELDER_index - age_uk_index_norm; --488

--check
select lsoa21cd, loneliness_index, ELDER_index, age_uk_index, age_uk_index_norm, validate_diff
from ELDER.collated order by 6;

--get standard deviation of difference between two indices
select stddev(validate_diff) from ELDER.collated; --14.97

--get distributions by standard deviations away from 0
select count(*) from ELDER.collated where validate_diff between -14.97 and 14.97; --330
select count(*) from ELDER.collated where validate_diff between -29.94 and -14.97; -- 28
select count(*) from ELDER.collated where validate_diff < -29.94; -- 11
select count(*) from ELDER.collated where validate_diff between 14.97 and 29.94; -- 109
select count(*) from ELDER.collated where validate_diff > 29.94; -- 10

--get data for scatter plot
select lsoa21cd, ELDER_index, age_uk_index_norm
from ELDER.collated;

--check outlier
select ELDER_index, age_uk_index_norm, education_norm, deprivation_norm, liv_arr_norm, digital_exclusion_norm, health_norm, transport_access_norm
from ELDER.collated
where lsoa21cd = 'E01033034';
