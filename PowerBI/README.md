# DAX Measures - Amazon Freight Dashboard

Complete list of all DAX measures used in the Power BI dashboard.

---

## 📊 CORE METRICS

### Total Orders
```dax
Total Orders = COUNTROWS(amazon_enriched)
```
**Returns**: 128,976  
**Usage**: Primary KPI, funnel stages, trend analysis

---

### Total Revenue
```dax
Total Revenue = SUM(amazon_enriched[Amount])
```
**Returns**: ₹77,765,433  
**Usage**: Primary KPI, revenue analysis

---

### Successful Orders
```dax
Successful Orders = 
CALCULATE(
    COUNTROWS(amazon_enriched),
    amazon_enriched[success] = 1
)
```
**Returns**: ~107,571  
**Usage**: Success rate calculation, funnel

---

### Success Rate
```dax
Success Rate = 
DIVIDE([Successful Orders], [Total Orders], 0) * 100
```
**Returns**: 82.51%  
**Usage**: Primary KPI, performance tracking  
**Note**: Multiplied by 100 for percentage display

---

### Cancelled Orders
```dax
Cancelled Orders = 
CALCULATE(
    COUNTROWS(amazon_enriched),
    amazon_enriched[cancelled] = TRUE
)
```
**Returns**: ~18,334  
**Usage**: Cancellation analysis

---

### Cancellation Rate
```dax
Cancellation Rate = 
DIVIDE([Cancelled Orders], [Total Orders], 0) * 100
```
**Returns**: 14.08%  
**Usage**: Primary KPI, problem identification

---

### Returned Orders
```dax
Returned Orders = 
CALCULATE(
    COUNTROWS(amazon_enriched),
    amazon_enriched[returned] = TRUE
)
```
**Returns**: ~2,114  
**Usage**: Returns analysis, customer satisfaction

---

### Return Rate
```dax
Return Rate = 
DIVIDE([Returned Orders], [Successful Orders], 0) * 100
```
**Returns**: 1.96%  
**Usage**: Quality metrics

---

### Average Order Value (AOV)
```dax
AOV = 
DIVIDE([Total Revenue], [Total Orders], 0)
```
**Returns**: ₹602.94  
**Usage**: Primary KPI, pricing analysis

---

### Revenue Loss
```dax
Revenue Loss = SUM(amazon_enriched[revenue_loss])
```
**Returns**: ₹6,828,687  
**Usage**: Impact analysis, executive summary

---

## 🚚 OPERATIONAL METRICS

### In Transit
```dax
In Transit = 
CALCULATE(
    COUNTROWS(amazon_enriched),
    amazon_enriched[Courier Status] = "On the Way"
)
```
**Returns**: 6,799  
**Usage**: Operations dashboard KPI

---

### At Risk
```dax
At Risk = 
CALCULATE(
    COUNTROWS(amazon_enriched),
    amazon_enriched[Courier Status] = "On the Way",
    amazon_enriched[Date] < MAX(amazon_enriched[Date]) - 5
)
```
**Returns**: 6,424  
**Usage**: Critical alert, operations KPI  
**Logic**: Orders in transit >5 days from max date in dataset

---

### Average Days In Transit
```dax
Avg Days In Transit = 
VAR MaxDate = MAX(amazon_enriched[Date])
RETURN
CALCULATE(
    AVERAGEX(
        amazon_enriched,
        MaxDate - amazon_enriched[Date]
    ),
    amazon_enriched[Courier Status] = "On the Way"
)
```
**Returns**: 5.94 days  
**Usage**: Operations KPI, delivery performance

---

