-- -------------------------------------------
-- - Insertion Script - FSDB Assignment 2025 -
-- -------------------------------------------
-- -------------------------------------------

-- heal books data, grouping by pk and projecting min
INSERT INTO books(TITLE,AUTHOR,COUNTRY,LANGUAGE,PUB_DATE,ALT_TITLE,TOPIC,CONTENT,AWARDS)
SELECT DISTINCT trim(TITLE),trim(MAIN_AUTHOR),min(trim(PUB_COUNTRY)),min(trim(ORIGINAL_LANGUAGE)),
       min(to_number(PUB_DATE)),min(trim(ALT_TITLE)),min(trim(TOPIC)),min(trim(CONTENT_NOTES)),min(trim(AWARDS))
FROM fsdb.acervus group by title,main_author
;
-- 181435 rows
commit;

--

INSERT INTO More_Authors(TITLE,MAIN_AUTHOR,ALT_AUTHORS,MENTIONS)
SELECT DISTINCT trim(TITLE),trim(MAIN_AUTHOR),trim(OTHER_AUTHORS),max(trim(MENTION_AUTHORS)) 
FROM fsdb.acervus where trim(OTHER_AUTHORS) is not null group by (trim(TITLE),trim(MAIN_AUTHOR),trim(OTHER_AUTHORS))
;

-- 23333 rows

--

-- same isbn can take different nat_lib_id; group by pk and project min
INSERT INTO Editions(ISBN,TITLE,AUTHOR,LANGUAGE,ALT_LANGUAGES,EDITION,PUBLISHER,EXTENSION,
       SERIES,COPYRIGHT,PUB_PLACE,DIMENSIONS,PHY_FEATURES,MATERIALS,NOTES,NATIONAL_LIB_ID,URL)
SELECT DISTINCT trim(ISBN),min(trim(TITLE)),min(trim(MAIN_AUTHOR)),nvl(min(trim(MAIN_LANGUAGE)),'Spanish'),
       min(trim(OTHER_LANGUAGES)),min(trim(EDITION)),min(trim(PUBLISHER)),min(trim(EXTENSION)),min(trim(SERIES)),
       min(trim(COPYRIGHT)),min(trim(PUB_PLACE)),min(trim(DIMENSIONS)),min(trim(PHYSICAL_FEATURES)),
       min(trim(ATTACHED_MATERIALS)),min(trim(NOTES)),min(trim(NATIONAL_LIB_ID)),min(trim(URL)) 
FROM fsdb.acervus group by trim(isbn)
;
-- 240632 rows

commit;

--

-- one copy with null pk (skip it & document)
INSERT INTO Copies(SIGNATURE,ISBN)
SELECT DISTINCT trim(SIGNATURE),trim(ISBN)
FROM fsdb.acervus where signature is not null
;
-- 241572 rows
commit;

--

INSERT INTO municipalities (TOWN,PROVINCE,POPULATION)
SELECT DISTINCT trim(TOWN),trim(PROVINCE),trim(POPULATION)
FROM fsdb.busstops
;
-- 1365 rows
--

INSERT INTO routes (ROUTE_ID)
SELECT DISTINCT trim(ROUTE_ID)
FROM fsdb.busstops
;
-- 150 rows
--

-- there is an invalid date (29-02-1970); split into two cases
INSERT INTO drivers (PASSPORT,EMAIL,FULLNAME,BIRTHDATE,PHONE,ADDRESS,CONT_START,CONT_END)
SELECT DISTINCT trim(LIB_PASSPORT),trim(LIB_EMAIL),trim(LIB_FULLNAME),to_date(LIB_BIRTHDATE,'DD-MM-YYYY'),
       to_number(LIB_PHONE),trim(LIB_ADDRESS),to_date(CONT_START,'DD.MM.YYYY'),to_date(CONT_END,'DD.MM.YYYY')
FROM fsdb.busstops where lib_birthdate!='29-02-1970'
;
-- 12 rows
INSERT INTO drivers (PASSPORT,EMAIL,FULLNAME,BIRTHDATE,PHONE,ADDRESS,CONT_START,CONT_END)
SELECT DISTINCT trim(LIB_PASSPORT),trim(LIB_EMAIL),trim(LIB_FULLNAME),to_date('01-03-1970','DD-MM-YYYY'),
       to_number(LIB_PHONE),trim(LIB_ADDRESS),to_date(CONT_START,'DD.MM.YYYY'),to_date(CONT_END,'DD.MM.YYYY')
FROM fsdb.busstops where lib_birthdate='29-02-1970'
;
-- 1 row

