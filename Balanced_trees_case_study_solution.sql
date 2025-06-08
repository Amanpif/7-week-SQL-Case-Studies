use balanced_trees;
show tables;

select * from sales;
select * from product_details;
select * from product_hierarchy;
select * from product_prices;
-- Cleaning
set sql_safe_updates=0;
update sales
set member=
case when member='t' then 1 
WHEN MEMBER='f' then 0 end;
set sql_safe_updates=1;

-- What was the total quantity sold for all products?
select prod_id,sum(qty) as quantity_sold
from sales
group by prod_id;

-- What is the total generated revenue for all products before discounts?
select prod_id,sum(qty*price) as revenue_before_discounts,
sum(qty*price*(1-(discount/100))) as revenue_after_discounts
from sales
group by prod_id;

-- What was the total discount amount for all products?
select sum(qty*price*(discount/100)) as total_discount_given
from sales;

-- How many unique transactions were there?
select count(distinct txn_id) as number_of_transactions
from sales;

-- What is the average unique products purchased in each transaction?
select avg(number_of_products) as avg_unique_prod_purchased_per_trans
from
(select txn_id,count(distinct prod_id) as number_of_products
from sales
group by txn_id) as rans;

-- What are the 25th, 50th and 75th percentile values for the revenue per transaction?
with reven_per_tran as 
(select txn_id,sum(qty*price*(1-(discount/100))) as revenue_per_transaction
from sales
group by txn_id
order by sum(qty*price*(1-(discount/100)))),
alias as 
(select *,
row_number() over (order by revenue_per_transaction) as ranked
from reven_per_tran)
select 
(select revenue_per_transaction from alias where ranked=floor((select count(*) from reven_per_tran)*0.25)) as `25th_percentile_rev_per_trans`,
(select revenue_per_transaction from alias where ranked=floor((select count(*) from reven_per_tran)*0.5))  as `50th_percentile_rev_per_trans`,
(select revenue_per_transaction from alias where ranked=ceil((select count(*) from reven_per_tran)*0.75)) as `75th_percentile_rev_per_trans`;

-- What is the average discount value per transaction?
select avg(avg_discount) as avg_discount_per_trans
from (select txn_id,avg(discount) as avg_discount
from sales
group by txn_id) as ran;

-- What is the percentage split of all transactions for members vs non-members?
with number_of_transactions as
(select count(distinct txn_id) as total from sales)
select 
((select count(distinct(txn_id)) from sales where member=0)/
total)*100 as percentage_of_nonmember_trans,
((select count(distinct(txn_id)) from sales where member=1)/
total)*100 as percentage_of_member_trans
from number_of_transactions;

--  What is the average revenue for member transactions and non-member transactions?
select 
member,avg(average_revenue) as average_revenue_
from
(select txn_id,member,
sum(qty*price) as average_revenue
from sales
group by txn_id,member)as ran
group by member;

-- What are the top 3 products by total revenue before discount?
select prod_id,
sum(qty*price) as total_revenue_for_product
from sales
group by prod_id
order by sum(qty*price) desc
limit 3;

-- What is the total quantity, revenue and discount for each segment?
select product_details.segment_name,
sum(qty) as total_quantity_sold,
sum(qty*sales.price) as total_revenue_generated,
avg(discount) as avg_discount_given
from sales 
join product_details on sales.prod_id=product_details.product_id
group by product_details.segment_name;

-- What is the top selling product for each segment?
with cte as
(select product_details.segment_name,
product_details.product_name,
sum(qty) as amount_sold
from sales
join product_details on sales.prod_id=product_details.product_id
group by product_details.segment_name,product_details.product_name)
select segment_name,product_name as most_selling_product from
(select *,
row_number() over (partition by segment_name order by amount_sold desc) as rn
from cte) as rans
where rn=1;

-- What is the total quantity, revenue and discount for each category?
select product_details.category_name,
sum(qty) as total_quantity,
sum(qty*sales.price) as revnue,
avg(discount) as discount
from sales
join product_details on sales.prod_id=product_details.product_id
group by product_details.category_name;

-- What is the top selling product for each category?
with cte as
(select product_details.category_name,product_details.product_name,
sum(qty) as amount_sold
from sales 
join product_details on sales.prod_id=product_details.product_id
group by product_details.category_name,product_details.product_name)
select category_name,product_name as most_Selling_product
from
(select *,
row_number() over (partition by category_name order by amount_sold desc)as rn
from cte) as ran
where rn=1;

-- What is the percentage split of total revenue by segment?
with cte as
(select product_details.segment_name,
sum(qty*sales.price) as revenue_generated
from sales
join product_details on sales.prod_id=product_details.product_id
group by product_details.segment_name),
cte2 as(
select sum(revenue_generated) as total_revenue from cte )
select segment_name,
(revenue_generated/(select total_revenue from cte2))*100 as percentage_of_share_in_revenue
from cte;

-- What is the percentage split of revenue by product for each segment?
with cte1 as
(select product_details.segment_name,product_details.product_name,
sum(qty*sales.price) as revenue_generated
from sales
join product_details on sales.prod_id=product_details.product_id
group by product_details.segment_name,product_details.product_name),
cte2 as
(select product_details.segment_name,
sum(qty*sales.price) as total_revenue
from sales
join product_details on sales.prod_id=product_details.product_id
group by product_details.segment_name
)
select cte1.segment_name,cte1.product_name,
(cte1.revenue_generated/cte2.total_revenue)*100 as percentage_share_by_product
from cte1
join cte2 on cte1.segment_name=cte2.segment_name
order by cte1.segment_name;

-- What is the percentage split of revenue by category for each category?
with cte1 as
(select product_details.category_name,product_details.product_name,
sum(qty*sales.price) as revenue_generated
from sales
join product_details on sales.prod_id=product_details.product_id
group by product_details.category_name,product_details.product_name),
cte2 as
(select product_details.category_name,
sum(qty*sales.price) as total_revenue
from sales
join product_details on sales.prod_id=product_details.product_id
group by product_details.category_name
)
select cte1.category_name,cte1.product_name,
(cte1.revenue_generated/cte2.total_revenue)*100 as percentage_share_by_product
from cte1
join cte2 on cte1.category_name=cte2.category_name
order by cte1.category_name;


-- What is the total transaction “penetration” for each product? 
-- (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
with cte1 as
(select product_details.product_name,
count(distinct sales.txn_id) as number_of_purchases
from sales
join product_details on sales.prod_id=product_details.product_id
group by product_details.product_name),
cte2 as 
(select count(distinct txn_id) as total_transactions from sales)
select product_name,
(number_of_purchases/(select total_transactions from cte2))*100 as penetration
from cte1;

-- What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
WITH product_in_txn AS (
  SELECT txn_id, pd.product_name
  FROM sales s
  JOIN product_details pd ON s.prod_id = pd.product_id
  GROUP BY txn_id, pd.product_name
),
combinations AS (
  SELECT 
    a.txn_id,
    a.product_name AS product_1,
    b.product_name AS product_2,
    c.product_name AS product_3
  FROM product_in_txn a
  JOIN product_in_txn b ON a.txn_id = b.txn_id AND a.product_name < b.product_name
  JOIN product_in_txn c ON a.txn_id = c.txn_id AND b.product_name < c.product_name
)
SELECT 
  product_1, product_2, product_3,
  COUNT(*) AS combo_count
FROM combinations
GROUP BY product_1, product_2, product_3
ORDER BY combo_count DESC
LIMIT 1;

 