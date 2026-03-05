-- ============================================================================
-- AMAZON FREIGHT OPERATIONS ANALYTICS - SQL QUERIES
-- Database: amazon_project
-- ============================================================================

-- Table Setup
CREATE TABLE amazon_orders (
    index_col INTEGER,
    order_id VARCHAR(50),
    order_date VARCHAR(20),
    order_status VARCHAR(100),
    fulfilment_type VARCHAR(20),
    sales_channel VARCHAR(50),
    service_level VARCHAR(20),
    category VARCHAR(50),
    size VARCHAR(10),
    courier_status VARCHAR(50),
    quantity INTEGER,
    currency VARCHAR(10),
    amount DECIMAL(10,2),
    ship_city VARCHAR(100),
    ship_state VARCHAR(100),
    ship_postal_code VARCHAR(20),
    ship_country VARCHAR(10),
    is_b2b BOOLEAN,
    fulfilled_by VARCHAR(50),
    new_col VARCHAR(50),
    pendings_col VARCHAR(50)
);

-- Convert date column to proper DATE type
ALTER TABLE amazon_orders
ALTER COLUMN order_date TYPE DATE
USING TO_DATE(order_date, 'MM-DD-YY');

-- Performance indexes
CREATE INDEX idx_order_date ON amazon_orders(order_date);
CREATE INDEX idx_order_status ON amazon_orders(order_status);
CREATE INDEX idx_fulfilment_type ON amazon_orders(fulfilment_type);
CREATE INDEX idx_ship_state ON amazon_orders(ship_state);

-- ============================================================================
-- KEY PERFORMANCE INDICATORS (KPIs)
-- ============================================================================

-- 1. Weekly Order Fulfillment Rate
WITH weekly_metrics AS (
    SELECT 
        DATE_TRUNC('week', order_date)::DATE AS week_start,
        COUNT(*) AS total_orders,
        COUNT(*) FILTER (WHERE order_status IN ('Shipped', 'Shipped - Delivered to Buyer', 'Shipped - Picked Up')) AS successful_orders,
        COUNT(*) FILTER (WHERE order_status ILIKE '%Cancelled%') AS cancelled_orders
    FROM amazon_orders
    GROUP BY 1
)
SELECT *,
       ROUND(100.0 * successful_orders / total_orders, 2) AS ofr_pct,
       ROUND(100.0 * cancelled_orders / total_orders, 2) AS cancellation_rate
FROM weekly_metrics
ORDER BY week_start;

-- 2. Cancellation Analysis by Fulfilment and State
SELECT 
    fulfilment_type,
    service_level,
    ship_state,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled_orders,
    ROUND(100.0 * COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) / COUNT(*), 2) AS cancellation_rate,
    SUM(CASE WHEN order_status = 'Cancelled' THEN COALESCE(amount, 0) ELSE 0 END) AS revenue_loss
FROM amazon_orders
GROUP BY fulfilment_type, service_level, ship_state
HAVING COUNT(*) >= 50
ORDER BY cancellation_rate DESC
LIMIT 20;

-- 3. Revenue Per Order Trend
SELECT 
    DATE_TRUNC('week', order_date)::DATE AS week_start,
    fulfilment_type,
    CASE WHEN is_b2b THEN 'B2B' ELSE 'B2C' END AS segment,
    COUNT(*) AS order_count,
    SUM(amount) AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_revenue_per_order
FROM amazon_orders
WHERE amount IS NOT NULL AND order_status NOT ILIKE '%cancel%'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- 4. Service Level Performance
SELECT 
    service_level,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN order_status IN ('Shipped - Delivered to Buyer', 'Shipped - Picked Up') THEN 1 END) AS delivered_orders,
    ROUND(100.0 * COUNT(CASE WHEN order_status IN ('Shipped - Delivered to Buyer', 'Shipped - Picked Up') THEN 1 END) / COUNT(*), 2) AS delivery_success_rate
FROM amazon_orders
GROUP BY service_level;

-- 5. Return Rate by Category
SELECT 
    category,
    ship_state,
    COUNT(*) AS delivered_orders,
    COUNT(CASE WHEN order_status ILIKE '%Return%' OR order_status ILIKE '%Reject%' THEN 1 END) AS returned_orders,
    ROUND(100.0 * COUNT(CASE WHEN order_status ILIKE '%Return%' OR order_status ILIKE '%Reject%' THEN 1 END) / COUNT(*), 2) AS return_rate
FROM amazon_orders
WHERE order_status NOT IN ('Cancelled', 'Pending')
GROUP BY category, ship_state
HAVING COUNT(*) >= 30
ORDER BY return_rate DESC
LIMIT 20;

-- 6. Fulfilment Type Comparison
SELECT 
    fulfilment_type,
    COUNT(*) AS total_orders,
    SUM(amount) AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_order_value,
    ROUND(100.0 * COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) / COUNT(*), 2) AS cancellation_rate
FROM amazon_orders
GROUP BY fulfilment_type;

-- 7. B2B vs B2C Performance
SELECT 
    CASE WHEN is_b2b THEN 'B2B' ELSE 'B2C' END AS segment,
    COUNT(*) AS order_count,
    SUM(amount) AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_order_value,
    ROUND(100.0 * COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) / COUNT(*), 2) AS cancellation_rate
FROM amazon_orders
GROUP BY is_b2b;

-- 8. Top States by Revenue
SELECT 
    ship_state,
    COUNT(*) AS order_count,
    SUM(amount) AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_order_value,
    ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 2) AS pct_of_total_revenue
