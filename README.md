# Surplus Food Rescue Network (DBMS Project)

This project is a relational Database Management System (DBMS) designed for the **Surplus Food Rescue Network**, aimed at bridging the gap between food donors (such as restaurants, banquets, and caterers) and NGOs/shelters to reduce food waste and tackle hunger.

---

## Database Schema & Architecture

The system is built on Oracle SQL and consists of **11 tables**, 1 sequence, 1 trigger, 1 stored procedure, and 2 views:

1. **`ZONES`**: Defines the areas of the city where donors, NGOs, and volunteers belong.


2. **`FOOD_CATEGORIES`**: Master list of food types categorized as either `COOKED` or `PACKAGED`.


3. **`DONORS`**: Profiles for organizations like restaurants, banquets, caterers, hostels, and canteens.


4. **`NGOS`**: Shelters, orphanages, old-age homes, and community kitchens receiving the surplus food.


5. **`VOLUNTEERS`**: People responsible for verifying, picking up, and delivering food.


6. **`FOOD_BATCHES`**: Tracks surplus food posted by donors, including its lifecycle status (`AVAILABLE` to `DELIVERED`, `EXPIRED`, etc.).


7. **`CLAIMS`**: Records NGOs reserving a food batch, featuring built-in double-claim prevention constraints.


8. **`PICKUPS`**: Tracks volunteer collection details for claimed food batches.


9. **`DELIVERIES`**: Final handover logs indicating successful deliveries, partial amounts, or rejections.


10. **`FEEDBACK`**: Optional feedback storing quality ratings and safety issues reported after a delivery.


11. **`BATCH_STATUS_HISTORY`**: An audit trail tracking every modification to a food batch's status.



---

## Advanced DBMS Features

* **Triggers (`TRG_LOG_BATCH_STATUS`)**: Automatically logs changes to any food batch's status into the history table.


* **Stored Procedures (`SP_EXPIRE_BATCHES`)**: Automatically updates unclaimed reserved food to `NO_SHOW` and un-claimed active batches to `EXPIRED` past their expiration time.


* **Views**:
* `V_EXPIRING_SOON_BATCHES`: Tracks available food expiring within the next 3 hours.


* `V_NGO_PERFORMANCE`: Computes NGO reliability metrics and no-show percentages.




* **Data Integrity**: Unique constraints (such as on `CLAIMS.BATCH_ID`) prevent race conditions like double-claiming the same batch.



---

## How to Run the Project

1. **Step 1: Set Up the Schema**
* Open your SQL development environment (such as Oracle SQL Developer) and run `01_SCHEMA.SQL` to create all required tables, constraints, sequences, triggers, procedures, and views.




2. **Step 2: Load Sample Data**
* Execute `02_SAMPLE_DATA.SQL` to populate the database with sample data modeled around Pune city, featuring realistic edge cases like expired batches, no-shows, and rejected deliveries.




3. **Step 3: Run and Test Queries**
* Use `03_QUERIES.SQL` to execute operational queries, analytics, accountability tracking, and live simulation steps.
