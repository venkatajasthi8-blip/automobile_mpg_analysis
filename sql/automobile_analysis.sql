-- Create a separate database just for this project
CREATE DATABASE IF NOT EXISTS automobile_project;

-- Tell MySQL to use it for everything I run next
USE automobile_project;

-- Same columns, in the same order as automobile_clean.csv
CREATE TABLE automobile (
-- Data loaded from automobile_clean.csv using the Table Data Import Wizard
    car_id         INT PRIMARY KEY,
    name           VARCHAR(100),
    mpg            DECIMAL(10,2),
    cylinders      INT,
    displacement   DECIMAL(10,1),
    horsepower     DECIMAL(10,1),
    weight         INT,
    acceleration   DECIMAL(10,1),
    model_year     INT,
    origin         VARCHAR(20),
    brand          VARCHAR(30),
    year           INT,
    era            VARCHAR(40),
    l_per_100km    DECIMAL(10,2),
    weight_kg      DECIMAL(10,2),
    is_diesel      INT,
    expected_mpg   DECIMAL(10,2),
    efficiency_gap DECIMAL(10,2),
    on_frontier    INT
);


USE automobile_project;

SELECT COUNT(*) AS total_cars, SUM(on_frontier) AS frontier_cars FROM automobile;

--  missing values in the main columns
SELECT COUNT(*) - COUNT(mpg)            AS missing_mpg,
       COUNT(*) - COUNT(horsepower)     AS missing_horsepower,
       COUNT(*) - COUNT(weight_kg)      AS missing_weight,
       COUNT(*) - COUNT(efficiency_gap) AS missing_gap
FROM automobile;

-- do the categories look right? 
SELECT origin, era, COUNT(*) AS cars
FROM automobile
GROUP BY origin, era
ORDER BY origin, era;

-- rebuild the Pareto frontier in SQL and compare with the Python flag
SELECT COUNT(*) AS frontier_cars_in_sql
FROM automobile a
WHERE NOT EXISTS (
    SELECT 1
    FROM automobile b
    WHERE b.year = a.year
      AND b.mpg >= a.mpg
      AND b.horsepower >= a.horsepower
      AND (b.mpg > a.mpg OR b.horsepower > a.horsepower)
);

-- Q1 What did each region give up to gain mpg?
-- Percent change from the first era to the last era
SELECT origin,
	ROUND(AVG(CASE WHEN era = 'Cheap fuel' THEN mpg END), 1) AS mpg_first_era,
    ROUND(AVG(CASE WHEN era = 'Downsizing' THEN mpg END), 1) AS mpg_last_era,
    ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN mpg END)
				/ AVG(CASE WHEN era = 'Cheap fuel' THEN mpg END) - 1), 1) AS mpg_change_pct,
	ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN horsepower END)
				/ AVG(CASE WHEN era = 'Cheap fuel' THEN horsepower END) - 1), 1) AS hp_change_pct,
	ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN weight_kg END)
				/ AVG(CASE WHEN era = 'Cheap fuel' THEN weight_kg END) - 1), 1) AS weight_change_pct
			
FROM automobile
GROUP BY origin;
    
-- Q2 Does high performance cost mpg?
-- Split cars into equal groups by horsepower per tonne (1 = weakest, 4 = most powerful)
WITH performance AS(
	SELECT mpg, efficiency_gap, on_frontier,
			horsepower/(weight_kg/1000) AS hp_per_tonne,
			NTILE(4) OVER (ORDER BY horsepower/(weight_kg/1000)) AS performance_quartile
	FROM automobile
)
SELECT performance_quartile,
		COUNT(*) AS cars,
        ROUND(AVG(hp_per_tonne), 0) AS avg_hp_per_tonne,
        ROUND(AVG(mpg), 1) AS avg_mpg,
        ROUND(AVG(efficiency_gap), 2) AS avg_gap,
        ROUND(100.0*SUM(on_frontier)/COUNT(*), 1) AS frontier_share_pct
FROM performance
GROUP BY performance_quartile
ORDER BY performance_quartile;

