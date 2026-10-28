-- =====================================================================
--  SURPLUS FOOD RESCUE NETWORK  |  ORACLE  |  SIMPLE VERSION
--  01_SCHEMA.SQL  (11 TABLES, 1 SEQUENCE, 1 TRIGGER, 1 PROCEDURE, 2 VIEWS)
--
--  SCOPE: SINGLE CITY, VERIFIED DONORS AND NGOS, COOKED + PACKAGED FOOD.
--  OUT OF SCOPE: LEGAL LIABILITY, PAYMENTS, ROUTE PLANNING, LIVE TRACKING.
--
--  HOW TO RUN: OPEN IN SQL DEVELOPER AND PRESS F5 (RUN SCRIPT).
--  TO RE-RUN FROM SCRATCH: UNCOMMENT THE DROP LINES BELOW AND RUN THEM FIRST.
-- =====================================================================

-- DROP TABLE BATCH_STATUS_HISTORY CASCADE CONSTRAINTS;
-- DROP TABLE FEEDBACK             CASCADE CONSTRAINTS;
-- DROP TABLE DELIVERIES           CASCADE CONSTRAINTS;
-- DROP TABLE PICKUPS              CASCADE CONSTRAINTS;
-- DROP TABLE CLAIMS               CASCADE CONSTRAINTS;
-- DROP TABLE FOOD_BATCHES         CASCADE CONSTRAINTS;
-- DROP TABLE VOLUNTEERS           CASCADE CONSTRAINTS;
-- DROP TABLE NGOS                 CASCADE CONSTRAINTS;
-- DROP TABLE DONORS               CASCADE CONSTRAINTS;
-- DROP TABLE FOOD_CATEGORIES      CASCADE CONSTRAINTS;
-- DROP TABLE ZONES                CASCADE CONSTRAINTS;
-- DROP SEQUENCE SEQ_HISTORY;

-- =====================================================================
--  1. ZONES  (AREAS OF THE CITY; DONORS, NGOS AND VOLUNTEERS BELONG TO ONE)
-- =====================================================================
CREATE TABLE ZONES (
    ZONE_ID    NUMBER(5)     PRIMARY KEY,
    ZONE_NAME  VARCHAR2(50)  NOT NULL UNIQUE,
    PINCODE    CHAR(6)       NOT NULL
);

-- =====================================================================
--  2. FOOD_CATEGORIES
-- =====================================================================
CREATE TABLE FOOD_CATEGORIES (
    CATEGORY_ID    NUMBER(5)     PRIMARY KEY,
    CATEGORY_NAME  VARCHAR2(60)  NOT NULL UNIQUE,
    FOOD_TYPE      VARCHAR2(10)  NOT NULL
                   CHECK (FOOD_TYPE IN ('COOKED', 'PACKAGED'))
);

-- =====================================================================
--  3. DONORS  (RESTAURANTS, BANQUETS, CATERERS, HOSTELS, CANTEENS)
-- =====================================================================
CREATE TABLE DONORS (
    DONOR_ID             NUMBER(5)      PRIMARY KEY,
    ORG_NAME             VARCHAR2(100)  NOT NULL,
    DONOR_TYPE           VARCHAR2(20)   NOT NULL
                         CHECK (DONOR_TYPE IN ('RESTAURANT', 'BANQUET', 'CATERER', 'HOSTEL', 'CANTEEN')),
    CONTACT_NAME         VARCHAR2(60)   NOT NULL,
    PHONE                VARCHAR2(15)   NOT NULL,
    EMAIL                VARCHAR2(100)  NOT NULL UNIQUE,
    ADDRESS              VARCHAR2(200)  NOT NULL,
    ZONE_ID              NUMBER(5)      NOT NULL REFERENCES ZONES (ZONE_ID),
    VERIFICATION_STATUS  VARCHAR2(12)   DEFAULT 'UNVERIFIED' NOT NULL
                         CHECK (VERIFICATION_STATUS IN ('UNVERIFIED', 'VERIFIED', 'FLAGGED')),
    CREATED_AT           DATE           DEFAULT SYSDATE NOT NULL
);

