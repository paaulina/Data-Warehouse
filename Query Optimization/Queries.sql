-- SQL script for obtaining KPIs (filtering taken from LearnSQL Physical DW design - assignment QUIZ)
-- Costs values taken from Exacution plan (Shift+Control+E) in DBeaver

---------------- INDEXES ----------------------

--Indexes with better costs reduction (not accepted in QUIZ):

CREATE INDEX aircraft_index        -- reduces cost of obtaining FH, FC, ADOSS and ADOSU 
ON AIRCRAFTUTILIZATION(AIRCRAFTID);

CREATE INDEX logbook_aircraftid    --reduces cost of obtaining RRh, RRc, PRRh, PRRc, MRRh and MRRc 
ON LOGBOOKREPORTING(AIRCRAFTID);

CREATE INDEX logbook_personid      -- reduces cost of obtaining MRRh and MRR
ON LOGBOOKREPORTING(PERSONID);

-- Bitmap indexes with worse costs reduction but using LESS BLOCKS (still not accepted by LearnSQL QUIZ): 

CREATE BITMAP INDEX AU_AD
ON AIRCRAFTUTILIZATION( AD.MODEL )
FROM AIRCRAFTUTILIZATION AU, AIRCRAFTDIMENSION AD
WHERE AU.AIRCRAFTID = AD.ID PCTFREE 0;

CREATE BITMAP INDEX AIRCRAFT_INDEX ON AIRCRAFTUTILIZATION(AIRCRAFTID);

CREATE BITMAP INDEX LR_AD
ON LOGBOOKREPORTING( AD.MODEL )
FROM LOGBOOKREPORTING LR, AIRCRAFTDIMENSION AD
WHERE LR.AIRCRAFTID = AD.ID PCTFREE 0;

CREATE BITMAP INDEX LR_PD
ON LOGBOOKREPORTING( PD.airport )
FROM LOGBOOKREPORTING LR, PeopleDimension PD
WHERE LR.PERSONID = PD.ID PCTFREE 0;

----------------- KPIs -----------------------
SELECT TD.monthid, 									--Initial cost: 656, cost after creating aircraft_index: 162/170 (BTREE/BITMAP)
       Sum(AU.flighthours)  AS FH, 
       Sum(AU.flightcycles) AS FC 
FROM   aircraftutilization AU, 
	   temporaldimension TD, 
       aircraftdimension AD
WHERE  AU.aircraftid = AD.id 
       AND AU.timeid = TD.id 
       AND AD.model = '777' 
GROUP  BY TD.monthid
ORDER  BY TD.monthid; 

SELECT M.Y,											--Initial cost: 652, cost after creating aircraft_index: 58/141 (BTREE/BITMAP)
	   Sum(AU.scheduledoutofservice)   AS ADOSS, 
       Sum(AU.unscheduledoutofservice) AS ADOSU 
FROM   aircraftutilization AU, 
       months M, 
       temporaldimension TD 
WHERE  M.id = TD.monthid 
       AND AU.timeid = TD.id 
       AND AU.aircraftid = 'XY-WTR' 
GROUP  BY M.y; 



SELECT LR.monthid, 											--Initial cost: 2123, cost after creating logbook_aircraftid index: 457/543 (BTREE/BITMAP)
       1000 * ( marep + pirep ) / fh AS RRh, 
       100 * ( marep + pirep ) / fc  AS RRc, 
       1000 * pirep / fh             AS PRRh, 
       100 * pirep / fc              AS PRRc, 
       1000 * marep / fh             AS MRRh, 
       100 * marep / fc              AS MRRc 
FROM   (SELECT TD.monthid, 
               Sum(AU.flighthours)  AS FH, 
               Sum(AU.flightcycles) AS FC 
        FROM   temporaldimension TD, 
               aircraftdimension AD, 
               aircraftutilization AU 
        WHERE  AU.aircraftid = AD.id 
               AND AU.timeid = TD.id 
               AND AD.model = '777' 
        GROUP  BY TD.monthid) AU, 
       (SELECT L.monthid, 
               Sum(CASE 
                     WHEN PD.role = 'M' THEN L.counter 
                     ELSE 0 
                   END) AS MAREP, 
               Sum(CASE 
                     WHEN PD.role = 'P' THEN L.counter 
                     ELSE 0 
                   END) AS PIREP 
        FROM   logbookreporting L, 
               aircraftdimension AD, 
               peopledimension PD 
        WHERE  L.aircraftid = AD.id 
               AND PD.id = L.personid 
               AND AD.model = '777' 
        GROUP  BY L.monthid) LR
WHERE  AU.monthid = LR.monthid;



SELECT LR.model, 							--Initial cost: 2385, cost after creating logbook_personid index: 560/784 (BTREE/BITMAP)
       1000 * marep / fh AS MRRh, 
       100 * marep / fc  AS MRRc 
FROM   (SELECT AD.model, 
               Sum(AU.flighthours)  AS FH, 
               Sum(AU.flightcycles) AS FC 
        FROM   aircraftdimension AD, 
               aircraftutilization AU 
        WHERE  AU.aircraftid = AD.id 
        GROUP  BY AD.model) AU, 
        
       (SELECT AD.model, 
               Sum(CASE WHEN PD.role = 'M' THEN L.counter ELSE 0 END) AS MAREP
        FROM   logbookreporting L, 
               aircraftdimension AD, 
               peopledimension PD 
        WHERE  L.aircraftid = AD.id 
               AND PD.airport = 'KRS' 
               AND PD.id = L.personid 
        GROUP  BY AD.model) LR 
        
WHERE  AU.model = LR.model; 

