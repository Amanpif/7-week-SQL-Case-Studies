use foodie_fi;

-- How many customers has Foodie-Fi ever had?
select count(distinct(customer_id))
from subscriptions;

-- What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
select month(start_date) as month_of_start,count(plan_id) as number_of_plan 
from subscriptions
where plan_id=0
group by month(start_date)
order by month(start_date);

-- What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
select plan_id,count(plan_id) as number_of_plans
from subscriptions
where start_date>='2021-01-01'
group by plan_id;

-- What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
select 
(count(distinct(case when plan_id=4 then customer_id end))/
count(distinct(customer_id)))*100
from subscriptions;

-- How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
with cte as 
(select customer_id,plan_id,
lead(plan_id,1, NULL) over (partition by customer_id order by start_date) as next_plan
from subscriptions)
select count(distinct(customer_id))
from cte
where plan_id=0 and next_plan=4;

-- What is the number and percentage of customer plans after their initial free trial?
with cte as 
(select customer_id,plan_id
from (select *,
row_number() over(partition by customer_id order by start_date desc) as latest_plan
from subscriptions
order by customer_id) as ranked
where latest_plan=1)
select 
count(case when plan_id=1 then customer_id end) as num_of_plan1,
count(case when plan_id=2 then customer_id end) as num_of_plan2,
count(case when plan_id=3 then customer_id end) as num_of_plan3,
count(case when plan_id=4 then customer_id end) as num_of_plan4
from cte;

-- What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
with cte as 
(select customer_id,plan_id
from (select *,
row_number() over(partition by customer_id order by start_date desc) as latest_plan
from subscriptions
where start_date<'2020-12-31'
order by customer_id) as ranked
where latest_plan=1)
select 
count(case when plan_id=0 then customer_id end) as num_of_plan0,
count(case when plan_id=1 then customer_id end) as num_of_plan1,
count(case when plan_id=2 then customer_id end) as num_of_plan2,
count(case when plan_id=3 then customer_id end) as num_of_plan3,
count(case when plan_id=4 then customer_id end) as num_of_plan4
from cte;

-- How many customers have upgraded to an annual plan in 2020?
select count(distinct(customer_id))
from subscriptions
where plan_id=3 and start_date<'2021-01-01';

-- How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
with cte1 as
(select customer_id,min(start_date) as date_of_join
from subscriptions
group by customer_id
order by customer_id),
cte2 as
(select customer_id,start_date as date_of_upgrade
from subscriptions
where plan_id=3
order by customer_id)
select avg(timestampdiff(day,cte1.date_of_join,cte2.date_of_upgrade)) as avg_time
from cte1
join cte2 on cte1.customer_id=cte2.customer_id;

-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
with cte1 as
(select customer_id,min(start_date) as date_of_join
from subscriptions
group by customer_id
order by customer_id),
cte2 as
(select customer_id,start_date as date_of_upgrade
from subscriptions
where plan_id=3
order by customer_id)
select 
count(case when timestampdiff(day,cte1.date_of_join,cte2.date_of_upgrade)<30 then cte1.customer_id end) as less_than_30,
count(case when timestampdiff(day,cte1.date_of_join,cte2.date_of_upgrade) between 30 and 60 then cte1.customer_id end) as less_than_60,
count(case when timestampdiff(day,cte1.date_of_join,cte2.date_of_upgrade)>60 then cte1.customer_id end) as more_than_30
from cte1
join cte2 on cte1.customer_id=cte2.customer_id;

-- How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
select subs1.customer_id,subs1.start_date,subs2.start_date
from subscriptions as subs1
join subscriptions as subs2 on subs1.plan_id=2 and subs2.plan_id=1 and subs1.customer_id=subs2.customer_id
and subs1.start_date<subs2.start_date
where subs1.start_date<'2021-01-01' and subs2.start_date<'2021-01-01';

-- Challenge Payment Question
with cte as
(select subscriptions.customer_id,subscriptions.plan_id,plans.plan_name,plans.price,
subscriptions.start_date,
lag(plans.plan_id,1,Null) over (partition by subscriptions.customer_id order by subscriptions.start_date) as prev_plan
from subscriptions
join plans on subscriptions.plan_id=plans.plan_id)
select customer_id,plan_id,plan_name,start_date,
case when prev_plan=1 and plan_id in ('2','3') then price-9.9
when plan_id=4 then 0
else price end as payment
from cte;