FROM amazon_orders
WHERE amount IS NOT NULL
GROUP BY ship_state
ORDER BY total_revenue DESC
LIMIT 10;

-- 9. Category Performance
SELECT 
    category,
    COUNT(*) AS total_orders,
    SUM(amount) AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_revenue_per_order,
    ROUND(100.0 * COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) / COUNT(*), 2) AS cancellation_rate
FROM amazon_orders
GROUP BY category
ORDER BY total_revenue DESC;

-- 10. Daily Operations Snapshot
SELECT 
    order_date,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN order_status IN ('Shipped', 'Shipped - Delivered to Buyer') THEN 1 END) AS successful,
    COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) AS cancelled,
    SUM(amount) AS daily_revenue
FROM amazon_orders
WHERE order_date >= (SELECT MAX(order_date) - INTERVAL '30 DAYS' FROM amazon_orders)
GROUP BY order_date
ORDER BY order_date DESC;

-- ============================================================================
-- DEEP DIVE ANALYSES
-- ============================================================================

-- Cancellation Deep Dive
SELECT 
    fulfilment_type,
    service_level,
    category,
    COUNT(*) AS total_cancellations,
    ROUND(AVG(amount), 2) AS avg_order_value,
    STRING_AGG(DISTINCT courier_status, ', ') AS cancellation_stages
FROM amazon_orders
WHERE order_status = 'Cancelled'
GROUP BY fulfilment_type, service_level, category
ORDER BY total_cancellations DESC
LIMIT 20;

-- Geographic Performance Scorecard
SELECT 
    ship_state,
    COUNT(*) AS total_orders,
    SUM(amount) AS total_revenue,
    ROUND(100.0 * COUNT(CASE WHEN order_status IN ('Shipped', 'Shipped - Delivered to Buyer') THEN 1 END) / COUNT(*), 2) AS success_rate,
    ROUND(100.0 * COUNT(CASE WHEN order_status = 'Cancelled' THEN 1 END) / COUNT(*), 2) AS cancellation_rate
FROM amazon_orders
GROUP BY ship_state
HAVING COUNT(*) >= 50
ORDER BY success_rate ASC
LIMIT 20;

-- ============================================================================
-- ENRICHED VIEW WITH CALCULATED FIELDS
-- ============================================================================

CREATE OR REPLACE VIEW amazon_orders_enriched AS
SELECT 
    *,
    -- Delivery flags
    CASE WHEN order_status IN ('Shipped - Delivered to Buyer', 'Shipped - Picked Up') THEN TRUE ELSE FALSE END AS is_delivered_successfully,
    CASE WHEN order_status = 'Cancelled' THEN TRUE ELSE FALSE END AS is_cancelled,
    CASE WHEN order_status ILIKE '%Return%' OR order_status ILIKE '%Reject%' THEN TRUE ELSE FALSE END AS is_returned,
    
    -- Revenue loss
    CASE WHEN order_status = 'Cancelled' THEN COALESCE(amount, (SELECT AVG(amount) FROM amazon_orders WHERE amount IS NOT NULL)) ELSE 0 END AS revenue_loss,
    
    -- SLA status
    CASE 
        WHEN service_level = 'Expedited' AND courier_status = 'Shipped' THEN 'Met SLA'
        WHEN service_level = 'Expedited' AND courier_status = 'On the Way' AND order_date < CURRENT_DATE - 3 THEN 'Breached SLA'
        WHEN service_level = 'Standard' AND courier_status = 'Shipped' THEN 'Met SLA'
        WHEN service_level = 'Standard' AND courier_status = 'On the Way' AND order_date < CURRENT_DATE - 5 THEN 'Breached SLA'
        ELSE 'In Progress'
    END AS sla_status,
    
    -- Order value bucket
    CASE 
        WHEN amount < 400 THEN 'Low'
        WHEN amount < 600 THEN 'Medium'
        WHEN amount < 800 THEN 'High'
        ELSE 'Premium'
    END AS order_value_bucket,
    
    -- City tier
    CASE 
        WHEN ship_city IN ('BENGALURU', 'HYDERABAD', 'MUMBAI', 'NEW DELHI', 'CHENNAI', 'PUNE', 'KOLKATA') THEN 'Tier 1'
        WHEN ship_city IN ('GURGAON', 'THANE', 'LUCKNOW', 'JAIPUR', 'AHMEDABAD', 'CHANDIGARH') THEN 'Tier 2'
        ELSE 'Tier 3'
    END AS city_tier,
    
    -- Product line
    CASE 
        WHEN category IN ('T-shirt', 'Shirt') THEN 'Casual Wear'
        WHEN category IN ('Blazzer', 'Trousers') THEN 'Formal Wear'
        WHEN category IN ('Perfume', 'Watch', 'Wallet', 'Shoes', 'Socks') THEN 'Accessories'
        ELSE 'Other'
    END AS product_line,
    
    -- Customer segment
    CASE 
        WHEN is_b2b THEN 'B2B'
        WHEN service_level = 'Expedited' AND amount > 700 THEN 'Premium B2C'
        WHEN service_level = 'Expedited' THEN 'Standard B2C'
        ELSE 'Value B2C'
    END AS customer_segment

FROM amazon_orders;

-- Test enriched view
SELECT 
    order_id,
    is_cancelled,
    revenue_loss,
    sla_status,
    city_tier,
    customer_segment
FROM amazon_orders_enriched
LIMIT 10;