SELECT *
FROM dbo.LendingClubData

-- earliest_cr_line, issue_d, and address all look like they could be fixed up.
-- Specifically, the earliest_cr_line and issue_d are only give by month and year, so extract that only.
-- For the address, extract the state and zip only

ALTER TABLE dbo.LendingClubData
ADD 
	issue_month TINYINT,
    issue_year SMALLINT,
	earliest_cr_line_month TINYINT,
	earliest_cr_line_year SMALLINT,
	zip_code CHAR(5), -- must be length 5
	state VARCHAR(25)

GO

CREATE PROC UpdateLendingData

AS

BEGIN
-- add in issue_d and earliest_cr_line months and years first.
UPDATE dbo.LendingClubData
SET
	issue_month = MONTH(issue_d)
   ,issue_year = YEAR(issue_d)
   ,earliest_cr_line_month = MONTH(earliest_cr_line) 
   ,earliest_cr_line_year = YEAR(earliest_cr_line) 
   ,zip_code = SUBSTRING(address, LEN(address)-4, 5)
   ,state = SUBSTRING(address, LEN(address)-7, 2)
FROM dbo.LendingClubData


-- change term to numerical cat
UPDATE dbo.LendingClubData
SET
	term =  SUBSTRING(term, 1, 2)


UPDATE dbo.LendingClubData
SET
	emp_length = 
		CASE
			WHEN emp_length IS NULL AND emp_title IS NULL THEN  '< 1 year'
		ELSE
			emp_length
		END

END


EXEC UpdateLendingData

SELECT * FROM dbo.LendingClubData




SELECT name
FROM SYS.COLUMNS
WHERE OBJECT_ID = OBJECT_ID('dbo.LendingClubData')
	AND is_nullable = 1

-- Features that can be NULL are: emp_title, emp_length, title, revol_util, mort_acc, pub_rec_bankruptcies

SELECT COUNT(DISTINCT(emp_title)) FROM dbo.LendingClubData -- 149260 This feature will not be useful as too many. Drop in the final View.

SELECT * FROM dbo.LendingClubData
WHERE emp_title IS NULL

-- Many of the emp_title and emp_length are NULL together
-- Since emp_title is the employment title and emp_length is the employment length
-- it makes sense to put in 0 for the emp_length in these cases

SELECT DISTINCT(emp_length)
FROM dbo.LendingClubData

-- There is not a 0 option, but < 1 year makes sense, so I will do that.
SELECT emp_title, emp_length
FROM dbo.LendingClubData
WHERE emp_title IS NULL
	AND emp_length IS NULL

SELECT COUNT(*)
FROM dbo.LendingClubData
WHERE emp_title IS NOT NULL
	AND emp_length IS NULL

-- 178. Since this is a small amount and there is no reason to make any assumptions, it would be best to drop the remaining rows for emp_length IS NULL


-- title column
SELECT DISTINCT title
FROM dbo.LendingClubData

SELECT COUNT(*)
FROM dbo.LendingClubData
WHERE title IS NULL
-- title is another categorical feature with too many features. Since it has nulls, the best solution will be to drop this column

SELECT revol_util
FROM dbo.LendingClubData

-- revolving utilization is numerical, so number of distinct doesn't matter. See how many nulls there are
SELECT COUNT(*)
FROM dbo.LendingClubData
WHERE revol_util IS NULL

-- revol_utlil: 276 null, which is a rather low number out of over 390,000. The  quickest solution for this one is to drop the rows with a null. However,
-- Observe that, from the features, none of them necessarily correlate in an obvious way to input data, so I will keep them around to explore further in Python


SELECT mort_acc
FROM dbo.LendingClubData

-- A numerical category featuring the number of mortgage accounts

SELECT COUNT(*)
FROM dbo.LendingClubData
WHERE mort_acc IS NULL

-- mort_acc nulls: 37795. Based purely on this, the best route would be to remove this feature. However, it is probably worth looking further into.

SELECT DISTINCT pub_rec_bankruptcies
FROM dbo.LendingClubData

-- This feature only has a few distinct choices, coupled with the fact that bankruptcies are probably indicative of a person paying a loan back,
-- this feature should not be dropped.

SELECT COUNT(*)
FROM dbo.LendingClubData
WHERE pub_rec_bankruptcies IS NULL

-- pub_rec_bankruptcies nulls: 535. However, it is worth seeing if any other feature corresponds to it.


-- ALL NULLABLE COLUMNS LOOKED INTO.

-- Non-null non-numeric features that may not be useful (verification_status, home_ownership, purpose, application_type)
SELECT DISTINCT verification_status, COUNT(*) OVER(PARTITION BY verification_status)
FROM dbo.LendingClubData

-- verification_status is good.

SELECT DISTINCT home_ownership, COUNT(*) OVER(PARTITION BY home_ownership)
FROM dbo.LendingClubData

-- home_ownership: 'NONE', 'ANY', and 'OTHER' have very small counts vs the others. Probably easier to lump into one 'OTHER' category

SELECT DISTINCT
	home_owner_adj = CASE
		WHEN home_ownership IN ('NONE', 'ANY') THEN 'OTHER'
		ELSE home_ownership
	END
FROM dbo.LendingClubData


SELECT DISTINCT purpose, COUNT(*) OVER(PARTITION BY purpose)
FROM dbo.LendingClubData

-- purpose looks good

SELECT DISTINCT application_type, COUNT(*) OVER(PARTITION BY application_type)
FROM dbo.LendingClubData

-- application_type is fine. Over 99.5% of the application types are 'INDIVIDUAL', which means that this feature may not be very useful.

GO

--- NOTES FOR VIEW

-- Remove rows with NULL for emp_length and the entire emp_title feature

-- title is another categorical feature with too many features. Drop it.

-- revol_utlil: 276 null, which is a rather low number out of over 390,000. The  quickest solution for this one is to drop the rows with a null. However,
-- Observe that, from the features, none of them necessarily correlate in an obvious way to input data, so I will keep them around to explore further in Python

-- mort_acc nulls: 37795. Based purely on this, the best route would be to remove this feature. However, it is probably worth looking further into.

-- pub_rec_bankruptcies nulls: 535. However, it is worth seeing if any other feature corresponds to it.

-- home_ownership: 'NONE', 'ANY', and 'OTHER' have very small counts vs the others. Probably easier to lump into one 'OTHER' category

CREATE VIEW dbo.LendingClubView

AS

(
SELECT 
	loan_amnt
   ,term
   ,int_rate
   ,installment
   ,grade
   ,sub_grade
   ,emp_length -- drop rows where this is null
   ,home_ownership =
		CASE
			WHEN home_ownership IN ('NONE', 'ANY') THEN 'OTHER'
			ELSE home_ownership
		END
   ,annual_inc
   ,verification_status
   ,issue_month
   ,issue_year
   ,purpose
   ,dti
   ,earliest_cr_line_month
   ,earliest_cr_line_year
   ,open_acc
   ,pub_rec
   ,revol_bal
   ,total_acc
   ,initial_list_status
   ,application_type
   ,mort_acc
   ,pub_rec_bankruptcies
   ,zip_code
   ,state 
   ,loan_status -- Target
FROM dbo.LendingClubData
WHERE emp_length IS NOT NULL
)
