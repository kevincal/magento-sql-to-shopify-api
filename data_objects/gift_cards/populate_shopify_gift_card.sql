/*
	Shopify Gift Card Primer

	Populates shopify_gift_card in a couple passes.
	1. Create the Base Record
	2.

  IMPORTANT. This must be run AFTER shopify_customer is populated and BEFORE shopify_orders.

	Note: Using double semi-colons as delimiter as this file is parsed by a Python Script

*/

-- Reset Tables
TRUNCATE TABLE shopify_gift_card;;


/** ====================== BASE PRODUCT RECORD ====================== **/
/**
Notes about Gift Card Record:

**/

-- Normalize Customer Email
UPDATE giftvoucher SET customer_email = LOWER(TRIM(customer_email));;

-- Create Base Product Record
INSERT INTO shopify_gift_card
(
 `magento_id`,
 `code`,
 `initial_value`,
 `balance`,
 `currency`,
 `expires_on`,
 `user_id`,
 `disabled_at`,
 `note`
)
SELECT DISTINCT
  gv.giftvoucher_id AS `magento_id`,
  gv.gift_code AS `code`,
  gh.amount AS `initial_value`,
  gv.balance AS `balance`,
  gv.currency AS `currency`,
 DATE_FORMAT(expired_at, '%Y-%m-%d') AS `expires_on`,
 sc.shopify_id AS `user_id`,
 CASE
  WHEN gv.status IN (6,3) THEN CURDATE()
  ELSE NULL
  END  AS `disabled_at`,
  gv.giftvoucher_comments AS `note`
FROM
  giftvoucher gv
  INNER JOIN giftvoucher_history gh ON (gh.giftvoucher_id = gv.giftvoucher_id AND gh.action = 1)
  LEFT OUTER JOIN shopify_customer sc ON sc.email = gv.customer_email;;
