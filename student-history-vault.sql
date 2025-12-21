													-- IMPORTING RAW DATA --

CREATE TABLE student_raw (
student_number INT,
college VARCHAR(100),
program VARCHAR(100),
section VARCHAR(10),
school_year INT,
year_level INT,
semester VARCHAR(10),
average REAL,
absents INT,
year INT,
month INT,
PRIMARY KEY(student_number, year, month))


										   	-- DATA PREPPING FOR TEMPORAL MODELING -- 
											   
-- INSERTING month_spent AND remarks COLUMNS 
-- WE ARE GOING TO PARTITION BY school_year AND month_spent BECAUSE IT IS BETTER COMPARED TO year AND month
-- HERE'S WHY: 
-- school_year AND month_spent: 	2021 | 6 ; 2021 | 12 = 1 SCHOOL YEAR 
-- year AND month: 					2021 | 12; 2022 | 6 = 1 SCHOOL YEAR 


CREATE TABLE student_staging (
student_number INT,
college VARCHAR(100),
program VARCHAR(100),
section VARCHAR(10),
year_level INT,
school_year INT,
month_spent INT,
semester VARCHAR(10),
average REAL,
absents INT,
remarks VARCHAR(10),
year INT,
month INT,
PRIMARY KEY(student_number, year, month)
)

INSERT INTO student_staging
SELECT student_number, 
	   college, program,
	   section,
	   year_level,
	   school_year,
	   CASE WHEN month = 12 THEN 6 WHEN month = 6 THEN 12 END AS month_spent,
	   semester,
	   average,
	   absents,
	   CASE WHEN average > 75 THEN 'Passed' ELSE 'Failed' END AS remarks,
	   year, 
	   month
FROM student_raw

													-- CHECKING FOR DUPLICATES -- 


WITH CTE AS (
SELECT *, ROW_NUMBER() OVER (PARTITION BY student_number, college, program, section, year_level, school_year, month_spent) AS row_num
FROM student_staging)

SELECT *
FROM CTE
WHERE row_num > 1

-- NO DUPLICATES 

												-- INCREMENTAL (ITERATIVE) UPDATE--

CREATE TYPE student_stats AS (
year_level INT,
semester VARCHAR(10), 
average REAL,
absents INT, 
remarks VARCHAR(10), 
year INT,
month INT
)

CREATE TABLE student_cmd (
student_number INT,
college VARCHAR(100),
program VARCHAR(100),
section VARCHAR(10),
student_stats student_stats[],
school_year INT,
month_spent INT
)

INSERT INTO student_cmd
WITH last_sem AS (
SELECT *
FROM student_cmd
WHERE school_year = 2020 AND month_spent = 12 -- <-- These are changed every insert (Every semestrer)
), current_sem AS (
SELECT *
FROM student_staging
WHERE schooL_year = 2021 AND month_spent = 6  -- <-- These are changed every insert (Every semestrer)
)

SELECT 
	COALESCE(t.student_number, y.student_number) AS student_number,
	COALESCE(t.college, y.college) AS college,
	COALESCE(t.program, y.program) AS program,
	COALESCE(t.section, y.section) AS section,
	CASE WHEN y.student_stats IS NULL THEN ARRAY[ROW(t.year_level,
													 t.semester,
													 t.average,
													 t.absents,
													 t.remarks,
													 t.year,
													 t.month)::student_stats]
		 WHEN t.school_year IS NOT NULL THEN y.student_stats ||
		 								   ARRAY[ROW(t.year_level,
													 t.semester,
													 t.average,
													 t.absents,
													 t.remarks,
													 t.year,
													 t.month)::student_stats]
		ELSE y.student_stats END AS student_stats,
	CASE WHEN t.month_spent IS NULL THEN y.school_year
	ELSE COALESCE(t.school_year, y.school_year + 1) END AS current_school_year,
	CASE WHEN t.month_spent IS NULL THEN y.month_spent
	ELSE COALESCE(t.month_spent, y.month_spent + 6) END AS month_spent
FROM current_sem AS t FULL OUTER JOIN last_sem y ON t.student_number = y.student_number


												-- BATCH (RECONSTRUCTIVE) VIEW -- 


CREATE TYPE student_stats AS ( -- <-- ALREADY DID THIS IN THE INCREMENTAL UPDATE
year_level INT,
semester VARCHAR(10), 
average REAL,
absents INT, 
remarks VARCHAR(10), 
year INT,
month INT
)

