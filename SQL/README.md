# SQL Analysis Queries - Amazon Freight Dashboard

Complete collection of PostgreSQL queries used in the analysis.

---

## TABLE CREATION

### Main Orders Table
```sql
CREATE TABLE amazon_orders (
    -- Primary Key
    order_id VARCHAR(30) PRIMARY KEY,
    
    -- Order Information
    order_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL,
    fulfilment VARCHAR(20),
    sales_channel VARCHAR(20),
    service_level VARCHAR(20),
    
    -- Product Details
    category VARCHAR(50),
    size VARCHAR(10),
    quantity DECIMAL(10,2) DEFAULT 0,
    
    -- Financial
    currency VARCHAR(3) DEFAULT 'INR',
    amount DECIMAL(10,2) NOT NULL,
    
    -- Shipping
    courier_status VARCHAR(30),
    ship_city VARCHAR(100),
    ship_state VARCHAR(50),
    ship_postal_code VARCHAR(10),
    ship_country VARCHAR(3) DEFAULT 'IN',
    
    -- Flags
    is_b2b BOOLEAN DEFAULT FALSE,
    fulfilled_by VARCHAR(20),
    
    -- Derived Columns (from Python enrichment)
    delivered BOOLEAN,
    cancelled BOOLEAN,
    returned BOOLEAN,
    revenue_loss DECIMAL(10,2) DEFAULT 0,
    city_tier VARCHAR(10),
    product_group VARCHAR(30),
    week_number INT,
    month_name VARCHAR(10),
    success_flag INT,
    days_old DECIMAL(10,2),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

### Performance Indexes
```sql
-- Date-based queries
CREATE INDEX idx_order_date ON amazon_orders(order_date);

-- Geographic analysis
CREATE INDEX idx_ship_state ON amazon_orders(ship_state);
CREATE INDEX idx_ship_city ON amazon_orders(ship_city);

-- Product analysis
CREATE INDEX idx_category ON amazon_orders(category);
CREATE INDEX idx_product_group ON amazon_orders(product_group);

-- Status tracking
CREATE INDEX idx_status ON amazon_orders(status);
CREATE INDEX idx_courier_status ON amazon_orders(courier_status);

-- Performance filters
CREATE INDEX idx_success_flag ON amazon_orders(success_flag);
CREATE INDEX idx_cancelled ON amazon_orders(cancelled);

-- Composite indexes for common queries
CREATE INDEX idx_state_service ON amazon_orders(ship_state, service_level);
CREATE INDEX idx_date_status ON amazon_orders(order_date, status);
```

---

## DATA IMPORT

### Copy from CSV
```sql
COPY amazon_orders (
    order_id, order_date, status, fulfilment, service_level,
    category, courier_status, quantity, amount, ship_city, ship_state,
    is_b2b, delivered, cancelled, returned, revenue_loss,
    city_tier, product_group, week_number, month_name, success_flag, days_old
)
FROM '/path/to/amazon_enriched.csv'
DELIMITER ','
CSV HEADER;
```

### Verify Import
```sql
SELECT 
    COUNT(*) as total_records,
    MIN(order_date) as earliest_date,
    MAX(order_date) as latest_date,
    SUM(amount) as total_revenue
FROM amazon_orders;

-- Expected: 128,976 records, ₹77,765,433 revenue
```

---

## CORE BUSINESS METRICS

### 1. Overall Performance Summary
```sql
SELECT 
    COUNT(*) as total_orders,
    COUNT(DISTINCT order_id) as unique_orders,
    SUM(amount) as total_revenue,
    ROUND(AVG(amount), 2) as avg_order_value,
    SUM(CASE WHEN success_flag = 1 THEN 1 ELSE 0 END) as successful_orders,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    SUM(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) as cancelled_orders,
    ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancellation_rate,
    SUM(revenue_loss) as total_revenue_loss