-- Q3 Which cars were powerful AND efficient?
-- Best of both = horsepower at or above the average of its model year 
-- and a positive efficiency gap
WITH with_year_avg AS (
	SELECT origin, horsepower, efficiency_gap,
			AVG(horsepower) OVER (PARTITION BY year) AS year_avg_hp
	FROM automobile
)
SELECT origin,
		COUNT(*) AS cars,
		SUM(CASE WHEN horsepower >= year_avg_hp AND efficiency_gap > 0 THEN 1 ELSE 0 END) AS best_of_both,
		ROUND(100.0 * SUM(CASE WHEN horsepower >= year_avg_hp AND efficiency_gap > 0 THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS best_of_both_pct
FROM with_year_avg
GROUP BY origin
ORDER BY best_of_both_pct DESC;

-- Q4 do frontier cars sacrifice drivability?
-- Acceleration is seconds from 0 to 60, so lower means faster
SELECT CASE WHEN on_frontier = 1 THEN 'Frontier' ELSE 'Not frontier' END AS car_group,
		COUNT(*) AS cars,
		ROUND(AVG(horsepower), 0) AS avg_hp,
        ROUND(AVG(acceleration), 1) AS avg_sec_0_to_60,
        ROUND(AVG(weight_kg), 0) AS avg_weight_kg,
        ROUND(AVG(mpg), 1) AS avg_mpg
FROM automobile
GROUP BY on_frontier;

-- Q5 which brands most often beat their peers?
-- Brands with fewer than 8 cars are left out so a few lucky cars cannot decide the ranking
SELECT brand,
		COUNT(*) AS cars,
        ROUND(100.0 * AVG(CASE WHEN efficiency_gap > 0 THEN 1 ELSE 0 END), 1) AS pct_beating_peers,
        ROUND(AVG(efficiency_gap), 2) AS avg_gap
FROM automobile
GROUP BY brand
HAVING COUNT(*) >= 8
ORDER BY pct_beating_peers DESC;

-- Q6 Which brands have the most efficiency to recover?
-- Add up all the negative gaps per brand
SELECT brand,
       COUNT(*) AS cars,
       SUM(CASE WHEN efficiency_gap < 0 THEN 1 ELSE 0 END) AS cars_below_expected,
       ROUND(SUM(CASE WHEN efficiency_gap < 0 THEN efficiency_gap ELSE 0 END), 1) AS total_mpg_shortfall
FROM automobile
GROUP BY brand
HAVING COUNT(*) >= 8
ORDER BY total_mpg_shortfall ASC;

-- Q7 which brands built frontier cars?
SELECT brand,
       COUNT(*) AS cars,
       SUM(on_frontier) AS frontier_cars,
       ROUND(100.0 * SUM(on_frontier) / COUNT(*), 1) AS frontier_share_pct
FROM automobile
GROUP BY brand
HAVING COUNT(*) >= 8
ORDER BY frontier_share_pct DESC;

-- Q8 which engine configuration was the best bet?
-- Careful: the 3 and 5 cylinder groups only have a handful of cars
SELECT cylinders,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 1) AS avg_mpg,
       ROUND(AVG(horsepower), 0) AS avg_hp,
       ROUND(AVG(efficiency_gap), 2) AS avg_gap,
       ROUND(100.0 * SUM(on_frontier) / COUNT(*), 1) AS frontier_share_pct
FROM automobile
GROUP BY cylinders
ORDER BY cylinders;

-- Q9 is weight the whole story?
-- If the gap is close to zero in every weight class, it really removed the weight effect
SELECT CASE WHEN weight_kg < 1100 THEN '1. Light (under 1100 kg)'
            WHEN weight_kg <= 1500 THEN '2. Medium (1100-1500 kg)'
            ELSE '3. Heavy (over 1500 kg)' END AS weight_class,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 1) AS avg_mpg,
       ROUND(AVG(efficiency_gap), 2) AS avg_gap,
       ROUND(100.0 * SUM(on_frontier) / COUNT(*), 1) AS frontier_share_pct
FROM automobile
GROUP BY weight_class
ORDER BY weight_class;

