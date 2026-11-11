# bakery-waste-analytics
Bakery waste analysis in SQL and Tableau. Found 30% of production goes unsold, costing 78% of profit.

**Tools:** SQL (SQLite, DB Browser) · Tableau Public
**Data:** 19,321 sales records from a three-store bakery, Jan 2023 – Dec 2024 (synthetic dataset)(Currency is Rupees ₹)

**[VIEW THE DASHBOARD](https://public.tableau.com/views/BakerySalesVisualization_17943568651460/Dashboard1?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

<img width="1974" height="1404" alt="image" src="https://github.com/user-attachments/assets/409aee5b-a020-449d-af92-f8672ddbf44d" />


--
## The question

A three-store bakery throws away unsold product every day. Baked goods spoil within days, so making too much wastes money, but making too little leaves empty shelves and lost sales.

**Goal:** find which products, stores and days waste the most money, and recommend where production should change.

## Key Findings
| Total sales | ₹2,690,806 |
| Profit on items sold | ₹1,143,738 |
| Cost of unsold product | ₹894,344 |
| **Profit after waste** | **₹249,394** |
| Share of production that went unsold | 30.5% |

## The data

- **Source:** [Bakery Sales, Customer & Inventory Analytics Dataset](https://www.kaggle.com/datasets/sdcloud/historical-bakery-sales-dataset) on Kaggle
- **Size:** 19,321 rows × 40 columns · 3 stores · 35 products · 2 years
- **Currency:** Indian rupees (₹)

## Process

```
1. Profile     →  2. Verify      →  3. Find problems  →  4. Clean        →  5. Analyze
   counts,          recompute         logic checks,        two new tables     8 business
   blanks,          price, total,     outliers, repeated   + data-quality     questions
   duplicates       profit, dates     inventory values     flags
```

## Key Findings and Recommendations

**The bakery's biggest money problem is its overproduction.** Over two years, the three stores produced 61,952 units and 30.5% of them (18,925 units) went unsold. The cost of making that unsold product was **₹894,344**, about 78% of the bakery's total profit of **₹1,143,738** for the same period.

### Key Findings

1. **Cake is almost half of all the waste.** Cakes are 46.8% of waste cost, and 42% of cakes go unsold.
2. **All three stores share the same issue.** That means it's not a specific store's fault, but instead falls on production planning.
3. **Using promotions and discounts costs more than they bring in.** Promoted goods have a 36.7% profit margin compared with 45.4% at full price, and customers buy only around 13% more goods per product line.

### Recommendations

1. **Move cakes to made-to-order** and keep fewer ready-to-go cakes on display. Cutting cake waste in half would save around **₹209,000** over two years.
2. **Use discounts to clear stock instead of using them to drive sales.** Discounts on perishable items can help recover some of the money lost on wasted products.
3. **Improve how data is logged.** 549 store-day-product records had conflicting production numbers. After making changes, the bakery needs accurate data to see whether the changes actually work.
