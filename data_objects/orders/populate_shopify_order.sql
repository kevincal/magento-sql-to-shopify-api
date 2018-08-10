/*
	Shopify Order SQL Primer

	Populates shopify_order staging tables in a couple passes.
	- Create the Base Order Record
	- Create the Order Addresses
	- Create the Line Items
	- Create the Invoice Items
	- Create the Tax Line
	- Creates the Transactions
	- Creates the Fulfillment
	- Creates any Refunds (if available)

	Note: Using double semi-colons as delimiter as this file is parsed by a Python Script

*/

-- Reset Tables
TRUNCATE TABLE shopify_order;;
TRUNCATE TABLE shopify_order_address;
TRUNCATE TABLE shopify_order_line_item;;
TRUNCATE TABLE shopify_order_transaction;;
TRUNCATE TABLE shopify_order_tax_line;;
TRUNCATE TABLE shopify_order_discount;;
TRUNCATE TABLE shopify_order_fulfillment;;
TRUNCATE TABLE shopify_order_shipping_line;

/** ====================== BASE ORDER RECORD ====================== **/
/**
Notes about Order Record:
1. `name` field is the magento increment id (order #)
**/
INSERT INTO shopify_order
(
  `magento_id`,
  `email`,
  `name`,
  `phone`,
  `subtotal_price`,
  `total_line_items_price`,
  `total_discounts`,
  `total_price`,
  `total_tax`,
  `total_weight`,
  `customer_locale`,
  `currency`,
  `source_name`,
  `processed_at`,
  `cancel_reason`,
  `cancelled_at`,
  `tags`
)
SELECT DISTINCT
  o.entity_id,
  o.customer_email,
  o.increment_id AS `name`,
  sca.phone,
  o.subtotal AS `subtotal_price`,
  o.subtotal AS `total_line_items_price`,
  -1 * o.discount_amount AS `total_discounts`,
  o.grand_total AS `total_price`,
  o.tax_amount AS `total_tax`,
  ROUND(o.weight * 453.592) AS `total_weight`, -- lbs -> grams
  'en-US' AS `customer_locale`,
  'USD' AS `currency`,
  'api' AS `source_name`,
  o.updated_at - INTERVAL 5 HOUR AS `processed_at`,
  CASE
    WHEN o.status IN ('canceled', 'closed') THEN 'customer'
    ELSE ''
  END AS `cancel_reason`,
  CASE
    WHEN o.status IN ('canceled', 'closed') THEN o.updated_at - INTERVAL 5 HOUR
    ELSE NULL
  END AS `cancelled_at`,
  'magento' AS `tags`
FROM
  sales_flat_order o
  INNER JOIN shopify_customer sc ON sc.email = o.customer_email
  INNER JOIN shopify_customer_address sca ON sca.email = sc.email AND sca.is_default = 1;;

/** ====================== TARGET SHIP DATE / DESIRED DELIVERY ====================== **/
UPDATE
  shopify_order o
  INNER JOIN sales_mlc_order mlc ON mlc.order_id = o.magento_id
SET
  o.target_ship_date = mlc.target_ship_date,
  o.desired_delivery_date = mlc.desired_delivery_date;;


/** ====================== ORDER GIFT MESSAGE / NOTE ====================== **/

UPDATE
  shopify_order so
  INNER JOIN sales_flat_order o ON o.increment_id = so.name
  INNER JOIN gift_message AS g ON g.gift_message_id = o.gift_message_id
SET
  so.note = g.message;;

/** ====================== ORDER COMMENTS ====================== **/

-- Create A Temp Table
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_order_comments
(
order_id int(11) NOT NULL,
comments TEXT,
PRIMARY KEY (order_id)
) ENGINE=MyISAM;;

INSERT INTO tmp_order_comments
(order_id, comments)
SELECT
    parent_id,
    GROUP_CONCAT(`comment` SEPARATOR '\r\n') AS comments
FROM sales_flat_order_status_history
WHERE entity_name = 'order' AND `comment` IS NOT NULL
GROUP BY parent_id;;

UPDATE
  shopify_order so
  INNER JOIN tmp_order_comments AS c ON so.magento_id = c.order_id
