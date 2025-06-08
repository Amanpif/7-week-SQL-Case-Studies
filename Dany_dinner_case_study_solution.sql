use dannys_diner;

-- 1. What is the total amount each customer spent at the restaurant?
select sales.customer_id,sum(menu.price)
from sales
join menu on sales.product_id=menu.product_id
group by sales.customer_id;

-- 2. How many days has each customer visited the restaurant?
select sales.customer_id,count(distinct(sales.order_date)) as number_of_days
from sales
group by sales.customer_id;

-- 3. What was the first item from the menu purchased by each customer?
with purchased_item as(
select sales.customer_id,menu.product_id,menu.product_name,sales.order_date
from sales
join menu on sales.product_id=menu.product_id)
select customer_id,product_name from 
(select *,
row_number() over (partition by customer_id order by order_date) as rn
from purchased_item) as ranked
where rn=1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select customer_id,product_id,count(product_id) as number_of_purchases
from sales
where product_id=
(select product_id
from sales 
group by product_id
order by count(*) desc
limit 1
)
group by customer_id,product_id;

-- 5. Which item was the most popular for each customer?
select customer_id,product_id
from (select *,
row_number() over(partition by customer_id order by number_of_purchases desc) as rn
from (select sales.customer_id,sales.product_id,count(*) as number_of_purchases
from sales
group by customer_id,product_id) as ranked) as ran
where rn=1;

-- 6. Which item was purchased first by the customer after they became a member?
select * from
(select *,
row_number() over(partition by customer_id order by order_date) as rn
from
(select sales.customer_id,sales.product_id,sales.order_date,members.join_date
from sales
join members on sales.customer_id=members.customer_id
where sales.order_date>members.join_date) as ranked) as ran
where rn=1;

-- 7. Which item was purchased just before the customer became a member?
select * from
(select *,
row_number() over(partition by customer_id order by order_date desc) as rn
from
(select sales.customer_id,sales.product_id,sales.order_date,members.join_date
from sales
join members on sales.customer_id=members.customer_id
where sales.order_date<members.join_date) as ranked) as ran
where rn=1;

-- 8. What is the total items and amount spent for each member before they became a member?
select sales.customer_id,count(menu.product_id) as total_items,sum(menu.price) as amount_spent
from sales
join menu on sales.product_id=menu.product_id
join members on sales.customer_id=members.customer_id
where sales.order_date<members.join_date
group by sales.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
with cte as
(select sales.customer_id,menu.product_name,sum(menu.price) as amount_spent
from sales
join menu on sales.product_id=menu.product_id
group by sales.customer_id,menu.product_name)
select customer_id,sum(
case when product_name="sushi" then 20*amount_spent
else 10*amount_spent
end) as points
from cte
group by customer_id;

-- 10. In the first week after a customer joins the program (including their join date) 
-- they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
with cte as 
(select sales.customer_id,menu.product_name,
sum(case when sales.order_date<members.join_date then menu.price else 0 end) as amount_before_joining,
sum(case when sales.order_date>=members.join_date then menu.price else 0 end) as amount_after_joining
from sales
join menu on sales.product_id=menu.product_id
join members on sales.customer_id=members.customer_id
group by sales.customer_id,menu.product_name
order by sales.customer_id,menu.product_name)
select customer_id,
sum(case when product_name='sushi' then amount_before_joining*20+amount_after_joining*20 
else amount_before_joining*10+amount_after_joining*20 end) as points
from cte
group by customer_id;