-- =====================================================================
--  4. NGOS  (SHELTERS, ORPHANAGES, OLD-AGE HOMES, COMMUNITY KITCHENS)
-- =====================================================================
CREATE TABLE NGOS (
    NGO_ID                NUMBER(5)      PRIMARY KEY,
    ORG_NAME              VARCHAR2(100)  NOT NULL,
    REGISTRATION_NO       VARCHAR2(30)   NOT NULL UNIQUE,
    CONTACT_NAME          VARCHAR2(60)   NOT NULL,
    PHONE                 VARCHAR2(15)   NOT NULL,
    EMAIL                 VARCHAR2(100)  NOT NULL UNIQUE,
    ADDRESS               VARCHAR2(200)  NOT NULL,
    ZONE_ID               NUMBER(5)      NOT NULL REFERENCES ZONES (ZONE_ID),
    ACCEPTS_VEG_ONLY      NUMBER(1)      DEFAULT 0 NOT NULL
                          CHECK (ACCEPTS_VEG_ONLY IN (0, 1)),
    DAILY_CAPACITY_MEALS  NUMBER(6)      NOT NULL
                          CHECK (DAILY_CAPACITY_MEALS > 0),
    VERIFICATION_STATUS   VARCHAR2(12)   DEFAULT 'UNVERIFIED' NOT NULL
                          CHECK (VERIFICATION_STATUS IN ('UNVERIFIED', 'VERIFIED', 'FLAGGED'))
);

-- =====================================================================
--  5. VOLUNTEERS  (PEOPLE WHO VERIFY, PICK UP AND DELIVER FOOD)
-- =====================================================================
CREATE TABLE VOLUNTEERS (
    VOLUNTEER_ID  NUMBER(5)      PRIMARY KEY,
    FULL_NAME     VARCHAR2(60)   NOT NULL,
    PHONE         VARCHAR2(15)   NOT NULL,
    EMAIL         VARCHAR2(100)  NOT NULL UNIQUE,
    ZONE_ID       NUMBER(5)      NOT NULL REFERENCES ZONES (ZONE_ID),
    VEHICLE_TYPE  VARCHAR2(10)   NOT NULL
                  CHECK (VEHICLE_TYPE IN ('BIKE', 'CAR', 'VAN')),
    IS_AVAILABLE  NUMBER(1)      DEFAULT 1 NOT NULL
                  CHECK (IS_AVAILABLE IN (0, 1))
);

-- =====================================================================
--  6. FOOD_BATCHES  (THE SURPLUS FOOD A DONOR POSTS)
--  STATUS FLOW:  AVAILABLE -> RESERVED -> IN_TRANSIT -> DELIVERED
--                AVAILABLE / RESERVED -> EXPIRED
--                IN_TRANSIT -> REJECTED  (FOOD FOUND UNSAFE ON ARRIVAL)
--                AVAILABLE -> CANCELLED  (DONOR WITHDRAWS)
-- =====================================================================
CREATE TABLE FOOD_BATCHES (
    BATCH_ID               NUMBER(8)      PRIMARY KEY,
    DONOR_ID               NUMBER(5)      NOT NULL REFERENCES DONORS (DONOR_ID),
    CATEGORY_ID            NUMBER(5)      NOT NULL REFERENCES FOOD_CATEGORIES (CATEGORY_ID),
    TITLE                  VARCHAR2(120)  NOT NULL,
    IS_VEG                 NUMBER(1)      NOT NULL
                           CHECK (IS_VEG IN (0, 1)),
    QUANTITY_MEALS         NUMBER(6)      NOT NULL
                           CHECK (QUANTITY_MEALS > 0),
    PREPARED_AT            DATE           NOT NULL,
    EXPIRY_TIME            DATE           NOT NULL,
    STATUS                 VARCHAR2(12)   DEFAULT 'AVAILABLE' NOT NULL
                           CHECK (STATUS IN ('AVAILABLE', 'RESERVED', 'IN_TRANSIT', 'DELIVERED',
                                             'EXPIRED', 'REJECTED', 'CANCELLED')),
    VERIFICATION_STATUS    VARCHAR2(12)   DEFAULT 'UNVERIFIED' NOT NULL
                           CHECK (VERIFICATION_STATUS IN ('UNVERIFIED', 'VERIFIED', 'FLAGGED')),
    VERIFIED_BY_VOLUNTEER  NUMBER(5)      REFERENCES VOLUNTEERS (VOLUNTEER_ID),
    CREATED_AT             DATE           DEFAULT SYSDATE NOT NULL,
    CHECK (EXPIRY_TIME > PREPARED_AT)
);