SET
  so.comments = c.comments;;

-- Drop the Temp Table
DROP TABLE IF EXISTS tmp_order_comments;;

/** ====================== ORDER BILLING ADDRESS ====================== **/

INSERT INTO shopify_order_address
(
  `name`,
  `magento_id`,
  `first_name`,
  `last_name`,
  `company`,
  `address1`,
  `address2`,
  `city`,
  `province`,
  `country_code`,
  `zip`,
  `phone`,
  `is_billing`
)
SELECT DISTINCT
  o.increment_id AS `name`,
  sca.magento_id,
  sca.first_name,
  sca.last_name,
  sca.company,
  sca.address1,
  sca.address2,
  sca.city,
  sca.province,
  sca.country_code,
  sca.zip,
  sca.phone,
  1 AS `is_billing`
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN shopify_customer_address sca ON sca.magento_id = o.billing_address_id;;


INSERT INTO shopify_order_address
(
  `name`,
  `magento_id`,
  `first_name`,
  `last_name`,
  `company`,
  `address1`,
  `address2`,
  `city`,
  `province`,
  `country_code`,
  `zip`,
  `phone`,
  `is_shipping`
)
SELECT DISTINCT
  o.increment_id AS `name`,
  sca.magento_id,
  sca.first_name,
  sca.last_name,
  sca.company,
  sca.address1,
  sca.address2,
  sca.city,
  sca.province,
  sca.country_code,
  sca.zip,
  sca.phone,
  1 AS `is_shipping`
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN shopify_customer_address sca ON sca.magento_id = o.shipping_address_id;;


/** ====================== ORDER LINE ITEM ====================== **/

INSERT INTO shopify_order_line_item
(
  `name`,
  `sku`,
  `title`,
  `fulfillment_service`,
  `fulfillment_status`,
  `quantity`,
  `price`,
  `grams`,
  `total_tax`,
  `total_discount`,
  `requires_shipping`,
  `taxable`
)
SELECT
  o.increment_id AS `name`,
  p.sku AS `sku`,
  IFNULL(pname.value, oi.name) AS `title`,
  'manual' AS `fulfillment_service`,
  NULL AS `fulfillment_status`,
  oi.qty_ordered AS `quantity`,
  oi.price AS `price`,
  ROUND(oi.weight * 453.592, 0) AS `grams`,
  oi.tax_amount AS `total_tax`,
  oi.discount_amount AS `total_discount`,
  1 AS `requires_shipping`,
  1 AS `taxable`
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN sales_flat_order_item oi ON oi.order_id = o.entity_id
  INNER JOIN catalog_product_entity p ON oi.product_id = p.entity_id
  LEFT OUTER JOIN catalog_product_entity_varchar pname ON (oi.product_id = pname.entity_id AND pname.attribute_id = 71);;


/** ====================== ORDER TRANSACTIONS ====================== **/

-- Payments
INSERT INTO shopify_order_transaction
(
  `name`,
  `authorization`,
  `gateway`,
  `amount`,
  `kind`,
  `status`
)
SELECT
  o.increment_id AS `name`,
  p.last_trans_id AS `authorization`,
  CASE
    WHEN method LIKE 'auth%' THEN 'authorize_net'
    WHEN method LIKE 'paypal%' THEN 'paypal'
    ELSE ''
  END AS `gateway`,
  amount_paid AS `amount`,
  'sale' AS `kind`,
  'success' AS `status`
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN sales_flat_order_payment p ON p.parent_id = o.entity_id
WHERE
  p.amount_paid >= 0;;

-- Refunds
INSERT INTO shopify_order_transaction
(
  `name`,
  `authorization`,
  `gateway`,
  `amount`,
  `kind`,
  `status`
)
SELECT
  o.increment_id AS `name`,
  p.last_trans_id AS `authorization`,
  CASE
    WHEN method LIKE 'auth%' THEN 'authorize_net'
    WHEN method LIKE 'paypal%' THEN 'paypal'
    ELSE ''
  END AS `gateway`,
  p.amount_refunded AS `amount`,
  'refund' AS `kind`,
  'success' AS `status`
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN sales_flat_order_payment p ON p.parent_id = o.entity_id
WHERE
  p.amount_refunded > 0;;