-- Q10 how much fuel did a driver save between the first and last era?
-- 100 x (difference in litres per 100 km) = litres saved per 10,000 km
SELECT origin,
       ROUND(AVG(CASE WHEN era = 'Cheap fuel' THEN l_per_100km END), 1) AS l_per_100km_first_era,
       ROUND(AVG(CASE WHEN era = 'Downsizing' THEN l_per_100km END), 1) AS l_per_100km_last_era,
       ROUND(100 * (AVG(CASE WHEN era = 'Cheap fuel' THEN l_per_100km END)
                  - AVG(CASE WHEN era = 'Downsizing' THEN l_per_100km END)), 0) AS litres_saved_per_10000km
FROM automobile
GROUP BY origin;

-- Q11 is the 1980 jump in mpg real?
-- Compare all cars with US cars only, next to the share of non-US cars in the sample
SELECT year,
       ROUND(AVG(mpg), 1) AS avg_mpg_all_cars,
       ROUND(100.0 * AVG(CASE WHEN origin <> 'usa' THEN 1 ELSE 0 END), 1) AS pct_cars_non_usa,
       ROUND(AVG(CASE WHEN origin = 'usa' THEN mpg END), 1) AS avg_mpg_usa_only
FROM automobile
GROUP BY year
ORDER BY year;

-- Q12 top 3 standout cars in each era
-- ROW_NUMBER ranks the cars inside each era by efficiency gap
WITH ranked AS (
    SELECT era, name, year, origin, mpg, efficiency_gap,
           ROW_NUMBER() OVER (PARTITION BY era ORDER BY efficiency_gap DESC) AS rank_in_era
    FROM automobile
)
SELECT era, rank_in_era, name, year, origin, mpg, efficiency_gap
FROM ranked 
WHERE rank_in_era <= 3
ORDER BY CASE era WHEN 'Cheap fuel' THEN 1
                  WHEN 'Oil crisis shock' THEN 2
                  ELSE 3 END,
         rank_in_era;
         
-- Q13 did diesel deliver?
-- Only 9 diesel cars exist, so this is a lead and not proof
SELECT CASE WHEN is_diesel = 1 THEN 'Diesel' ELSE 'Other' END AS fuel_group,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 1) AS avg_mpg,
       ROUND(AVG(horsepower), 0) AS avg_hp,
       ROUND(AVG(efficiency_gap), 2) AS avg_gap
FROM automobile
GROUP BY is_diesel;

-- Brand summary (one row per brand with at least 8 cars)
CREATE OR REPLACE VIEW brand_summary AS
SELECT brand,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 1) AS avg_mpg,
       ROUND(AVG(efficiency_gap), 2) AS avg_gap,
       ROUND(100.0 * AVG(CASE WHEN efficiency_gap > 0 THEN 1 ELSE 0 END), 1) AS pct_beating_peers,
       ROUND(100.0 * SUM(on_frontier) / COUNT(*), 1) AS frontier_share_pct,
       ROUND(SUM(CASE WHEN efficiency_gap < 0 THEN efficiency_gap ELSE 0 END), 1) AS total_mpg_shortfall
FROM automobile
GROUP BY brand
HAVING COUNT(*) >= 8;

-- Yearly trend per origin
CREATE OR REPLACE VIEW origin_yearly_trend AS
SELECT origin,
       year,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 2) AS avg_mpg,
       ROUND(AVG(horsepower), 1) AS avg_hp,
       ROUND(AVG(weight_kg), 0) AS avg_weight_kg,
       COALESCE(ROUND(AVG(mpg) - LAG(AVG(mpg)) OVER (PARTITION BY origin ORDER BY year), 2), 0) AS change_vs_last_year
FROM automobile
GROUP BY origin, year;

-- Mix of US and non-US cars per year
CREATE OR REPLACE VIEW year_mix AS
SELECT year,
       ROUND(AVG(mpg), 1) AS avg_mpg_all_cars,
       ROUND(100.0 * AVG(CASE WHEN origin <> 'usa' THEN 1 ELSE 0 END), 1) AS pct_cars_non_usa,
       ROUND(AVG(CASE WHEN origin = 'usa' THEN mpg END), 1) AS avg_mpg_usa_only