-- several last-itv dates for each bus; the later (max) will be taken as valid
INSERT INTO bibuses(PLATE,LAST_ITV,NEXT_ITV)
SELECT p, max(l), min (n) FROM
(SELECT trim(PLATE) p, to_date(trim(LAST_ITV),'DD.MM.YYYY // HH24:MI:SS') l, to_date(trim(NEXT_ITV),'DD.MM.YYYY') n
        FROM fsdb.busstops) group by p
;
-- 14 rows

INSERT INTO assign_drv (PASSPORT,TASKDATE,ROUTE_ID)
SELECT DISTINCT trim(LIB_PASSPORT),to_date(STOPDATE,'DD-MM-YYYY'),trim(ROUTE_ID)
FROM fsdb.busstops
;
-- 150 rows

INSERT INTO assign_bus (PLATE,TASKDATE,ROUTE_ID)
SELECT DISTINCT trim(PLATE),to_date(STOPDATE,'DD-MM-YYYY'),trim(ROUTE_ID)
FROM fsdb.busstops
;
-- 150 rows

-- stoptime with minute granularity
INSERT INTO stops (TOWN,PROVINCE,ADDRESS,ROUTE_ID,STOPTIME)
SELECT DISTINCT trim(TOWN),trim(PROVINCE),trim(ADDRESS),trim(ROUTE_ID),
       to_number(substr(STOPTIME,1,2))*60+to_number(substr(STOPTIME,4,2))
FROM fsdb.busstops
;
-- 1365 rows

INSERT INTO services (TOWN,PROVINCE,BUS,TASKDATE,PASSPORT)
SELECT DISTINCT trim(TOWN),trim(PROVINCE),trim(PLATE),to_date(STOPDATE,'DD-MM-YYYY'),trim(LIB_PASSPORT)
FROM fsdb.busstops
;
-- 1365 rows
commit;

--

-- some users appear to be in several towns; solution: skip&doc 
-- (or heal by imp. sem assumption: assume first one is the valid, so keep first)
--skip BAN_UP2 to take null value

INSERT INTO users (USER_ID,ID_CARD,NAME,SURNAME1,SURNAME2,BIRTHDATE,
                         TOWN,PROVINCE,ADDRESS,EMAIL,PHONE,TYPE)
SELECT a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 
FROM (SELECT a1, a2, a3, a4, a5, a6, town a7, a8, a9, a10, a11, a12, row_number() over (partition by a1 order by null) rn
         FROM (SELECT DISTINCT trim(USER_ID) a1, trim(PASSPORT) a2, trim(NAME) a3, trim(SURNAME1) a4, trim(SURNAME2) a5,
                  to_date(BIRTHDATE,'DD/MM/YYYY') a6, trim(TOWN) town, to_date(substr(DATE_TIME,1,10),'DD/MM/YYYY') taskdate, 
                  trim(ADDRESS) a9, trim(EMAIL) a10, to_number(PHONE) a11 FROM fsdb.loans ) a
               JOIN (SELECT DISTINCT trim(TOWN) town,trim(PROVINCE) a8,to_date(STOPDATE,'DD-MM-YYYY') taskdate,
                            DECODE(HAS_LIBRARY,'Y','L','N','P') a12 FROM fsdb.busstops) b 
               using (town,taskdate) 
     )
WHERE rn=1;
-- 2771 rows


--time in minutes
INSERT INTO loans (SIGNATURE,USER_ID,STOPDATE,TOWN,PROVINCE,TYPE,TIME,RETURN)
SELECT * FROM (
   SELECT DISTINCT trim(l.SIGNATURE) c1,trim(USER_ID),to_date(substr(l.DATE_TIME,1,10),'DD/MM/YYYY') s1,trim(u.TOWN) s2,trim(u.PROVINCE) s3,
          'L', to_number(substr(DATE_TIME,13,2))*60+to_number(substr(DATE_TIME,16,2)), to_date(l.RETURN,'DD/MM/YYYY  HH24:MI:SS') 
      FROM users u JOIN fsdb.loans l using (user_ID) )
where (s1,s2,s3) in (select taskdate, town, province from services)
      and c1 in (select signature from copies);
-- 23709 rows

INSERT INTO posts (SIGNATURE,USER_ID,STOPDATE,POST_DATE,TEXT,LIKES,DISLIKES)
SELECT * FROM (
   SELECT DISTINCT trim(SIGNATURE) p1, trim(USER_ID) p2, to_date(substr(DATE_TIME,1,10),'DD/MM/YYYY') p3, 
          to_date(POST_DATE,'DD/MM/YYYY  HH24:MI:SS'),trim(POST) text,to_number(LIKES),to_number(DISLIKES)
      FROM fsdb.loans) 
where TEXT is not null AND (p1,p2,p3) in (select signature, user_id,stopdate from loans);
-- 5447 rows

commit;

