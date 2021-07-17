-- SQLite, Dbeaver

/* PREPARATION */
-- getting overview of data, amount of data, datatypes

-- dailyActivity_merged is merged data of dailyCalories, dailyIntensities, dailySteps

SELECT *
FROM dailyActivity_merged_csv

PRAGMA table_info(dailyActivity_merged_csv)

SELECT DISTINCT Id FROM dailyActivity_merged_csv

SELECT COUNT(DISTINCT Id) FROM dailyCalories_merged_csv
SELECT COUNT(DISTINCT Id) FROM dailyIntensities_merged_csv
SELECT COUNT(DISTINCT Id) FROM dailySteps_merged_csv
-- Unique values for Id in dailyActivity_merged.csv : 33
-- Unique values for Id in dailyCalories_merged.csv : 33
-- Unique values for Id in dailyIntensities_merged.csv : 33
-- Unique values for Id in dailySteps_merged_csv : 33

SELECT COUNT(DISTINCT Id) FROM hourlyCalories_merged_csv 
SELECT COUNT(DISTINCT Id) FROM hourlyIntensities_merged_csv
SELECT COUNT(DISTINCT Id) FROM hourlySteps_merged_csv
SELECT COUNT(DISTINCT Id) FROM minuteCaloriesNarrow_merged_csv
SELECT COUNT(DISTINCT Id) FROM minuteIntensitiesNarrow_merged_csv 
SELECT COUNT(DISTINCT Id) FROM minuteMETsNarrow_merged_csv 
SELECT COUNT(DISTINCT Id) FROM minuteStepsNarrow_merged_csv
-- Unique values for Id for tables^ : 33

-- identifying incomplete data

SELECT COUNT(DISTINCT Id) FROM minuteSleep_merged_csv
--  Unique values for Id in minuteSleep_merged_csv : 24
SELECT COUNT(DISTINCT Id) FROM sleepDay_merged_csv
--  Unique values for Id in sleepDay_merged_csv : 24
SELECT COUNT(DISTINCT Id) FROM heartrate_seconds_merged_csv 
--  Unique values for Id in heartrate_seconds_merged_csv : 14
SELECT COUNT(DISTINCT Id) FROM weightLogInfo_merged_csv
--  Unique values for Id in weightLogInfo_merged_csv : 8

-- SQLite has limitations for ALTER TABLE, cant modify column datatype
-- need to create new table, 
-- CREATE TABLE tmp_table AS SELECT id, name FROM src_table

ALTER TABLE dailyActivity_merged_csv 
ALTER COLUMN activityDate date; 

------------------------------------------------------------------------------------------

/* CLEANING */
-- Mispellings, extra spaces & characters, nulls, negative values, duplicates, inconsistent data

-- Removing NULLS

SELECT COUNT(*) AS calories_count
FROM dailyActivity_merged_csv 
WHERE Calories IS NULL 

-- Removing calories with value 0

SELECT COUNT(*) AS calories_zero
FROM dailyActivity_merged_csv 
WHERE Calories = 0

DELETE FROM dailyActivity_merged_csv 
WHERE Calories = 0
-- 4 rows deleted

-- Removing total distance with value 0

SELECT COUNT(*) AS total_distance_zero
FROM dailyActivity_merged_csv 
WHERE TotalDistance = 0

DELETE FROM dailyActivity_merged_csv 
WHERE TotalDistance = 0
-- 74 rows deleted

-- Removing rows where total distance is not equal to tracked distance 

SELECT * 
FROM dailyActivity_merged_csv
WHERE TotalDistance != TrackerDistance

DELETE FROM dailyActivity_merged_csv 
WHERE TotalDistance != TrackerDistance
-- 15 rows deleted

------------------------------------------------------------------------------------------

/* ANALYZE */

-- Joining dailyCalories_merged_csv with dailyIntensities_merged_csv, dailySteps_merged_csv, sleepDay_merged_csv
 	--check against dailyActivity_merged_csv
 	
SELECT A.Id, A.Calories,  A.TotalSteps, A.TotalDistance, A.TrackerDistance, A.LoggedActivitiesDistance,
       SD.TotalSleepRecords, SD.TotalMinutesAsleep, SD.TotalTimeInBed, I.SedentaryMinutes, I.LightlyActiveMinutes, 
       I.FairlyActiveMinutes,I.VeryActiveMinutes, I.SedentaryActiveDistance, I.LightActiveDistance, 
       I.ModeratelyActiveDistance, I.VeryActiveDistance,
