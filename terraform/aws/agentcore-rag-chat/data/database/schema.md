# Sample business data schema

This lightweight "database" is represented as CSV files for the RAG sample. It models a tiny online store.

## customers.csv

| column | description |
| --- | --- |
| customer_id | Unique customer identifier (e.g. C001) |
| name | Customer full name |
| country | Country of the billing address |
| signup_date | ISO date the customer registered |

## products.csv

| column | description |
| --- | --- |
| product_id | Unique product identifier (e.g. P001) |
| name | Product name |
| category | Product category |
| unit_price_usd | Price per unit in USD |

## orders.csv

| column | description |
| --- | --- |
| order_id | Unique order identifier (e.g. O1001) |
| customer_id | References customers.customer_id |
| product_id | References products.product_id |
| quantity | Number of units ordered |
| order_date | ISO date the order was placed |

Relationships: each order belongs to one customer and one product. Join orders to customers on `customer_id` and to products on `product_id`.
