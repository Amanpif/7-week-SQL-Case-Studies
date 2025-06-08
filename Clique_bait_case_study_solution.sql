use clique_bait;

-- How many users are there?
select count(distinct user_id)
from users;

-- How many cookies does each user have on average?
select avg(number_of_cookies)
from (select user_id,
count(distinct cookie_id) as number_of_cookies
from users
group by user_id) as rans;

-- What is the unique number of visits by all users per month?
select month(event_time),
count(distinct(visit_id)) as number_of_visits
from events
group by month(event_time);

-- What is the number of events for each event type?
select event_type,
count(*) as number_of_events
from events
group by event_type;

-- What is the percentage of visits which have a purchase event?
select ((select count(distinct visit_id) from events where event_type=3)/
(select count(distinct visit_id) from events))*100 as percentage_of_purchases;

-- What is the percentage of visits which view the checkout page but do not have a purchase event?
select ((select count(distinct visit_id) from events where page_id=12 and visit_id not in 
(select distinct visit_id from events where event_type=3))/
(select count(distinct visit_id) from events))*100 as percentage;

-- What are the top 3 pages by number of views?
select page_id,count(distinct(visit_id)) as number_of_views                            
from events
group by page_id
order by count(distinct(visit_id)) desc
limit 3;

-- What is the number of views and cart adds for each product category?
select page_hierarchy.product_category,
count(distinct(case when events.event_type=1 then visit_id end)) as view_count,
count(distinct(case when events.event_type=3 then visit_id end)) as add_count
from events
join page_hierarchy on events.page_id=page_hierarchy.page_id
group by page_hierarchy.product_category;

-- What are the top 3 products by purchases?
select page_hierarchy.product_id,
count(distinct(case when event_type=3 then visit_id end)) as number_of_purchases
from events
join page_hierarchy on events.page_id=page_hierarchy.page_id
group by page_hierarchy.product_id 
order by count(distinct(case when event_type=3 then visit_id end)) desc
limit 3;

-- PRODUCT FUNNEL ANALYSIS
select page_hierarchy.product_id,
count(distinct(case when event_type=3 then visit_id end)) as number_of_purchases,
count(distinct(case when event_type=2 then visit_id end)) as number_of_cart_addition,
count(distinct(case when event_type=1 then visit_id end)) as number_of_views,
COUNT(DISTINCT CASE 
        WHEN events.event_type = 2 
             AND NOT EXISTS (
                 SELECT 1 
                 FROM events e2
                 JOIN page_hierarchy ph2 
                   ON e2.page_id = ph2.page_id
                 WHERE e2.event_type = 3
                   AND e2.visit_id = events.visit_id
                   AND ph2.product_id = page_hierarchy.product_id
             )
        THEN events.visit_id 
    END)
 as number_of_addition_but_not_purchased
from events
join page_hierarchy on events.page_id=page_hierarchy.page_id
group by page_hierarchy.product_id;

-- Step 1: Precompute visit-product purchases
WITH purchased_products AS (
    SELECT DISTINCT
        ph.product_id,
        e.visit_id
    FROM events e
    JOIN page_hierarchy ph ON e.page_id = ph.page_id
    WHERE e.event_type = 3
),

-- Step 2: Combine events with product info
product_events AS (
    SELECT
        ph.product_id,
        e.event_type,
        e.visit_id
    FROM events e
    JOIN page_hierarchy ph ON e.page_id = ph.page_id
)

-- Step 3: Final aggregation
SELECT 
    pe.product_id,
    
    COUNT(DISTINCT CASE WHEN pe.event_type = 3 THEN pe.visit_id END) AS number_of_purchases,
    
    COUNT(DISTINCT CASE WHEN pe.event_type = 2 THEN pe.visit_id END) AS number_of_cart_addition,
    
    COUNT(DISTINCT CASE WHEN pe.event_type = 1 THEN pe.visit_id END) AS number_of_views,
    
    COUNT(DISTINCT CASE 
        WHEN pe.event_type = 2 AND NOT EXISTS (
            SELECT 1
            FROM purchased_products pp
            WHERE pp.product_id = pe.product_id AND pp.visit_id = pe.visit_id
        )
        THEN pe.visit_id 
    END) AS number_of_addition_but_not_purchased

FROM product_events pe
GROUP BY pe.product_id
ORDER BY pe.product_id;


-- similar for product_category
with purchased_items as
(select 
distinct events.visit_id,page_hierarchy.product_category
from events
join page_hierarchy on events.page_id=page_hierarchy.page_id
where events.event_type=3
)
select page_hierarchy.product_category,
count(distinct(case when event_type=3 then visit_id end)) as number_of_purchases,
count(distinct(case when event_type=2 then visit_id end)) as number_of_cart_addition,
count(distinct(case when event_type=1 then visit_id end)) as number_of_views,
count(distinct(
case when event_type=2 and not exists
(select * from purchased_items 
where purchased_items.visit_id=events.visit_id and purchased_items.product_category=page_hierarchy.product_category )
then events.visit_id end))as number_of_add_but_not_purchased
from events
join page_hierarchy on events.page_id=page_hierarchy.page_id
group by page_hierarchy.product_category;


-- CAMPAIGN ANALYSIS
with cte as 
(
select distinct events.visit_id,
users.user_id,
min(events.event_time) as visit_start_time,
count(events.page_id) as page_views,
count(case when event_type=2 then event_type end) as cart_adds,
max(case when event_type=3 then 1 else 0 end) as purchase,
count(case when event_type=4 then event_type end) as impressions,
count(case when event_type=5 then event_type end) as click,
group_concat(
case when events.page_id>2 and events.page_id<12 and event_type=2 then product_id end order by sequence_number) as cart_products
from events
join users on events.cookie_id=users.cookie_id
join page_hierarchy on events.page_id=page_hierarchy.page_id
group by events.visit_id,users.user_id)
select visit_id,user_id,page_views,cart_adds,purchase,impressions,click,cart_products,
campaign_identifier.campaign_name
from cte
join campaign_identifier on cte.visit_start_time between campaign_identifier.start_date and campaign_identifier.end_date;