FROM amazon_orders;
```

**Output:**
```
total_orders: 128,976
total_revenue: ₹77,765,433
avg_order_value: ₹602.94
success_rate: 82.51%
cancellation_rate: 14.08%
total_revenue_loss: ₹6,828,687
```

---

### 2. Monthly Trend Analysis
```sql
SELECT 
    month_name,
    COUNT(*) as orders,
    SUM(amount) as revenue,
    ROUND(AVG(amount), 2) as aov,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancel_rate
FROM amazon_orders
GROUP BY month_name
ORDER BY 
    CASE month_name
        WHEN 'April' THEN 1
        WHEN 'May' THEN 2
        WHEN 'June' THEN 3
    END;
```

---

## GEOGRAPHIC ANALYSIS

### 3. State Performance Ranking
```sql
WITH state_metrics AS (
    SELECT 
        ship_state,
        COUNT(*) as total_orders,
        SUM(amount) as revenue,
        SUM(CASE WHEN success_flag = 1 THEN 1 ELSE 0 END) as successful_orders,
        SUM(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) as cancelled_orders,
        ROUND(AVG(success_flag) * 100, 2) as success_rate,
        ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancel_rate
    FROM amazon_orders
    GROUP BY ship_state
)
SELECT 
    ship_state,
    total_orders,
    revenue,
    success_rate,
    cancel_rate,
    RANK() OVER (ORDER BY success_rate DESC) as performance_rank
FROM state_metrics
WHERE total_orders >= 1000
ORDER BY success_rate DESC
LIMIT 10;
```

---

### 4. State × Service Level Performance Matrix
```sql
SELECT 
    ship_state,
    service_level,
    COUNT(*) as orders,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancel_rate
FROM amazon_orders
WHERE ship_state IN (
    SELECT ship_state 
    FROM amazon_orders 
    GROUP BY ship_state 
    ORDER BY COUNT(*) DESC 
    LIMIT 10
)
GROUP BY ship_state, service_level
ORDER BY ship_state, service_level;
```

**Key Finding:** Uttar Pradesh Standard = 73.11% success vs 86.39% Expedited

---

### 5. Top 20 Cities by Revenue
```sql
SELECT 
    ship_city,
    ship_state,
    COUNT(*) as orders,
    SUM(amount) as revenue,
    ROUND(AVG(amount), 2) as aov,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancel_rate
FROM amazon_orders
WHERE ship_city IS NOT NULL
GROUP BY ship_city, ship_state
ORDER BY revenue DESC
LIMIT 20;
```

---

## PRODUCT ANALYSIS

### 6. Category Revenue Distribution (Pareto)
```sql
WITH category_revenue AS (
    SELECT 
        category,
        SUM(amount) as revenue,
        COUNT(*) as orders,
        SUM(SUM(amount)) OVER () as total_revenue
    FROM amazon_orders
    WHERE success_flag = 1
    GROUP BY category
)
SELECT 
    category,
    revenue,
    orders,
    ROUND(revenue / total_revenue * 100, 2) as revenue_pct,
    SUM(ROUND(revenue / total_revenue * 100, 2)) 
        OVER (ORDER BY revenue DESC) as cumulative_pct
FROM category_revenue
ORDER BY revenue DESC;
```

**Key Insight:** Top 2 categories = 77% of revenue

---

### 7. Category Performance Scorecard
```sql
SELECT 
    category,
    COUNT(*) as total_orders,
    SUM(amount) as revenue,
    ROUND(AVG(amount), 2) as aov,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancel_rate,
    ROUND(AVG(CASE WHEN returned = TRUE THEN 1 ELSE 0 END) * 100, 2) as return_rate
FROM amazon_orders
GROUP BY category
ORDER BY revenue DESC;
```

---

## OPERATIONAL ANALYTICS

### 8. At-Risk Orders (Delayed >5 Days)
```sql
SELECT 
    order_id,
    order_date,
    ship_state,
    ship_city,
    service_level,
    amount,
    CURRENT_DATE - order_date as days_in_transit,
    CASE 
        WHEN service_level = 'Expedited' AND 
             (CURRENT_DATE - order_date) > 3 
        THEN 'High Priority - Expedited SLA Breach'
        WHEN service_level = 'Standard' AND 
             (CURRENT_DATE - order_date) > 5 
        THEN 'Medium Priority - Standard SLA Breach'
        ELSE 'On Track'
    END as priority
