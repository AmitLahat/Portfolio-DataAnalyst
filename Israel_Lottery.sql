-- (Link to the raw data: https://github.com/AmitLahat/Portfolio-DataAnalyst/blob/main/Lotto.csv)

/*I want to know what could have happened if i submitted the most common number results
  from Israel's lottery in every draw (based on the last 5 years).
  Data taken from "Pais.co.il"  */

-- Cleaning:
alter table Lotto
drop column "column10", "column11","column12" --drop extra columns
EXEC sp_rename 'Lotto.column1', 'DrawNumber', 'COLUMN'; --rename properly
EXEC sp_rename 'Lotto.column2', 'DrawDate', 'COLUMN';
EXEC sp_rename 'Lotto.column3', 'Num1', 'COLUMN';
EXEC sp_rename 'Lotto.column4', 'Num2', 'COLUMN';
EXEC sp_rename 'Lotto.column5', 'Num3', 'COLUMN';
EXEC sp_rename 'Lotto.column6', 'Num4', 'COLUMN';
EXEC sp_rename 'Lotto.column7', 'Num5', 'COLUMN';
EXEC sp_rename 'Lotto.column8', 'Num6', 'COLUMN';
EXEC sp_rename 'Lotto.column9', 'StrongNum', 'COLUMN';
delete Lotto -- keep last 5 years
where DrawDate <= 
(select top 1 dateadd(yy, -5, max(DrawDate)over()) as MDate 
from Lotto)

--Israel Lottery 5 years back (20.5.18-20.5.23) (568 Draws)
select * from [dbo].[Lotto]
--strong number appearances:
select StrongNum, count(StrongNum) as AppearancesStr
-- into StrongNumAppeared -- (for following steps)
from Lotto
group by StrongNum
-- 6 numbers (1-37):
with Number1 as(
select Num1, count(Num1) as Appearances1
from Lotto
group by Num1 ),
Number2 as(
select Num2, count(Num2) as Appearances2
from Lotto
group by Num2 ),
Number3 as(
select Num3, count(Num3) as Appearances3
from Lotto
group by Num3 ),
Number4 as(
select Num4, count(Num4) as Appearances4
from Lotto
group by Num4 ),
Number5 as(
select Num5, count(Num5) as Appearances5
from Lotto
group by Num5 ),
Number6 as(
select Num6, count(Num6) as Appearances6
from Lotto
group by Num6 )
select COALESCE(Num1,Num6) as Num,
isnull(Appearances1,0)+isnull(Appearances2,0)+isnull(Appearances3,0)
+isnull(Appearances4,0)+isnull(Appearances5,0)+isnull(Appearances6,0) as Appearances
-- into NumbersAppeared -- (for following steps)
from Number1 full join Number2 on Num1=Num2
full join Number3 on Num2=Num3
full join Number4 on Num3=Num4
full join Number5 on Num4=Num5
full join Number6 on Num5=Num6
order by 1 
-- Saved both Numbers and Strong numbers appearance results into new tables (NumbersAppeared, StrongNumAppeared)
-- most&least common numbers: (Strong Number)
select StrongNum, AppearancesStr  from(
select *, ROW_NUMBER()over(order by AppearancesStr) as rn
from StrongNumAppeared) as s
where s.rn in (1,7)
order by 2 desc
-- most&least common numbers: (1-37 Numbers)
select Num, Appearances  from(
select *, ROW_NUMBER()over(order by Appearances) as rn
from NumbersAppeared) as s
where s.rn in (1,37)
order by 2 desc
/* Oddly enough the most and least common numbers are consecutive numbers.
   3,4 for StrongNumber (50% point), and 24,25 for NormalNumbers (66% point)*/
-- Now how do the results distribute relative the the average?
select * from StrongNumAppeared where AppearancesStr>=81 -- 1-7 above avg of 81 = 4 results
select * from NumbersAppeared where Appearances>=94 -- 1-37 above avg of 94 = 14 results
/*For strong numbers the least common appears 77% relative to the most common
  additionally 4/7 numbers are above their average --> No number(s) truly stand out.
  For normal numbers the least common appears 70% relative to the most common
  However, 14 numbers are above the average (37% of them) 
  Because of the small gap between the most/least common we still can't give high priority to the top 37%.
*/
------------------------------------------------------
-- Now lets check the "Best" numbers and how much we might earn: 
select top 6 * from NumbersAppeared order by 2 desc
select top 1 * from StrongNumAppeared order by 2 desc
/* Best numbers from last 5 years are: 1,12,13,20,25,33. Strong: 3
   The testing is without the strongnumber */
create view v_lotto_results as -- create a view to work with a loop (concating the numbers with '.' seperator)
select DrawNumber, DrawDate,
concat('.',Num1,'.',Num2,'.',Num3,'.',Num4,'.',Num5,'.',Num6,'.') as Drawn_Numbers
from Lotto
--
DECLARE @drawnNums VARCHAR(20), @DrawDate date -- Loop to check accurance of result string
DECLARE @DrawNum int = 3584, @bestnums VARCHAR(20) = '1,12,13,20,25,33'
DECLARE @CommonAppearances table (DrawDate date,Times_Common int);
WHILE @DrawNum>=3017
BEGIN
	SELECT @drawnNums = Drawn_Numbers, @DrawDate = DrawDate 
	   from v_lotto_results where DrawNumber=@DrawNum
	Insert into @CommonAppearances(DrawDate,Times_Common)
	SELECT @DrawDate, COUNT(*) AS Times_InCommon
	FROM (
		SELECT value AS Number
		FROM STRING_SPLIT(@drawnNums, '.')
		WHERE value IN (
			SELECT value
			FROM STRING_SPLIT(@bestnums, ',') )
			) AS s
	SET @DrawNum-=1
END
select Times_Common, count(Times_Common) as Times_Happened
from @CommonAppearances
group by Times_Common
order by 1 desc
/* based on that, here are the IMAGINARY costs/profits:
   (not including the Strong number, 3 correct numbers profit is 10ILS, no data on 4 & 5 correct numbers so we'll 10X it) */
select format(568*11.90,'c','he-il') as 'Total_Spending for 568 draws:',
	   format(35*10,'c','he-il') as 'Earnings for 3 correct numbers',
	   format(2*100,'c','he-il') as 'Earnings for 4 correct numbers',
	   format(1*1000,'c','he-il') as 'Earnings for 5 correct numbers',
	   format(35*10+2*100+1*1000-568*11.90,'c','he-il') as Summary
--With a loss of 77% for our money, We can conclude that without hitting the jackpot, the lottery is a terrible investment.
------------------------------------------------------

--*************************************
-- Extra loops from additional testing:
--*************************************
-- loop to check accurance of duos in results:
DECLARE @n1 int, @n2 int, @count int
DECLARE @result table (N1 int, N2 int, "Count" int)
set @n1=1 set @n2=2
while @n1<37
BEGIN
	while @n2<38
	BEGIN
		insert into @result (N1,N2,count)
		select @n1, @n2,	
		count(Drawn_Numbers) from v_lotto_results
		where Drawn_Numbers LIKE '%'+concat('.',@n1,'.')+'%'
		and Drawn_Numbers LIKE '%'+concat('.',@n2,'.')+'%'							
		set @n2+=1
	END
	set @n1+=1
	set @n2 = @n1+1
END
SELECT * FROM @result
order by 3 desc
/* (13,25), (13,20), (1,33) 3 out of the top 4 pairs are included in our "best numbers" from earlier. */
---------------------------------------------------------------------------------------------------
-- Cheking common numbers between consecutive draws:
select DrawNumber, DrawDate,
concat(Num1,'.',Num2,'.',Num3,'.',Num4,'.',Num5,'.',Num6) as Drawn_Numbers,
lead(concat(Num1,'.',Num2,'.',Num3,'.',Num4,'.',Num5,'.',Num6))
over(order by DrawDate desc) as PreviousNums,
'  ' as CommonNumbersCount
-- into ConsecNums -- (creating a table to update custom column)
from Lotto
--
UPDATE ConsecNums
SET CommonNumbersCount = (
    SELECT COUNT(*)
    FROM (
        SELECT value
        FROM STRING_SPLIT("Drawn_Numbers", '.')
        INTERSECT
        SELECT value
        FROM STRING_SPLIT("PreviousNums", '.')
    ) AS common_numbers )
select * from ConsecNums
--
select CommonNumbersCount, count(DrawDate) as TimesHappened   -- count repetition common numbers for consecutive draws
from ConsecNums
group by CommonNumbersCount
order by 1 desc
/* 405/568  71.30% that at least 1 number from previous draw will ReAppear
   Although the probability for it is only 56.3%*/