/** ====================== GIFT CARD TRANSACTIONS ====================== **/

INSERT INTO shopify_order_transaction
(
  `name`,
  `authorization`,
  `gateway`,
  `amount`,
  `kind`,
  `status`,
  `gift_card_id`
)
SELECT
  o.increment_id AS `name`,
  '' AS `authorization`,
  'gift_card' AS `gateway`,
  gh.amount AS `amount`,
  'sale' AS `kind`,
  'success' AS `status`,
  gc.shopify_id
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN giftvoucher_history gh ON gh.order_increment_id = so.name
  INNER JOIN shopify_gift_card gc ON gc.magento_id = gh.giftvoucher_id
WHERE
  gh.amount > 0 AND
  gc.shopify_id IS NOT NULL;;


/** ====================== UPDATE ORDER PROCESSING METHOD ====================== **/
/*
"processing_method": "direct" => if online use "checkout" but if offline, use "manual"
*/

UPDATE
  shopify_order o
  LEFT OUTER JOIN shopify_order_transaction t ON t.name = o.name
SET
  o.processing_method = 'checkout'
WHERE
  t.gateway != '';;

UPDATE
  shopify_order o
  LEFT OUTER JOIN shopify_order_transaction t ON t.name = o.name
SET o.processing_method = 'manual'
WHERE
  t.gateway = '';;


/** ====================== UPDATE ORDER INVOICE STATUS ====================== **/
/*
Note: Orders can have multiple invoices so we want the most recently
The status of payments associated with the order. Valid values:
    const STATE_OPEN       = 1;
    const STATE_PAID       = 2;
    const STATE_CANCELED   = 3;
*/

UPDATE
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN sales_flat_invoice i ON i.order_id = o.entity_id
SET
  so.financial_status = 'paid'
WHERE
  i.state = 2;;

UPDATE
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN sales_flat_invoice i ON i.order_id = o.entity_id
SET
  so.financial_status = 'pending'
WHERE
  i.state = 1;;

UPDATE
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN sales_flat_invoice i ON i.order_id = o.entity_id
SET
  so.financial_status = 'voided'
WHERE
  i.state NOT IN (1,2);;

-- Create A Temp Table
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_order_refund_totals
(
  `name` varchar(25) DEFAULT '',
  `total_refund` decimal(10,2) DEFAULT 0.00,
  PRIMARY KEY (`name`)
) ENGINE=MyISAM;;

-- Populate Temp Table
INSERT INTO tmp_order_refund_totals (
  `name`, `total_refund`
)
SELECT `name`, SUM(`amount`) AS total
FROM shopify_order_transaction
WHERE kind = 'refund'
GROUP BY `name`;;

-- Update Total Refunded
UPDATE
  shopify_order o
  INNER JOIN tmp_order_refund_totals AS t ON t.name = o.name
SET
  o.financial_status = 'refunded'
WHERE
  t.total_refund = o.total_price;;

-- Update Partial Refunded
UPDATE
  shopify_order o
  INNER JOIN tmp_order_refund_totals AS t ON t.name = o.name
SET
  o.financial_status = 'partially_refunded'
WHERE
  t.total_refund < o.total_price;;

-- Drop Table
DROP TABLE tmp_order_refund_totals;;

/** ====================== DELETE $0.00 Sale Transacftions ====================== **/
DELETE FROM shopify_order_transaction
wHERE kind = 'sale' AND status = 'success' AND amount = 0;;


/** ====================== ORDER TAX LINE ====================== **/

INSERT INTO shopify_order_tax_line
(
  `name`,
  `rate`,
  `price`,
  `title`
)
SELECT
  o.increment_id AS `name`,
  t.percent / 100 AS `rate`,
  t.amount AS `price`,
  CASE
    WHEN t.title = 'US-TX-*-Rate 1' THEN 'TX State Tax'
    WHEN t.title = 'US-CA-*-Rate 1' THEN 'CA State Tax'
    WHEN t.title = 'US-NY-*-Rate 1' THEN 'NY State Tax'
    ELSE t.title
  END AS `title`
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN sales_order_tax t ON t.order_id = o.entity_id;;


