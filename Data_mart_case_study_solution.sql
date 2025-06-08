use data_mart;
show tables;

-- CLEANING DATA
select * from weekly_sales;
select year(week_date) from weekly_sales;
alter table weekly_sales
modify column week_date date;
describe weekly_sales;

update weekly_sales
set week_date=date_format(week_date,'%d/%m/%y');
select year(week_date) from weekly_sales;

-- PREPARATIION
-- Add a week_number as the second column for each week_date 
-- value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc
alter table weekly_sales
add column week_number int;
update weekly_sales
set week_number=week(week_date);

-- Add a month_number with the calendar month for each week_date value as the 3rd column
alter table weekly_sales
add column month_number int;
update weekly_sales
set month_number=month(week_date);

-- Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values
alter table weekly_sales
add column calendar_year int;
update weekly_sales
set calendar_year=year(week_date);

-- Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value
alter table weekly_sales
add column age_brand varchar(20);
update weekly_sales
set age_brand=
case when segment like '%1' then 'Young_Adults' 
when segment like '%2' then 'Middle_Aged'
else 'Retirees' end;

-- Add a new demographic column using the following mapping for the first letter in the segment values:
alter table weekly_sales
add column demographic varchar(20);
update weekly_sales
set demographic=
case when segment like 'C%' then 'Couples'
when segment like 'F%' then 'Families' 
else Null end;

update weekly_sales
set age_brand=Null
where segment='null';

-- Ensure all null string values with an "unknown" 
-- string value in the original segment column as well as the new age_band and demographic columns
alter table weekly_sales
modify column segment varchar(10);
update weekly_sales
set segment='unknown',
age_brand='unknown',
demographic='unknown'
where
segment='null';

-- Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record
alter table weekly_sales
modify column avg_transaction decimal(10,2);
update weekly_sales
set avg_transaction=round((sales/transactions),2);

-- What day of the week is used for each week_date value?
select distinct(week_date),day(week_date)
from weekly_sales;

-- What range of week numbers are missing from the dataset?
with week_numbers as
(select distinct(week_number)
from weekly_sales
order by week_number)
,original_week_numbers as
(
select rn from (select *,
row_number() over(partition by platform order by customer_type) as rn
from weekly_sales) as ran
where rn<53 and platform='Retail')
select rn from original_week_numbers as weeks_number_not_in_range
where rn not in (select week_number from week_numbers);

-- How many total transactions were there for each year in the dataset?
select calendar_year,sum(transactions)
from weekly_sales
group by calendar_year;

-- What is the total sales for each region for each month?
select region,month_number,sum(sales) 
from weekly_sales
group by region,month_number
order by region,month_number;

-- What is the total count of transactions for each platform
select platform,count(*) as num_of_transactions
from weekly_sales
group by platform;

-- What is the percentage of sales for Retail vs Shopify for each month?
select 
((select sum(sales) from weekly_sales where platform='Retail')/(select sum(sales) from weekly_sales))*100 as percentage_of_retail,
((select sum(sales) from weekly_sales where platform='Shopify')/(select sum(sales) from weekly_sales))*100 as percentage_of_shopify
;

-- What is the percentage of sales by demographic for each year in the dataset?
select calendar_year,
(sum(case when demographic='Couples' then sales end)/sum(sales))*100 as couple_sales_percentage,
(sum(case when demographic='Families' then sales end)/sum(sales))*100 as family_sales_percentage,
(sum(case when demographic='unknown' then sales end)/sum(sales))*100 as others_sales_percentage
from weekly_sales
group by calendar_year
order by calendar_year;

-- Which age_band and demographic values contribute the most to Retail sales?
select age_brand,demographic
from weekly_sales
where age_brand!='unknown' and demographic!='unknown'
group by age_brand,demographic
order by sum(sales) desc
limit 1;

-- Can we use the avg_transaction column to find the average transaction size for each year
-- for Retail vs Shopify? If not - how would you calculate it instead?
select calendar_year,
avg(case when platform='Retail' then transactions end) as avg_retail_transaction_size,
avg(case when platform='Shopify' then transactions end) as avg_shopify_transaction_size
from weekly_sales
group by calendar_year
order by calendar_year;

-- What is the total sales for the 4 weeks before and after 2020-06-15? 
-- What is the growth or reduction rate in actual values and percentage of sales?
select prev_weeks_sales,after_weeks_sales,
prev_weeks_sales-after_weeks_sales as reduction_in_sales,
((prev_weeks_sales-after_weeks_sales)/(prev_weeks_sales))*100 as percentage_reduction
from(
select 
sum(case when (week_date between date_sub('2020-08-10',interval 4 week) and '2020-08-10') then coalesce(sales,0) end) as prev_weeks_sales,
sum(case when (week_date between '2020-08-10' and date_add('2020-08-10',interval 4 week)) then coalesce(sales,0) end) as after_weeks_sales
from weekly_sales) as ran;

-- What about the entire 12 weeks before and after?
select prev_weeks_sales,after_weeks_sales,
prev_weeks_sales-after_weeks_sales as reduction_in_sales,
((prev_weeks_sales-after_weeks_sales)/(prev_weeks_sales))*100 as percentage_reduction
from(
select 
sum(case when (week_date between date_sub('2020-08-10',interval 12 week) and '2020-08-10') then coalesce(sales,0) end) as prev_weeks_sales,
sum(case when (week_date between '2020-08-10' and date_add('2020-08-10',interval 12 week)) then coalesce(sales,0) end) as after_weeks_sales
from weekly_sales) as ran;

-- How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
select calendar_year,prev_weeks_sales,after_weeks_sales,
prev_weeks_sales-after_weeks_sales as reduction_in_sales,
((prev_weeks_sales-after_weeks_sales)/(prev_weeks_sales))*100 as percentage_reduction
from(
select calendar_year,
sum(case when (month(week_date) between 4 and 8) then coalesce(sales,0) end) as prev_weeks_sales,
sum(case when (month(week_date) between 8 and 12) then coalesce(sales,0) end) as after_weeks_sales
from weekly_sales
group by calendar_year) as ran;





-- 






-- 