-- =====================================================================
--  7. CLAIMS  (AN NGO RESERVES A BATCH)
--  DOUBLE-CLAIM PREVENTION: BATCH_ID IS UNIQUE, SO A BATCH CAN HAVE ONLY
--  ONE CLAIM. IF TWO NGOS TRY AT THE SAME TIME, THE SECOND INSERT FAILS
--  WITH ORA-00001 (UNIQUE CONSTRAINT VIOLATED).
--  IF AN NGO BACKS OUT, DELETE ITS CLAIM AND SET THE BATCH BACK TO AVAILABLE.
-- =====================================================================
CREATE TABLE CLAIMS (
    CLAIM_ID      NUMBER(8)     PRIMARY KEY,
    BATCH_ID      NUMBER(8)     NOT NULL UNIQUE REFERENCES FOOD_BATCHES (BATCH_ID),
    NGO_ID        NUMBER(5)     NOT NULL REFERENCES NGOS (NGO_ID),
    CLAIMED_AT    DATE          DEFAULT SYSDATE NOT NULL,
    CLAIM_STATUS  VARCHAR2(12)  DEFAULT 'CLAIMED' NOT NULL
                  CHECK (CLAIM_STATUS IN ('CLAIMED', 'PICKED_UP', 'DELIVERED', 'REJECTED', 'NO_SHOW'))
);

-- =====================================================================
--  8. PICKUPS  (A VOLUNTEER COLLECTS THE CLAIMED FOOD)
-- =====================================================================
CREATE TABLE PICKUPS (
    PICKUP_ID                NUMBER(8)     PRIMARY KEY,
    CLAIM_ID                 NUMBER(8)     NOT NULL UNIQUE REFERENCES CLAIMS (CLAIM_ID),
    VOLUNTEER_ID             NUMBER(5)     NOT NULL REFERENCES VOLUNTEERS (VOLUNTEER_ID),
    ASSIGNED_AT              DATE          DEFAULT SYSDATE NOT NULL,
    PICKED_UP_AT             DATE,
    VERIFIED_QUANTITY_MEALS  NUMBER(6),
    PICKUP_STATUS            VARCHAR2(12)  DEFAULT 'ASSIGNED' NOT NULL
                             CHECK (PICKUP_STATUS IN ('ASSIGNED', 'PICKED_UP', 'FAILED'))
);

-- =====================================================================
--  9. DELIVERIES  (FOOD HANDED OVER TO THE NGO)
-- =====================================================================
CREATE TABLE DELIVERIES (
    DELIVERY_ID       NUMBER(8)     PRIMARY KEY,
    PICKUP_ID         NUMBER(8)     NOT NULL UNIQUE REFERENCES PICKUPS (PICKUP_ID),
    DELIVERED_AT      DATE          NOT NULL,
    MEALS_RECEIVED    NUMBER(6)     NOT NULL
                      CHECK (MEALS_RECEIVED >= 0),
    DELIVERY_STATUS   VARCHAR2(12)  NOT NULL
                      CHECK (DELIVERY_STATUS IN ('DELIVERED', 'PARTIAL', 'REJECTED')),
    REJECTION_REASON  VARCHAR2(200),
    CHECK (DELIVERY_STATUS <> 'REJECTED' OR REJECTION_REASON IS NOT NULL)
);

-- =====================================================================
--  10. FEEDBACK  (OPTIONAL IN THE PILOT PHASE; SUPPORTS FUTURE
--      REPUTATION AND FOOD-SAFETY TRACKING)
-- =====================================================================
CREATE TABLE FEEDBACK (
    FEEDBACK_ID            NUMBER(8)     PRIMARY KEY,
    DELIVERY_ID            NUMBER(8)     NOT NULL UNIQUE REFERENCES DELIVERIES (DELIVERY_ID),
    QUALITY_RATING         NUMBER(1)
                           CHECK (QUALITY_RATING BETWEEN 1 AND 5),
    SAFETY_ISSUE_REPORTED  NUMBER(1)     DEFAULT 0 NOT NULL
                           CHECK (SAFETY_ISSUE_REPORTED IN (0, 1)),
    COMMENT_TEXT           VARCHAR2(200),
    CREATED_AT             DATE          DEFAULT SYSDATE NOT NULL
);

-- =====================================================================
--  11. BATCH_STATUS_HISTORY  (TRACE OF EVERY STATUS CHANGE; FILLED BY TRIGGER)
-- =====================================================================
CREATE SEQUENCE SEQ_HISTORY START WITH 1 INCREMENT BY 1;

CREATE TABLE BATCH_STATUS_HISTORY (
    HISTORY_ID  NUMBER(10)    PRIMARY KEY,
    BATCH_ID    NUMBER(8)     NOT NULL REFERENCES FOOD_BATCHES (BATCH_ID),
    OLD_STATUS  VARCHAR2(12),
    NEW_STATUS  VARCHAR2(12)  NOT NULL,
    CHANGED_AT  DATE          DEFAULT SYSDATE NOT NULL
);

