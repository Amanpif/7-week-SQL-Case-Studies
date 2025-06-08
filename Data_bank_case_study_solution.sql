use data_bank;

-- How many unique nodes are there on the Data Bank system?
select count(distinct(node_id)) as num_of_nodes
from customer_nodes;

-- What is the number of nodes per region?
select region_id,count(distinct(node_id)) as num_of_nodes
from customer_nodes
group by region_id
order by region_id;

-- How many customers are allocated to each region?
select region_id,count(distinct(customer_id)) as num_of_customer
from customer_nodes
group by region_id;

-- How many days on average are customers reallocated to a different node?
select customer_id,avg(timestampdiff(day,start_date,end_date)) as duration
from customer_nodes
group by customer_id;

-- What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
with cte1 as 
(select *,timestampdiff(day,start_date,end_date) as duration,
row_number() over(partition by region_id order by timestampdiff(day,start_date,end_date)) as rn,
count(*) over (partition by region_id) as total_rows
from customer_nodes)
select region_id,
max(case when rn=floor(total_rows/2) then duration end) as median_duration,
max(case when rn=floor(0.8*total_rows) then duration end) as `80percentile_duration`,
max(case when rn=floor(0.95*total_rows) then duration end) as `95percentile_duration`
from cte1
group by region_id;

-- What is the unique count and total amount for each transaction type?
select txn_type,
count(distinct customer_id,txn_date,txn_type,txn_amount) as number_of_transactions,
sum(txn_amount) as amount_of_transaction
from customer_transactions
group by txn_type;

-- What is the average total historical deposit counts and amounts for all customers?
select avg(txn_amount),sum(txn_amount)
from customer_transactions
where txn_type='deposit';

-- For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
select month,count(customer_id) as num_of_customers
from 
(select month(txn_date) as month,customer_id,
count(case when txn_type='deposit' then customer_id end) as number_of_deposits,
count(case when txn_type='purchase' then customer_id end) as number_of_purchase,
count(case when txn_type='withdrawal' then customer_id end) as number_of_withdrawal
from customer_transactions
group by month(txn_date),customer_id) as ran
where number_of_deposits>1 and (number_of_purchase=1 or number_of_withdrawal=1)
group by month;

-- What is the closing balance for each customer at the end of the month?
with cte as 
(select customer_id,month(txn_date) as month,
sum(case when txn_type='deposit' then txn_amount end) as deposit,
sum(case when txn_type='purchase' then txn_amount end) as purchase,
sum(case when txn_type='withdrawal' then txn_amount end) as withdrawal
from customer_transactions
group by customer_id,month(txn_date)
)
select *,
sum((deposit-COALESCE(purchase,0)-COALESCE(withdrawal,0))) over(partition by customer_id order by month) as left_over
from cte;


WITH cte AS (
  SELECT 
    customer_id,
    DATE_FORMAT(txn_date, '%Y-%m') AS month,
    SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS deposit,
    SUM(CASE WHEN txn_type = 'purchase' THEN txn_amount ELSE 0 END) AS purchase,
    SUM(CASE WHEN txn_type = 'withdrawal' THEN txn_amount ELSE 0 END) AS withdrawal
  FROM customer_transactions
  GROUP BY customer_id, DATE_FORMAT(txn_date, '%Y-%m')
)
SELECT *,
  SUM(deposit - COALESCE(purchase, 0) - COALESCE(withdrawal, 0)) 
    OVER (PARTITION BY customer_id ORDER BY month) AS left_over
FROM cte;

-- What is the percentage of customers who increase their closing balance by more than 5%?
with cte as
(select *,
row_number() over(partition by customer_id order by txn_date) as rn
from customer_transactions)
select ((select count(customer_id)
from
(select customer_id,
max(case when rn=1 then txn_amount end) as starting_amount,
sum(case when txn_type='deposit' then txn_amount else (-txn_amount) end) as ending_amount
from cte
group by customer_id
having ending_amount>0 and (starting_amount/ending_amount)*100>5) as ran)
/
(select count(distinct(customer_id)) from customer_transactions))*100 
as percentage_of_customers;