FROM automobile
GROUP BY year;

-- Percent change from the first era to the last era, one row per origin and metric
CREATE OR REPLACE VIEW region_tradeoff AS
SELECT origin, 'MPG' AS metric,
       ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN mpg END)
                  / AVG(CASE WHEN era = 'Cheap fuel' THEN mpg END) - 1), 1) AS change_pct
FROM automobile
GROUP BY origin
UNION ALL
SELECT origin, 'Horsepower',
       ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN horsepower END)
                  / AVG(CASE WHEN era = 'Cheap fuel' THEN horsepower END) - 1), 1)
FROM automobile
GROUP BY origin
UNION ALL
SELECT origin, 'Weight',
       ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN weight_kg END)
                  / AVG(CASE WHEN era = 'Cheap fuel' THEN weight_kg END) - 1), 1)
FROM automobile
GROUP BY origin;

SELECT COUNT(*) AS brands_in_summary FROM brand_summary;
SELECT COUNT(*) AS origin_year_rows FROM origin_yearly_trend;
SELECT COUNT(*) AS years_in_mix FROM year_mix;

-- Create a separate database just for this project
CREATE DATABASE IF NOT EXISTS automobile_project;

-- Tell MySQL to use it for everything I run next
USE automobile_project;


-- Same columns, in the same order as automobile_clean.csv
CREATE TABLE automobile (
    car_id         INT PRIMARY KEY,
    name           VARCHAR(100),
    mpg            DECIMAL(10,2),
    cylinders      INT,
    displacement   DECIMAL(10,1),
    horsepower     DECIMAL(10,1),
    weight         INT,
    acceleration   DECIMAL(10,1),
    model_year     INT,
    origin         VARCHAR(20),
    brand          VARCHAR(30),
    year           INT,
    era            VARCHAR(40),
    l_per_100km    DECIMAL(10,2),
    weight_kg      DECIMAL(10,2),
    is_diesel      INT,
    expected_mpg   DECIMAL(10,2),
    efficiency_gap DECIMAL(10,2),
    on_frontier    INT
);



USE automobile_project;

SELECT COUNT(*) AS total_cars, SUM(on_frontier) AS frontier_cars FROM automobile;

--  missing values in the main columns
SELECT COUNT(*) - COUNT(mpg)            AS missing_mpg,
       COUNT(*) - COUNT(horsepower)     AS missing_horsepower,
       COUNT(*) - COUNT(weight_kg)      AS missing_weight,
       COUNT(*) - COUNT(efficiency_gap) AS missing_gap
FROM automobile;

-- do the categories look right? 
SELECT origin, era, COUNT(*) AS cars
FROM automobile
GROUP BY origin, era
ORDER BY origin, era;

-- rebuild the Pareto frontier in SQL and compare with the Python flag
SELECT COUNT(*) AS frontier_cars_in_sql
FROM automobile a
WHERE NOT EXISTS (
    SELECT 1
    FROM automobile b
    WHERE b.year = a.year
      AND b.mpg >= a.mpg
      AND b.horsepower >= a.horsepower
      AND (b.mpg > a.mpg OR b.horsepower > a.horsepower)
);

-- Q1 What did each region give up to gain mpg?
-- Percent change from the first era to the last era
SELECT origin,
	ROUND(AVG(CASE WHEN era = 'Cheap fuel' THEN mpg END), 1) AS mpg_first_era,
    ROUND(AVG(CASE WHEN era = 'Downsizing' THEN mpg END), 1) AS mpg_last_era,
    ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN mpg END)
				/ AVG(CASE WHEN era = 'Cheap fuel' THEN mpg END) - 1), 1) AS mpg_change_pct,
	ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN horsepower END)
				/ AVG(CASE WHEN era = 'Cheap fuel' THEN horsepower END) - 1), 1) AS hp_change_pct,
	ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN weight_kg END)
				/ AVG(CASE WHEN era = 'Cheap fuel' THEN weight_kg END) - 1), 1) AS weight_change_pct
			