-- =====================================================================
--  INDEX  (SPEEDS UP "FIND AVAILABLE BATCHES THAT EXPIRE SOON")
-- =====================================================================
CREATE INDEX IDX_BATCH_STATUS_EXPIRY ON FOOD_BATCHES (STATUS, EXPIRY_TIME);

-- =====================================================================
--  TRIGGER: WHENEVER A BATCH'S STATUS CHANGES, SAVE A ROW IN THE HISTORY
--  TABLE (OLD STATUS, NEW STATUS, TIME).
-- =====================================================================
CREATE OR REPLACE TRIGGER TRG_LOG_BATCH_STATUS
AFTER UPDATE OF STATUS ON FOOD_BATCHES
FOR EACH ROW
WHEN (OLD.STATUS <> NEW.STATUS)
BEGIN
    INSERT INTO BATCH_STATUS_HISTORY (HISTORY_ID, BATCH_ID, OLD_STATUS, NEW_STATUS, CHANGED_AT)
    VALUES (SEQ_HISTORY.NEXTVAL, :NEW.BATCH_ID, :OLD.STATUS, :NEW.STATUS, SYSDATE);
END;
/

-- =====================================================================
--  PROCEDURE: MARK FOOD AS EXPIRED WHEN ITS TIME IS OVER.
--  RUN IT BY HAND:  EXEC SP_EXPIRE_BATCHES;
--  (A REAL SYSTEM WOULD RUN IT AUTOMATICALLY EVERY FEW MINUTES.)
-- =====================================================================
CREATE OR REPLACE PROCEDURE SP_EXPIRE_BATCHES IS
BEGIN
    -- 1) AN NGO CLAIMED THE FOOD BUT NEVER COLLECTED IT BEFORE EXPIRY = NO SHOW
    UPDATE CLAIMS
       SET CLAIM_STATUS = 'NO_SHOW'
     WHERE CLAIM_STATUS = 'CLAIMED'
       AND BATCH_ID IN (SELECT BATCH_ID
                          FROM FOOD_BATCHES
                         WHERE STATUS = 'RESERVED'
                           AND EXPIRY_TIME < SYSDATE);

    -- 2) MARK THE BATCHES THEMSELVES AS EXPIRED
    UPDATE FOOD_BATCHES
       SET STATUS = 'EXPIRED'
     WHERE STATUS IN ('AVAILABLE', 'RESERVED')
       AND EXPIRY_TIME < SYSDATE;

    COMMIT;
END;
/

-- =====================================================================
--  VIEW 1: AVAILABLE FOOD THAT WILL EXPIRE WITHIN THE NEXT 3 HOURS
-- =====================================================================
CREATE OR REPLACE VIEW V_EXPIRING_SOON_BATCHES AS
SELECT B.BATCH_ID,
       B.TITLE,
       D.ORG_NAME AS DONOR,
       Z.ZONE_NAME,
       B.QUANTITY_MEALS,
       B.EXPIRY_TIME,
       ROUND((B.EXPIRY_TIME - SYSDATE) * 24 * 60) AS MINUTES_LEFT
FROM   FOOD_BATCHES B
       JOIN DONORS D ON D.DONOR_ID = B.DONOR_ID
       JOIN ZONES  Z ON Z.ZONE_ID  = D.ZONE_ID
WHERE  B.STATUS = 'AVAILABLE'
  AND  B.EXPIRY_TIME > SYSDATE
  AND  B.EXPIRY_TIME < SYSDATE + 3/24;

-- =====================================================================
--  VIEW 2: HOW RELIABLE EACH NGO IS (DELIVERED VS NO-SHOW)
-- =====================================================================
CREATE OR REPLACE VIEW V_NGO_PERFORMANCE AS
SELECT N.NGO_ID,
       N.ORG_NAME,
       COUNT(C.CLAIM_ID) AS TOTAL_CLAIMS,
       SUM(CASE WHEN C.CLAIM_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) AS DELIVERED,
       SUM(CASE WHEN C.CLAIM_STATUS = 'NO_SHOW'   THEN 1 ELSE 0 END) AS NO_SHOWS,
       ROUND(100 * SUM(CASE WHEN C.CLAIM_STATUS = 'NO_SHOW' THEN 1 ELSE 0 END)
                 / NULLIF(COUNT(C.CLAIM_ID), 0), 1) AS NO_SHOW_PERCENT
FROM   NGOS N
       LEFT JOIN CLAIMS C ON C.NGO_ID = N.NGO_ID
GROUP BY N.NGO_ID, N.ORG_NAME;