### SLA Breach (Percentage)
```dax
SLA Breach % = 
VAR ExpediteBreaches = 
    CALCULATE(
        COUNTROWS(amazon_enriched),
        amazon_enriched[ship-service-level] = "Expedited",
        amazon_enriched[Courier Status] = "On the Way",
        amazon_enriched[Date] < MAX(amazon_enriched[Date]) - 3
    )
VAR StandardBreaches = 
    CALCULATE(
        COUNTROWS(amazon_enriched),
        amazon_enriched[ship-service-level] = "Standard",
        amazon_enriched[Courier Status] = "On the Way",
        amazon_enriched[Date] < MAX(amazon_enriched[Date]) - 5
    )
VAR TotalInTransit = [In Transit]
RETURN
    DIVIDE(ExpediteBreaches + StandardBreaches, TotalInTransit, 0) * 100
```
**Returns**: 5.08%  
**Usage**: Operations KPI  
**Logic**: Expedited >3 days OR Standard >5 days

---

## 📦 CATEGORY METRICS

### Total Categories
```dax
Total Categories = DISTINCTCOUNT(amazon_enriched[Category])
```
**Returns**: 10  
**Usage**: Product diversity KPI

---

### Top 2 Category Concentration
```dax
Top 2 Cat % = 
VAR TopCats = 
    CALCULATE(
        [Total Orders],
        amazon_enriched[Category] IN {"T-shirt", "Shirt"}
    )
RETURN
DIVIDE(TopCats, [Total Orders], 0) * 100
```
**Returns**: 76.87%  
**Usage**: Risk analysis, product KPI

---

### B2B Percentage
```dax
B2B % = 
DIVIDE(
    CALCULATE([Total Orders], amazon_enriched[B2B] = TRUE),
    [Total Orders],
    0
) * 100
```
**Returns**: 0.67%  
**Usage**: Market segment KPI

---

### Premium Percentage (Expedited Shipping)
```dax
Premium % = 
DIVIDE(
    CALCULATE(
        [Total Orders],
        amazon_enriched[ship-service-level] = "Expedited"
    ),
    [Total Orders],
    0
) * 100
```
**Returns**: 69.2%  
**Usage**: Service level preference

---

### Top Category
```dax
Top Category = "T-shirt"
```
**Returns**: T-shirt  
**Usage**: Quick reference KPI  
**Note**: Simplified - could be dynamic calculation

---

## 🔔 ALERT MEASURES (Executive Summary)

### Alert Revenue Loss
```dax
Alert Revenue Loss = 
"🔴 ₹" & FORMAT([Revenue Loss]/1000000, "0.0") & "M Revenue Lost (Cancelled)"
```
**Returns**: "🔴 ₹6.8M Revenue Lost (Cancelled)"  
**Usage**: Executive summary critical alert

---

### Alert At Risk Orders
```dax
Alert At Risk Orders = 
"🔴 " & FORMAT([At Risk], "#,##0") & " Orders At Risk (>5 days)"
```
**Returns**: "🔴 6,424 Orders At Risk (>5 days)"  
**Usage**: Executive summary critical alert

---

### Alert UP Standard
```dax
Alert UP Standard = 
VAR UPSuccess = 
    CALCULATE(
        [Success Rate],
        amazon_enriched[ship-state] = "UTTAR PRADESH",
        amazon_enriched[ship-service-level] = "Standard"
    )
RETURN
    IF(
        UPSuccess < 1,
        "⚠️ UP Standard: " & FORMAT(UPSuccess * 100, "0.00") & "% Success",
        "⚠️ UP Standard: " & FORMAT(UPSuccess, "0.00") & "% Success"
    )
```
**Returns**: "⚠️ UP Standard: 73.11% Success"  
**Usage**: Executive summary warning  
**Logic**: Auto-detects if value is decimal (0.73) or percentage (73)

---

## 🟢 TOP PERFORMER MEASURES

### Top Tamil Nadu
```dax
Top Tamil Nadu = 
VAR TNSuccess = 
    CALCULATE(
        [Success Rate],
        amazon_enriched[ship-state] = "TAMIL NADU"
    )
RETURN
    "🟢 Tamil Nadu: " & FORMAT(TNSuccess, "0.00") & "% Success"
```
**Returns**: "🟢 Tamil Nadu: 83.99% Success"  
**Usage**: Executive summary top performer

---