FROM automobile
GROUP BY origin;
    
-- Q2 Does high performance cost mpg?
-- Split cars into equal groups by horsepower per tonne (1 = weakest, 4 = most powerful)
WITH performance AS(
	SELECT mpg, efficiency_gap, on_frontier,
			horsepower/(weight_kg/1000) AS hp_per_tonne,
			NTILE(4) OVER (ORDER BY horsepower/(weight_kg/1000)) AS performance_quartile
	FROM automobile
)
SELECT performance_quartile,
		COUNT(*) AS cars,
        ROUND(AVG(hp_per_tonne), 0) AS avg_hp_per_tonne,
        ROUND(AVG(mpg), 1) AS avg_mpg,
        ROUND(AVG(efficiency_gap), 2) AS avg_gap,
        ROUND(100.0*SUM(on_frontier)/COUNT(*), 1) AS frontier_share_pct
FROM performance
GROUP BY performance_quartile
ORDER BY performance_quartile;

-- Q3 Which cars were powerful AND efficient?
-- Best of both = horsepower at or above the average of its model year 
-- and a positive efficiency gap
WITH with_year_avg AS (
	SELECT origin, horsepower, efficiency_gap,
			AVG(horsepower) OVER (PARTITION BY year) AS year_avg_hp
	FROM automobile
)
SELECT origin,
		COUNT(*) AS cars,
		SUM(CASE WHEN horsepower >= year_avg_hp AND efficiency_gap > 0 THEN 1 ELSE 0 END) AS best_of_both,
		ROUND(100.0 * SUM(CASE WHEN horsepower >= year_avg_hp AND efficiency_gap > 0 THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS best_of_both_pct
FROM with_year_avg
GROUP BY origin
ORDER BY best_of_both_pct DESC;

-- Q4 do frontier cars sacrifice drivability?
-- Acceleration is seconds from 0 to 60, so lower means faster
SELECT CASE WHEN on_frontier = 1 THEN 'Frontier' ELSE 'Not frontier' END AS car_group,
		COUNT(*) AS cars,
		ROUND(AVG(horsepower), 0) AS avg_hp,
        ROUND(AVG(acceleration), 1) AS avg_sec_0_to_60,
        ROUND(AVG(weight_kg), 0) AS avg_weight_kg,
        ROUND(AVG(mpg), 1) AS avg_mpg
FROM automobile
GROUP BY on_frontier;

-- Q5 which brands most often beat their peers?
-- Brands with fewer than 8 cars are left out so a few lucky cars cannot decide the ranking
SELECT brand,
		COUNT(*) AS cars,
        ROUND(100.0 * AVG(CASE WHEN efficiency_gap > 0 THEN 1 ELSE 0 END), 1) AS pct_beating_peers,
        ROUND(AVG(efficiency_gap), 2) AS avg_gap
FROM automobile
GROUP BY brand
HAVING COUNT(*) >= 8
ORDER BY pct_beating_peers DESC;

-- Q6 Which brands have the most efficiency to recover?
-- Add up all the negative gaps per brand
SELECT brand,
       COUNT(*) AS cars,
       SUM(CASE WHEN efficiency_gap < 0 THEN 1 ELSE 0 END) AS cars_below_expected,
       ROUND(SUM(CASE WHEN efficiency_gap < 0 THEN efficiency_gap ELSE 0 END), 1) AS total_mpg_shortfall
FROM automobile
GROUP BY brand
HAVING COUNT(*) >= 8
ORDER BY total_mpg_shortfall ASC;

-- Q7 which brands built frontier cars?
SELECT brand,
       COUNT(*) AS cars,
       SUM(on_frontier) AS frontier_cars,
       ROUND(100.0 * SUM(on_frontier) / COUNT(*), 1) AS frontier_share_pct
FROM automobile
GROUP BY brand
HAVING COUNT(*) >= 8
ORDER BY frontier_share_pct DESC;

-- Q8 which engine configuration was the best bet?
-- Careful: the 3 and 5 cylinder groups only have a handful of cars
SELECT cylinders,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 1) AS avg_mpg,
       ROUND(AVG(horsepower), 0) AS avg_hp,
       ROUND(AVG(efficiency_gap), 2) AS avg_gap,
       ROUND(100.0 * SUM(on_frontier) / COUNT(*), 1) AS frontier_share_pct
FROM automobile
GROUP BY cylinders
ORDER BY cylinders;

-- Q9 is weight the whole story?
-- If the gap is close to zero in every weight class, it really removed the weight effect
SELECT CASE WHEN weight_kg < 1100 THEN '1. Light (under 1100 kg)'
            WHEN weight_kg <= 1500 THEN '2. Medium (1100-1500 kg)'
            ELSE '3. Heavy (over 1500 kg)' END AS weight_class,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 1) AS avg_mpg,
       ROUND(AVG(efficiency_gap), 2) AS avg_gap,
       ROUND(100.0 * SUM(on_frontier) / COUNT(*), 1) AS frontier_share_pct