FROM amazon_orders
WHERE courier_status = 'On the Way'
  AND (CURRENT_DATE - order_date) > 5
ORDER BY days_in_transit DESC;
```

**Critical Finding:** 6,424 orders at risk

---

### 9. SLA Compliance Analysis
```sql
WITH sla_analysis AS (
    SELECT 
        service_level,
        COUNT(*) as orders,
        AVG(CASE 
            WHEN courier_status = 'On the Way' 
            THEN CURRENT_DATE - order_date 
            ELSE NULL 
        END) as avg_transit_days,
        SUM(CASE 
            WHEN service_level = 'Expedited' AND 
                 (CURRENT_DATE - order_date) > 3 AND
                 courier_status = 'On the Way'
            THEN 1
            WHEN service_level = 'Standard' AND 
                 (CURRENT_DATE - order_date) > 5 AND
                 courier_status = 'On the Way'
            THEN 1
            ELSE 0
        END) as sla_breaches
    FROM amazon_orders
    WHERE courier_status = 'On the Way'
    GROUP BY service_level
)
SELECT 
    service_level,
    orders,
    ROUND(avg_transit_days, 1) as avg_transit_days,
    sla_breaches,
    ROUND(sla_breaches::DECIMAL / orders * 100, 2) as sla_breach_pct
FROM sla_analysis;
```

---

### 10. Fulfillment Channel Comparison
```sql
SELECT 
    fulfilment,
    COUNT(*) as orders,
    SUM(amount) as revenue,
    ROUND(AVG(amount), 2) as aov,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancel_rate,
    SUM(revenue_loss) as revenue_loss
