use pizza_runner;

-- Cleaning data in customer_id
select * from customer_orders;
SET SQL_SAFE_UPDATES = 0;
UPDATE customer_orders
SET exclusions = NULL
WHERE exclusions = 'null' OR exclusions = '';
SET SQL_SAFE_UPDATES = 1; 
SET SQL_SAFE_UPDATES = 0;
UPDATE customer_orders
SET extras = NULL
WHERE extras = 'null' OR extras = '';
SET SQL_SAFE_UPDATES = 1; 

select * from pizza_names;
select * from pizza_recipes;
select * from pizza_toppings;
select * from runner_orders;

-- Cleaning data in runner_orders
select * from runner_orders;
set sql_safe_updates=0;
update runner_orders
set duration=Null where duration='null';
update runner_orders
set cancellation=Null where cancellation='null' or cancellation='';
update runner_orders
set distance=Null where distance='null';
update runner_orders
set pickup_time=Null where pickup_time='null';
set sql_safe_updates=1;

set sql_safe_updates=0;
update runner_orders
set distance=trim(replace(replace(distance,'km',''),' ',''));
update runner_orders
set duration=trim(replace(REPLACE(REPLACE(REPLACE(duration, 'minute', ''), 'minutes', ''), 'mins', ''),' ',''));
set sql_safe_updates=1;

set sql_safe_updates=0;
update runner_orders
set duration=trim(replace(duration,'s',''));
set sql_safe_updates=1;

-- CASE STUDY QUERIES
-- How many pizzas were ordered?
select count(*) as number_of_orders
from runner_orders
where cancellation is Null;

-- How many unique customer orders were made?
select count(distinct(customer_id)) as unique_customers
from customer_orders;

-- How many successful orders were delivered by each runner?
select runner_id,count(order_id) as number_of_orders
from runner_orders
where cancellation is Null
group by runner_id;

-- How many of each type of pizza was delivered?
select customer_orders.pizza_id,count(*) as number_of_deliveries
from runner_orders
join customer_orders on runner_orders.order_id=customer_orders.order_id
group by customer_orders.pizza_id;

-- How many Vegetarian and Meatlovers were ordered by each customer?
select customer_orders.customer_id,pizza_names.pizza_name,count(*) as number_of_orders
from customer_orders
join pizza_names on customer_orders.pizza_id=pizza_names.pizza_id
group by customer_orders.customer_id,pizza_names.pizza_name;

-- What was the maximum number of pizzas delivered in a single order?
select customer_orders.order_id,count(customer_orders.pizza_id) as number_of_pizzas
from customer_orders
join runner_orders on customer_orders.order_id=runner_orders.order_id
where runner_orders.cancellation is Null
group by customer_orders.order_id
order by count(customer_orders.pizza_id) desc
limit 1;

-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select customer_orders.customer_id,
sum(case when customer_orders.exclusions is not Null or customer_orders.extras is not Null then customer_orders.pizza_id end) as changed_orders,
sum(case when customer_orders.exclusions is Null and customer_orders.extras is Null then customer_orders.pizza_id end) as unchanged_orders
from customer_orders
join runner_orders on customer_orders.order_id=runner_orders.order_id
where runner_orders.cancellation is Null
group by customer_orders.customer_id;

-- How many pizzas were delivered that had both exclusions and extras?
select sum(customer_orders.pizza_id) as number_of_pizzas
from customer_orders
join runner_orders on customer_orders.order_id=runner_orders.order_id
where runner_orders.cancellation is Null and (customer_orders.exclusions is not Null and customer_orders.extras is not Null);

-- What was the total volume of pizzas ordered for each hour of the day?
select hour(customer_orders.order_time) as dayhour,
count(customer_orders.pizza_id) as number_of_pizzas
from customer_orders
group by hour(customer_orders.order_time);

-- What was the volume of orders for each day of the week?
select weekday(customer_orders.order_time) as weekday,
count(customer_orders.pizza_id) as number_of_pizzas
from customer_orders
group by weekday(customer_orders.order_time);

-- What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
select runner_id,avg(duration) as avg_del_time
from runner_orders
group by runner_id;

-- Is there any relationship between the number of pizzas and how long the order takes to prepare?
SELECT 
  COUNT(co.pizza_id) AS number_of_pizzas,
  AVG(TIMESTAMPDIFF(MINUTE, co.order_time, ro.pickup_time)) AS avg_prep_time
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL
GROUP BY co.order_id;

-- What was the average distance travelled for each customer?
select customer_orders.customer_id,avg(runner_orders.distance)
from customer_orders
join runner_orders on customer_orders.order_id=runner_orders.order_id
group by customer_orders.customer_id;

-- What was the difference between the longest and shortest delivery times for all orders?
select max(duration)-min(duration)
from runner_orders
where cancellation is Null;

-- What was the average speed for each runner for each delivery and do you notice any trend for these values?
select runner_id,order_id,(distance/duration) as speed_of_delivery_in_km_per_min
from runner_orders
where cancellation is Null;

-- What is the successful delivery percentage for each runner?
select runner_id,
(count(case when cancellation is Null then order_id end)/
count(order_id))*100 as delivery_success_percentage
from runner_orders
group by runner_id;

-- If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges
-- for changes - how much money has Pizza Runner made so far if there are no delivery fees?
with orders as 
(select customer_orders.pizza_id,count(*) as number_of_orders
from customer_orders
join runner_orders on customer_orders.order_id=runner_orders.order_id
where runner_orders.cancellation is Null
group by customer_orders.pizza_id)
select 
sum(case when pizza_id=1 then 10*number_of_orders else 12*number_of_orders end) as amount
from orders; 

-- What if there was an additional $1 charge for any pizza extras?
-- Add cheese is $1 extra
select 
find_in_set((select topping_id from pizza_toppings where topping_name='Cheese'),toppings)
from pizza_recipes;

select * from pizza_recipes;
select * from pizza_toppings;


-- If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner
--  is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