COALESCE(sd.TotalSleepRecords, 0) AS TotalSleepRecords_zero,
COALESCE(sd.TotalMinutesAsleep, 0) AS TotalMinutesAsleep_zero,
COALESCE(sd.TotalTimeInBed, 0) AS TotalTimeInBed_zero
	FROM dailyActivity_merged_csv A
	LEFT JOIN dailyCalories_merged_csv C
	ON A.Id = C.Id
		AND A.ActivityDate = C.ActivityDay
 		AND A.Calories = C.Calories
	LEFT JOIN dailyIntensities_merged_csv I
    ON A.Id = I.Id
 		AND A.ActivityDate=I.ActivityDay
 		AND A.FairlyActiveMinutes = I.FairlyActiveMinutes
 		AND A.LightActiveDistance = I.LightActiveDistance
 		AND A.LightlyActiveMinutes = I.LightlyActiveMinutes
 		AND A.ModeratelyActiveDistance = I.ModeratelyActiveDistance
 		AND A.SedentaryActiveDistance = I.SedentaryActiveDistance
 		AND A.SedentaryMinutes = I.SedentaryMinutes
 		AND A.VeryActiveDistance = I.VeryActiveDistance
 		AND A.VeryActiveMinutes = I.VeryActiveMinutes
	LEFT JOIN dailySteps_merged_csv S
	ON A.Id = S.Id
 		AND A.ActivityDate=S.ActivityDay
	LEFT JOIN sleepDay_merged_csv SD
	ON A.Id = SD.Id
 		AND A.ActivityDate=SD.SleepDay	  

 -- Joining dailyActivity_merged_csv & weightLogInfo_merged_csv 

SELECT damc.Id, damc.ActivityDate, damc.TotalSteps, damc.TotalDistance, damc.TrackerDistance, damc.LoggedActivitiesDistance,
	   damc.VeryActiveDistance, damc.ModeratelyActiveDistance, damc.LightActiveDistance, damc.SedentaryActiveDistance, damc.VeryActiveMinutes,
       damc.FairlyActiveMinutes, damc.LightlyActiveMinutes, damc.SedentaryMinutes, damc.Calories, wlimc.WeightKg, wlimc.Fat, wlimc.BMI, 
       wlimc.IsManualReport,
COALESCE(wlimc.WeightKg, 0) AS Weight_in_kg,
COALESCE(wlimc.Fat, 0) AS Fat_new,
COALESCE(wlimc.BMI, 0) AS BMI_new,
COALESCE(wlimc.IsManualReport, 0) AS Mutual_report_new
	FROM dailyActivity_merged_csv damc
	LEFT JOIN weightLogInfo_merged_csv wlimc
 	ON damc.Id = wlimc .Id
 	ORDER BY wlimc.WeightKg DESC
 
  -- Steps in a day
 
 SELECT CONVERT(time, ActivityHour) AS time_of_intensity
FROM hourlyIntensities_merged_csv himc 

ALTER TABLE hourlyIntensities_merged_csv 
ADD time_of_intensity time;

UPDATE dailyActivity_merged_csv
SET time_of_intensity = CONVERT(time, ActivityHour)

WITH Total_steps AS
( SELECT Id ,ActivityHour, time_of_intensity,
    CASE
   WHEN time_of_intensity BETWEEN '06:00:00' AND '11:00:00' THEN 'Morning'
   WHEN time_of_intensity BETWEEN '12:00:00' AND '16:00:00' THEN 'Afternoon'
   WHEN time_of_intensity BETWEEN '17:00:00' AND '21:00:00' THEN 'Evening'
   ELSE 'Night'
   END AS day_time
 FROM hourlyIntensities_merged_csv    
  GROUP BY Id, ActivityHour, time_of_intensity)            
SELECT *
FROM hourlySteps_merged_csv
ORDER BY ActivityHour DESC

-- Time of day, day of week & intensities

 SELECT CONVERT(time, ActivityHour) AS time_of_intensity
FROM hourlyIntensities_merged_csv himc 

ALTER TABLE hourlyIntensities_merged_csv 
ADD time_of_intensity time;

UPDATE hourlyIntensities_merged_csv 
SET time_of_intensity = CONVERT(time, ActivityHour)

 WITH Intensity_time AS (
 SELECT Id, ActivityHour, time_of_intensity,
 		STRFTIME('%A', ActivityHour) day_of_week,
 CASE 
   WHEN STRFTIME('%A', ActivityHour) != 'Saturday' AND    -- != this sign is for not equal to
        STRFTIME('%A', ActivityHour) != 'Sunday' THEN 'Weekday'
   ELSE 'Weekend'
END AS part_of_week,
   CASE
   	WHEN time_of_intensity BETWEEN '06:00:00' AND '11:00:00' THEN 'Morning'
   	WHEN time_of_intensity BETWEEN '12:00:00' AND '16:00:00' THEN 'Afternoon'
  	WHEN time_of_intensity BETWEEN '17:00:00' AND '24:00:00' THEN 'Evening'
   	ELSE 'Night'
END AS day_time,
   SUM(TotalIntensity) AS total_intensity,
   SUM(AverageIntensity) AS total_average_intensity,
   AVG(AverageIntensity) AS average_intensity,
   MAX(AverageIntensity) AS max_intensity,
   MIN(AverageIntensity) AS min_intensity
FROM hourlyIntensities_merged_csv
 	GROUP BY Id, ActivityHour, STRFTIME('%A', ActivityHour), time_of_intensity)
SELECT *
 FROM Intensity_time
 ORDER BY ActivityHour DESC
 
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------

/* FINDINGS */


------------------------------------------------------------------------------------------

/* RECOMMENDATIONS based on SQL & Tableau */
 

------------------------------------------------------------------------------------------