FROM automobile
GROUP BY weight_class
ORDER BY weight_class;

-- Q10 how much fuel did a driver save between the first and last era?
-- 100 x (difference in litres per 100 km) = litres saved per 10,000 km
SELECT origin,
       ROUND(AVG(CASE WHEN era = 'Cheap fuel' THEN l_per_100km END), 1) AS l_per_100km_first_era,
       ROUND(AVG(CASE WHEN era = 'Downsizing' THEN l_per_100km END), 1) AS l_per_100km_last_era,
       ROUND(100 * (AVG(CASE WHEN era = 'Cheap fuel' THEN l_per_100km END)
                  - AVG(CASE WHEN era = 'Downsizing' THEN l_per_100km END)), 0) AS litres_saved_per_10000km
FROM automobile
GROUP BY origin;

-- Q11 is the 1980 jump in mpg real?
-- Compare all cars with US cars only, next to the share of non-US cars in the sample
SELECT year,
       ROUND(AVG(mpg), 1) AS avg_mpg_all_cars,
       ROUND(100.0 * AVG(CASE WHEN origin <> 'usa' THEN 1 ELSE 0 END), 1) AS pct_cars_non_usa,
       ROUND(AVG(CASE WHEN origin = 'usa' THEN mpg END), 1) AS avg_mpg_usa_only
FROM automobile
GROUP BY year
ORDER BY year;

-- Q12 top 3 standout cars in each era
-- ROW_NUMBER ranks the cars inside each era by efficiency gap
WITH ranked AS (
    SELECT era, name, year, origin, mpg, efficiency_gap,
           ROW_NUMBER() OVER (PARTITION BY era ORDER BY efficiency_gap DESC) AS rank_in_era
    FROM automobile
)
SELECT era, rank_in_era, name, year, origin, mpg, efficiency_gap
FROM ranked 
WHERE rank_in_era <= 3
ORDER BY CASE era WHEN 'Cheap fuel' THEN 1
                  WHEN 'Oil crisis shock' THEN 2
                  ELSE 3 END,
         rank_in_era;
         
-- Q13 did diesel deliver?
-- Only 7 diesel cars exist, so this is a lead and not proof
SELECT CASE WHEN is_diesel = 1 THEN 'Diesel' ELSE 'Other' END AS fuel_group,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 1) AS avg_mpg,
       ROUND(AVG(horsepower), 0) AS avg_hp,
       ROUND(AVG(efficiency_gap), 2) AS avg_gap
FROM automobile
GROUP BY is_diesel;

UPDATE automobile SET is_diesel = 1
WHERE car_id IN (298, 329);

-- Brand summary (one row per brand with at least 8 cars)
CREATE OR REPLACE VIEW brand_summary AS
SELECT brand,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 1) AS avg_mpg,
       ROUND(AVG(efficiency_gap), 2) AS avg_gap,
       ROUND(100.0 * AVG(CASE WHEN efficiency_gap > 0 THEN 1 ELSE 0 END), 1) AS pct_beating_peers,
       ROUND(100.0 * SUM(on_frontier) / COUNT(*), 1) AS frontier_share_pct,
       ROUND(SUM(CASE WHEN efficiency_gap < 0 THEN efficiency_gap ELSE 0 END), 1) AS total_mpg_shortfall