FROM amazon_orders
GROUP BY fulfilment
ORDER BY revenue DESC;
```

**Key Finding:** Amazon fulfillment: 86% success vs Merchant: 76%

---

## REVENUE ANALYSIS

### 11. Daily Revenue Trend
```sql
SELECT 
    order_date,
    COUNT(*) as orders,
    SUM(amount) as revenue,
    ROUND(AVG(amount), 2) as aov,
    -- 7-day moving average
    ROUND(AVG(SUM(amount)) OVER (
        ORDER BY order_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) as revenue_7day_ma
FROM amazon_orders
GROUP BY order_date
ORDER BY order_date;
```

---

### 12. Revenue Loss Breakdown
```sql
SELECT 
    status,
    COUNT(*) as cancelled_orders,
    SUM(amount) as potential_revenue,
    SUM(revenue_loss) as actual_loss,
    ROUND(SUM(revenue_loss) / SUM(amount) * 100, 2) as loss_percentage
FROM amazon_orders
WHERE cancelled = TRUE
GROUP BY status
ORDER BY actual_loss DESC;
```

**Total Loss:** ₹6.8M (8.8% of total revenue)

---

### 13. B2B vs B2C Analysis
```sql
SELECT 
    CASE WHEN is_b2b = TRUE THEN 'B2B' ELSE 'B2C' END as customer_type,
    COUNT(*) as orders,
    SUM(amount) as revenue,
    ROUND(AVG(amount), 2) as aov,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    ROUND(COUNT(*)::DECIMAL / SUM(COUNT(*)) OVER () * 100, 2) as order_pct
FROM amazon_orders
GROUP BY is_b2b;
```

**Opportunity:** Only 0.67% B2B penetration

---

## ADVANCED ANALYTICS

### 14. Cohort Analysis (Weekly Performance)
```sql
SELECT 
    week_number,
    COUNT(*) as orders,
    SUM(amount) as revenue,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancel_rate,
    LAG(ROUND(AVG(success_flag) * 100, 2)) OVER (ORDER BY week_number) as prev_week_success,
    ROUND(AVG(success_flag) * 100, 2) - 
        LAG(ROUND(AVG(success_flag) * 100, 2)) OVER (ORDER BY week_number) as success_change
FROM amazon_orders
GROUP BY week_number
ORDER BY week_number;
```

---

### 15. RFM-Style City Segmentation
```sql
WITH city_metrics AS (
    SELECT 
        ship_city,
        COUNT(*) as frequency,
        MAX(order_date) as recency,
        SUM(amount) as monetary
    FROM amazon_orders
    WHERE success_flag = 1
    GROUP BY ship_city
),
city_scores AS (
    SELECT 
        ship_city,
        frequency,
        CURRENT_DATE - recency as days_since_last_order,
        monetary,
        NTILE(5) OVER (ORDER BY frequency DESC) as f_score,
        NTILE(5) OVER (ORDER BY recency DESC) as r_score,
        NTILE(5) OVER (ORDER BY monetary DESC) as m_score
    FROM city_metrics
)
SELECT 
    ship_city,
    frequency as total_orders,
    days_since_last_order,
    monetary as total_revenue,
    f_score + r_score + m_score as rfm_score,
    CASE 
        WHEN (f_score + r_score + m_score) >= 12 THEN 'Champions'
        WHEN (f_score + r_score + m_score) >= 9 THEN 'Loyal'
        WHEN (f_score + r_score + m_score) >= 6 THEN 'Potential'
        ELSE 'At Risk'
    END as segment
FROM city_scores
ORDER BY rfm_score DESC
LIMIT 50;
```

---

## VIEWS FOR DASHBOARD

### 16. Create Summary View for Power BI
```sql
CREATE OR REPLACE VIEW vw_order_summary AS
SELECT 
    order_id,
    order_date,
    TO_CHAR(order_date, 'YYYY-MM') as year_month,
    EXTRACT(YEAR FROM order_date) as year,
    EXTRACT(MONTH FROM order_date) as month_num,
    month_name,
    week_number,
    status,
    fulfilment,
    service_level,
    category,
    product_group,
    courier_status,
    quantity,
    amount,
    ship_city,
    ship_state,
    city_tier,
    is_b2b,
    delivered,
    cancelled,
    returned,
    success_flag,
    revenue_loss,
    CASE 
        WHEN courier_status = 'On the Way' AND 
             (CURRENT_DATE - order_date) > 5 
        THEN TRUE 
        ELSE FALSE 
    END as is_at_risk
FROM amazon_orders;
```

---

### 17. Create State Performance View
```sql
CREATE OR REPLACE VIEW vw_state_performance AS
SELECT 
    ship_state,
    service_level,
    COUNT(*) as orders,
    SUM(amount) as revenue,
    ROUND(AVG(success_flag) * 100, 2) as success_rate,
    ROUND(AVG(CASE WHEN cancelled = TRUE THEN 1 ELSE 0 END) * 100, 2) as cancel_rate,
    RANK() OVER (
        PARTITION BY service_level 
        ORDER BY AVG(success_flag) DESC
    ) as performance_rank
FROM amazon_orders
GROUP BY ship_state, service_level;
```

---

## DATA VALIDATION

### 18. Quality Checks
```sql
-- Check for duplicates
SELECT order_id, COUNT(*) 
FROM amazon_orders 
GROUP BY order_id 
HAVING COUNT(*) > 1;

-- Check for nulls in critical fields
SELECT 
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) as null_order_ids,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) as null_dates,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) as null_amounts
FROM amazon_orders;

-- Validate date range
SELECT 
    MIN(order_date) as earliest,
    MAX(order_date) as latest,
    MAX(order_date) - MIN(order_date) as days_span
FROM amazon_orders;

-- Check revenue consistency
SELECT 
    SUM(amount) as total_revenue,
    SUM(CASE WHEN success_flag = 1 THEN amount ELSE 0 END) as successful_revenue,
    SUM(revenue_loss) as cancelled_revenue,
    SUM(amount) - SUM(CASE WHEN success_flag = 1 THEN amount ELSE 0 END) - SUM(revenue_loss) as discrepancy
FROM amazon_orders;
```

---

**All queries tested and validated on PostgreSQL 14+**  
**Created by:** Rishi Raghuvanshi  
**Last Updated:** January 2025