/** ====================== ORDER DISCOUNTS ====================== **/

INSERT INTO shopify_order_discount
(
  `name`,
  `code`,
  `type`,
  `amount`
)
SELECT
  o.increment_id AS `name`,
  o.coupon_code,
  'fixed_amount' AS `type`,
  -1 * o.discount_amount
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
WHERE
  o.discount_amount != 0;

/** ====================== ORDER FULFILLMENT ====================== **/

INSERT INTO shopify_order_fulfillment
(
  `name`,
  `status`,
  `tracking_company`,
  `tracking_number`
)
SELECT DISTINCT
  o.increment_id AS `name`,
  'success' AS `status`,
  CASE
    WHEN tr.title LIKE '%fedex%' THEN 'FedEx'
    WHEN tr.carrier_code = 'ups' THEN 'UPS'
    WHEN tr.carrier_code = 'usps' THEN 'USPS'
    ELSE ''
  END AS `tracking_company`,
  tr.track_number AS `tracking_number`
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id
  INNER JOIN sales_flat_shipment sh ON sh.order_id = o.entity_id
  LEFT OUTER JOIN sales_flat_shipment_track tr ON tr.parent_id = sh.entity_id;;

-- If missing
UPDATE shopify_order_fulfillment
SET tracking_company = 'FedEx'
WHERE
    tracking_company = '' AND
    CONCAT('',tracking_number * 1) = tracking_number;;

UPDATE shopify_order_fulfillment
SET tracking_company = 'Maggie Louise Confections'
WHERE tracking_company = '';;

/** ====================== ORDER LINE ITEM FULFILLMENT ====================== **/
UPDATE
  shopify_order_line_item li
  INNER JOIN shopify_order_fulfillment f ON f.name = li.name
SET
  li.fulfillment_status = 'fulfilled';;

UPDATE
  shopify_order o
  INNER JOIN shopify_order_fulfillment f ON f.name = o.name
SET
  o.fulfillment_status = 'fulfilled';;


/** ====================== ORDER SHIPPING LINE ====================== **/
INSERT INTO shopify_order_shipping_line
(
  `name`,
  `code`,
  `price`,
  `source`,
  `title`
)
SELECT DISTINCT
  o.increment_id AS `name`,
  o.shipping_method AS `code`,
  o.shipping_amount AS `price`,
  CASE
    WHEN o.shipping_description LIKE '%local%' THEN 'MLC'
    WHEN o.shipping_method LIKE '%flatrate%' THEN 'FedEx'
    ELSE 'Other'
  END AS `source`,
  CASE
    WHEN o.shipping_description LIKE '%free%' THEN 'Free Shipping'
    WHEN o.shipping_description LIKE '%787%' THEN 'Local Delivery'
    WHEN o.shipping_description LIKE '%local%' THEN 'Local Delivery'
    WHEN o.shipping_description LIKE '%Austin%' THEN 'In-Store Pickup'
    WHEN o.shipping_description LIKE '%in-store%' THEN 'In-Store Pickup'
    WHEN o.shipping_description = '' THEN 'Standard Shipping'
    ELSE o.shipping_description
  END AS `title`
FROM
  sales_flat_order o
  INNER JOIN shopify_order so ON so.name = o.increment_id;;

/** ====================== CLOSE / ARCHIVE OLD ORDERS ====================== **/
UPDATE
  shopify_order so
  INNER JOIN sales_flat_invoice i ON (i.order_id = so.magento_id AND i.state = 2)
  INNER JOIN sales_flat_shipment s ON (s.order_id = so.magento_id)
SET
  closed_at = GREATEST(s.updated_at, i.updated_at);;

/** ====================== SPECIAL TAGS ====================== **/
UPDATE shopify_order o SET
  tags = CONCAT(tags, ',', 'cancelled')
WHERE
  o.cancelled_at IS NOT NULL;;

UPDATE
    shopify_order o
    INNER JOIN shopify_order_transaction t ON t.name = o.name
SET
  tags = CONCAT(tags, ',', 'refund')
WHERE
  t.kind = 'refund';;