FROM automobile
GROUP BY brand
HAVING COUNT(*) >= 8;

-- Yearly trend per origin
CREATE OR REPLACE VIEW origin_yearly_trend AS
SELECT origin,
       year,
       COUNT(*) AS cars,
       ROUND(AVG(mpg), 2) AS avg_mpg,
       ROUND(AVG(horsepower), 1) AS avg_hp,
       ROUND(AVG(weight_kg), 0) AS avg_weight_kg,
       COALESCE(ROUND(AVG(mpg) - LAG(AVG(mpg)) OVER (PARTITION BY origin ORDER BY year), 2), 0) AS change_vs_last_year
FROM automobile
GROUP BY origin, year;

-- Mix of US and non-US cars per year
CREATE OR REPLACE VIEW year_mix AS
SELECT year,
       ROUND(AVG(mpg), 1) AS avg_mpg_all_cars,
       ROUND(100.0 * AVG(CASE WHEN origin <> 'usa' THEN 1 ELSE 0 END), 1) AS pct_cars_non_usa,
       ROUND(AVG(CASE WHEN origin = 'usa' THEN mpg END), 1) AS avg_mpg_usa_only
FROM automobile
GROUP BY year;

-- Percent change from the first era to the last era, one row per origin and metric
CREATE OR REPLACE VIEW region_tradeoff AS
SELECT origin, 'MPG' AS metric,
       ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN mpg END)
                  / AVG(CASE WHEN era = 'Cheap fuel' THEN mpg END) - 1), 1) AS change_pct
FROM automobile
GROUP BY origin
UNION ALL
SELECT origin, 'Horsepower',
       ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN horsepower END)
                  / AVG(CASE WHEN era = 'Cheap fuel' THEN horsepower END) - 1), 1)
FROM automobile
GROUP BY origin
UNION ALL
SELECT origin, 'Weight',
       ROUND(100 * (AVG(CASE WHEN era = 'Downsizing' THEN weight_kg END)
                  / AVG(CASE WHEN era = 'Cheap fuel' THEN weight_kg END) - 1), 1)
FROM automobile
GROUP BY origin;

SELECT COUNT(*) AS brands_in_summary FROM brand_summary;
SELECT COUNT(*) AS origin_year_rows FROM origin_yearly_trend;
SELECT COUNT(*) AS years_in_mix FROM year_mix;

SELECT *
FROM year_mix;

-- Rank each brand twice: by raw average mpg, and by efficiency gap 
-- AS SIGNED is needed so that rank differences can be negative
CREATE OR REPLACE VIEW brand_rank_shift AS
WITH ranked AS (
    SELECT brand,
           COUNT(*) AS cars,
           ROUND(AVG(mpg), 1) AS avg_mpg,
           ROUND(AVG(efficiency_gap), 2) AS avg_gap,
           CAST(RANK() OVER (ORDER BY AVG(mpg) DESC) AS SIGNED) AS rank_raw_mpg,
           CAST(RANK() OVER (ORDER BY AVG(efficiency_gap) DESC) AS SIGNED) AS rank_gap
    FROM automobile
    GROUP BY brand
    HAVING COUNT(*) >= 8
)
SELECT brand, cars, avg_mpg, avg_gap, rank_raw_mpg, rank_gap,
       rank_raw_mpg - rank_gap AS places_gained,
       CASE WHEN rank_gap < rank_raw_mpg THEN 'Rises'
            WHEN rank_gap > rank_raw_mpg THEN 'Falls'
            ELSE 'Same' END AS direction
FROM ranked;

SELECT * FROM brand_rank_shift ORDER BY rank_gap;

SELECT *
FROM region_tradeoff
ORDER BY origin, metric;
       
SELECT *
FROM year_mix
ORDER BY year;

SELECT *
FROM brand_summary
ORDER BY total_mpg_shortfall DESC;

SELECT *
FROM origin_yearly_trend
ORDER BY year, origin;