CREATE TABLE student_cmd2 (
student_number INT,
college VARCHAR(100),
program VARCHAR(100),
section VARCHAR(10),
school_year INT,
current_academic_level INT,
school_year_status VARCHAR(50),
average_per_academic_level REAL,
academic_honors VARCHAR(50),
cumulative_average REAL,
cumulative_student_history student_stats[],
enrollment_status VARCHAR(50)
)

INSERT INTO student_cmd2
WITH years AS (
SELECT *
FROM GENERATE_SERIES(2021, 2025) AS school_year
), p AS (
SELECT student_number, MIN(school_year) AS first_school_year
FROM student_staging
GROUP BY student_number
), students_and_years AS (
SELECT *
FROM p JOIN years y ON p.first_school_year <= y.school_year
), pre_windowed AS (SELECT sy.student_number, sy.school_year, ss.college, ss.program, ss.year_level,
	ARRAY_REMOVE(ARRAY_AGG(CASE WHEN ss.school_year IS NOT NULL THEN ROW(ss.year_level, 
															ss.semester,
															ss.average,
															ss.absents,
															ss.remarks,
															ss.year,
															ss.month)::student_stats END) OVER 
															(PARTITION BY ss.student_number ORDER BY COALESCE(sy.school_year, ss.school_year), ss.month_spent), NULL) AS student_stats
FROM students_and_years sy JOIN student_staging ss ON sy.student_number = ss.student_number AND sy.school_year = ss.school_year
ORDER BY student_number, school_year
), windowed AS (
SELECT student_number, school_year, college, program, year_level AS current_year_level, MAX(student_stats) AS student_stats
FROM pre_windowed
GROUP BY student_number, school_year, college, program, year_level
ORDER BY college, program, student_number
), windowed_with_sem AS (
SELECT *, 
	CASE WHEN CARDINALITY(student_stats) % 2 != 1 THEN 'Completed' ELSE 'In progress' END AS school_year_status
FROM windowed
), windowed_with_average AS (
SELECT student_number, school_year, AVG(unnested.average) AS average_per_year_level, school_year_status
FROM windowed_with_sem w, UNNEST(student_stats) AS unnested
WHERE (unnested).year_level = (w.school_year - (SELECT first_school_year FROM p WHERE student_number = w.student_number) + 1)
GROUP BY student_number, school_year, school_year_status
ORDER BY student_number, school_year
), windowed_with_awards AS (
SELECT ws.student_number, ws.school_year, ws.college, ws.program, ws.current_year_level, ws.student_stats, ws.school_year_status, wa.average_per_year_level, 
CASE WHEN ws.school_year_status = 'Completed' AND wa.average_per_year_level >= 95 THEN 'President''s Lister'
	 WHEN ws.school_year_status = 'Completed' AND wa.average_per_year_level >= 92 THEN 'Dean''s Lister'
	 WHEN ws.school_year_status = 'Completed' AND wa.average_per_year_level < 92 THEN 'Ineligeble for Academic Honors'
	 ELSE 'Academic session in progress' END AS eligeble_awards
FROM windowed_with_sem ws JOIN windowed_with_average wa ON ws.student_number = wa.student_number AND ws.school_year = wa.school_year
), windowed_with_grad_stat AS (
SELECT *, CASE WHEN CARDINALITY(student_stats) = 8 THEN 'Graduated' ELSE 'Undergraduate' END AS graduation_status
FROM windowed_with_awards
), windowed_with_cumulative_avg AS (
SELECT *, AVG(average_per_year_level) OVER (PARTITION BY student_number ORDER BY school_year ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_average
FROM windowed_with_grad_stat
),
static AS (
SELECT MAX(student_number) AS student_number, MAX(college) AS college, MAX(program) AS program, MAX(section) AS section
FROM student_staging
GROUP BY student_number)

SELECT s.student_number, 
	   s.college, 
	   s.program, 
	   s.section, 
	   w.school_year, 
	   w.current_year_level AS current_academic_level, 
	   w.school_year_status, 
	   w.average_per_year_level average_per_academic_level,
	   w.eligeble_awards AS academic_honors, 
	   w.cumulative_average,
	   w.student_stats AS cumulative_student_history,
	   w.graduation_status AS enrollment_status
FROM static s JOIN windowed_with_cumulative_avg w ON s.student_number = w.student_number
ORDER BY s.college, s.program, s.student_number, w.student_stats



 