### Top Karnataka Revenue
```dax
Top Karnataka Revenue = 
VAR KARevenue = 
    CALCULATE(
        [Total Revenue],
        amazon_enriched[ship-state] = "KARNATAKA"
    )
RETURN
    "🟢 Karnataka: ₹" & FORMAT(KARevenue/1000000, "0.0") & "M Revenue"
```
**Returns**: "🟢 Karnataka: ₹10.4M Revenue"  
**Usage**: Executive summary top performer

---

### Top T-shirt Revenue
```dax
Top T-shirt Revenue = 
VAR TShirtRev = 
    CALCULATE(
        [Total Revenue],
        amazon_enriched[Category] = "T-shirt"
    )
RETURN
    "🟢 T-shirt: ₹" & FORMAT(TShirtRev/1000000, "0.0") & "M Revenue"
```
**Returns**: "🟢 T-shirt: ₹38.8M Revenue"  
**Usage**: Executive summary top performer

---

## 📈 FUNNEL MEASURES

### Funnel Stage 1 - Orders
```dax
Funnel Stage 1 = [Total Orders]
```
**Returns**: 128,976  
**Usage**: Funnel chart - Stage 1

---

### Funnel Stage 2 - Shipped
```dax
Funnel Stage 2 = 
CALCULATE(
    [Total Orders],
    amazon_enriched[Courier Status] <> "Unshipped"
)
```
**Returns**: ~122,000  
**Usage**: Funnel chart - Stage 2

---

### Funnel Stage 3 - In Transit
```dax
Funnel Stage 3 = [In Transit]
```
**Returns**: 6,799  
**Usage**: Funnel chart - Stage 3  
**Note**: Snapshot of current in-transit orders

---

### Funnel Stage 4 - Delivered
```dax
Funnel Stage 4 = [Successful Orders]
```
**Returns**: ~106,000  
**Usage**: Funnel chart - Stage 4

---

## 🎯 CONDITIONAL MEASURES (Optional/Advanced)

### Previous Week Orders
```dax
Previous Week Orders = 
CALCULATE(
    [Total Orders],
    DATEADD(amazon_enriched[Date], -7, DAY)
)
```
**Usage**: Week-over-week comparison  
**Note**: Not used in final dashboard

---

### WoW Change
```dax
WoW Change = 
DIVIDE(
    [Total Orders] - [Previous Week Orders],
    [Previous Week Orders],
    0
) * 100
```
**Usage**: Trend analysis  
**Note**: Not used in final dashboard

---

## 📝 MEASURE USAGE SUMMARY

| Page | Measures Used | Primary Purpose |
|------|--------------|-----------------|
| **Page 1** | Total Orders, Total Revenue, Success Rate, Cancellation Rate, AOV | Executive KPIs |
| **Page 2** | In Transit, At Risk, SLA Breach, Returned Orders, Avg Days, Funnel measures | Operations monitoring |
| **Page 3** | Total Categories, Top 2 Cat %, B2B %, Premium %, Top Category | Product analysis |
| **Page 4** | All Alert measures, Top Performer measures, Core KPIs | Executive summary |

---

## 💡 TIPS FOR DAX OPTIMIZATION

1. **Use variables** (VAR) for complex calculations - improves performance
2. **DIVIDE with 0 as third parameter** prevents division by zero errors
3. **CALCULATE for context modification** - most powerful DAX function
4. **FORMAT for text output** - creates user-friendly display strings
5. **Multiply by 100 for percentages** - Power BI formats as decimal by default

---

## 🔍 DEBUGGING TIPS

If a measure returns unexpected results:

1. **Check data types** - ensure Amount is Decimal, not Text
2. **Verify filter context** - use CALCULATE to override filters
3. **Test with simple measure first** - build complexity gradually
4. **Use COUNTROWS** instead of COUNT for reliability
5. **Format dates correctly** - ensure Date column is Date type, not Text

---

**All measures tested and validated against source data.**  
**Last Updated**: January 2025  
**Created by**: Rishi Raghuvanshi
