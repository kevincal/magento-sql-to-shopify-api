/*
	Shopify Customer CSV Generator

	Populates shopify_customer in a couple passes.
	1. Create the Base Record
	2. Adds the Addresses
	3. Deduplicate Phone Numbers
	4. Create Metafield Value based on Customer Group
	5. (optional) Creates Tags for Customer

	Note: Using double semi-colons as delimiter as this file is parsed by a Python Script

*/

-- Reset Tables
-- TRUNCATE TABLE shopify_customer;;
TRUNCATE TABLE shopify_customer_address;;
TRUNCATE TABLE shopify_customer_metafield;;

-- Prep sales_flat_order by trimming and lower() email
UPDATE sales_flat_order SET customer_email = LOWER(TRIM(customer_email));;
UPDATE customer_entity SET email = LOWER(TRIM(email));;

/** ====================== BASE CUSTOMER RECORD ====================== **/
/**
Notes about Customer Record:
1. We are normalizing email address by lowercasing and triming white space.
2. We attempt to fix any basic case formatting on first and last names
3. (TODO) We have created a manual 'fix' process in which possible duplicate customers
   can be fixed by remapping email addresses. ie., kevin@hotmal.com and kevin@hotmail.com
   have the same phone number, we want to map orders from kevin@hotmal.com to the correct
   kevin@hotmail.com customer record.

**/

-- Create Base Customer Record
INSERT IGNORE INTO shopify_customer
(
	`email`,
  `accepts_marketing`,
	`tax_exempt`
)
SELECT SQL_CACHE DISTINCT
	so.customer_email AS email,
  1 AS accepts_marketing,
	CASE
		WHEN cg.customer_group_code LIKE '%Non-Profit%' THEN 1
		ELSE 0
	END AS tax_exempt
FROM
  sales_flat_order so
	LEFT OUTER JOIN sales_flat_order_address oa ON oa.entity_id = so.billing_address_id
	LEFT OUTER JOIN customer_group cg ON cg.customer_group_id = so.customer_group_id
	LEFT OUTER JOIN newsletter_subscriber ns ON ns.subscriber_email = so.customer_email
WHERE
  so.customer_email IS NOT NULL AND
  cg.customer_group_code != 'MLC: Inventorymlc';;

-- Update Magento ID
UPDATE
  shopify_customer sc
  INNER JOIN customer_entity c ON c.email = sc.email
SET
  sc.magento_id = c.entity_id;;

/** ====================== EMAIL OPT OUT ====================== **/
UPDATE
    shopify_customer c
    INNER JOIN mailchimp_unsubscribe u ON u.email = c.email
SET
    accepts_marketing = 0;;

UPDATE
    shopify_customer c
    INNER JOIN newsletter_subscriber s ON s.subscriber_email = c.email
SET
    accepts_marketing = 0
WHERE
  s.subscriber_status = 3;;

/** ====================== ADDRESS ====================== **/

-- Create A Temp Table
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_recent_order_address
(
address_id int(11) NOT NULL,
email varchar(255) NOT NULL,
PRIMARY KEY (address_id)
) ENGINE=MyISAM;;

INSERT INTO tmp_recent_order_address (email, address_id)
SELECT
  o.customer_email as email, max(oa.entity_id) as max_entity_id
FROM
  sales_flat_order o, sales_flat_order_address oa
WHERE
  o.billing_address_id = oa.entity_id AND
  oa.address_type = 'billing'
GROUP BY o.customer_email;;

-- Update First and Last Name from Most Recent Billing Address
UPDATE
	shopify_customer AS sc
	INNER JOIN tmp_recent_order_address AS recent ON recent.email = sc.email
	INNER JOIN sales_flat_order_address AS oa ON oa.entity_id = recent.address_id
SET
	sc.first_name = IFNULL(TRIM(oa.firstname), ''),
	sc.last_name= IFNULL(TRIM(oa.lastname), '');;

-- Format First Name to Aaaaa if no spaces
UPDATE shopify_customer SET
    first_name = CONCAT(UCASE(LEFT(first_name, 1)), SUBSTRING(LOWER(first_name), 2))
WHERE
  first_name NOT LIKE '%-%' AND
  first_name NOT LIKE '% %' AND
  LENGTH(first_name) > 3;;

-- Format Last Name to Aaaaa if no spaces
UPDATE shopify_customer SET
  last_name = CONCAT(UCASE(LEFT(last_name, 1)), SUBSTRING(LOWER(last_name), 2))
WHERE
  last_name NOT LIKE '% %' AND
  last_name NOT LIKE '%-%' AND
  last_name NOT LIKE 'Mc%' AND
  last_name NOT LIKE 'Mac%' AND
  last_name NOT LIKE 'O`%' AND
  last_name NOT LIKE 'O\'%' AND
  LENGTH(last_name) > 2;;

/** ====================== CUSTOMER ADDRESSES ====================== **/
/**
Note about Customer Address.
1. Shopify requires phone numbers to be unique to customer, so if a duplicate situation
   exists (ie., husband and wife sharing home number), one customer will keep the phone number
   while the other customer will have that number moved to their 'Notes' field.
2. Shopify requires phone numbers to follow E161 format so extensions are only supported
   in specific E.164 formats, ie., (NNN) NNN-NNNN;ext=NNN
**/

-- Create the Customer Address from Recent Address
INSERT INTO shopify_customer_address
(
  `email`,
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
  `is_default`
)
SELECT
  recent.email,
  oa.entity_id,
  IFNULL(TRIM(oa.firstname), '') as first_name,
  IFNULL(TRIM(oa.lastname), '') as last_name,
  IFNULL(oa.company, '') AS company,
  IFNULL(SUBSTRING_INDEX(oa.street, '\n', 1), '') AS adddress1,
  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(oa.street, '\n', 2), '\n', -1), '') AS address2,
  IFNULL(TRIM(oa.city), '') AS city,
  IFNULL(TRIM(oa.region), '') AS province,
  IFNULL(oa.country_id, '') AS country,
  IFNULL(TRIM(oa.postcode), '') AS zip,
  IFNULL(oa.telephone, '') AS phone,
  1 AS is_default
FROM
	shopify_customer AS sc
	INNER JOIN tmp_recent_order_address AS recent ON recent.email = sc.email
	INNER JOIN sales_flat_order_address AS oa ON oa.entity_id = recent.address_id;;

-- Create the Customer Address from Billing Address
INSERT INTO shopify_customer_address
(
  `email`,
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
  `phone`
)
SELECT
  sc.email,
  oa.entity_id,
  IFNULL(TRIM(oa.firstname), '') as first_name,
  IFNULL(TRIM(oa.lastname), '') as last_name,
  IFNULL(oa.company, '') AS company,
  IFNULL(SUBSTRING_INDEX(oa.street, '\n', 1), '') AS adddress1,
  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(oa.street, '\n', 2), '\n', -1), '') AS address2,
  IFNULL(TRIM(oa.city), '') AS city,
  IFNULL(oa.region, '') AS province,
  IFNULL(oa.country_id, '') AS country,
  IFNULL(TRIM(oa.postcode), '') AS zip,
  IFNULL(oa.telephone, '') AS phone
FROM
	shopify_customer AS sc
	INNER JOIN sales_flat_order o ON o.customer_email = sc.email
	INNER JOIN sales_flat_order_address AS oa ON oa.entity_id = o.billing_address_id;;

-- Create the Customer Address from Shipping Address
INSERT INTO shopify_customer_address
(
  `email`,
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
  `phone`
)
SELECT
  sc.email,
  oa.entity_id,
  IFNULL(TRIM(oa.firstname), '') as first_name,
  IFNULL(TRIM(oa.lastname), '') as last_name,
  IFNULL(oa.company, '') AS company,
  IFNULL(SUBSTRING_INDEX(oa.street, '\n', 1), '') AS adddress1,
  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(oa.street, '\n', 2), '\n', -1), '') AS address2,
  IFNULL(TRIM(oa.city), '') AS city,
  IFNULL(oa.region, '') AS province,
  IFNULL(oa.country_id, '') AS country,
  IFNULL(TRIM(oa.postcode), '') AS zip,
  IFNULL(oa.telephone, '') AS phone
FROM
	shopify_customer AS sc
	INNER JOIN sales_flat_order o ON o.customer_email = sc.email
	INNER JOIN sales_flat_order_address AS oa ON oa.entity_id = o.shipping_address_id;;


-- Create the Customer Address from the Customer Record
INSERT INTO shopify_customer_address
(
  `email`,
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
  `phone`
)
SELECT
  LOWER(TRIM(ce.email)) as email,
  NULL AS magento_id,
  TRIM(cev5.value) AS first_name,
  TRIM(cev7.value) AS last_name,
  IFNULL(caev24.value, '') AS company,
  IFNULL(SUBSTRING_INDEX(caet.value, '\n', 1), '') as street_address_1,
  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(caet.value, '\n', 2), '\n', -1), '') as street_address_2,
  TRIM(caev26.value) AS city,
  r.code as province,
  caev27.value as country,
  TRIM(caev30.value) AS zip,
  caev31.value as phone
FROM
  customer_entity ce

  -- join on shopify customer
  INNER JOIN shopify_customer c ON c.email = ce.email

  -- first name
  INNER JOIN customer_entity_varchar cev5 ON (ce.entity_id = cev5.entity_id AND cev5.attribute_id = 5)

  -- last name
  INNER JOIN customer_entity_varchar cev7 ON (ce.entity_id = cev7.entity_id AND cev7.attribute_id = 7)

  -- address
  INNER JOIN customer_address_entity cae ON (ce.entity_id = cae.parent_id)
  INNER JOIN customer_address_entity_text caet ON (cae.entity_id = caet.entity_id)

  -- city
  INNER JOIN customer_address_entity_varchar caev26 ON (cae.entity_id = caev26.entity_id AND caev26.attribute_id = 26)

  -- region / state
  INNER JOIN customer_address_entity_varchar caev28 ON (cae.entity_id = caev28.entity_id AND caev28.attribute_id = 28)
  INNER JOIN directory_country_region r ON r.default_name = caev28.value

  -- postcode
  INNER JOIN customer_address_entity_varchar caev30 ON (cae.entity_id = caev30.entity_id AND caev30.attribute_id = 30)

  -- country
  INNER JOIN customer_address_entity_varchar caev27 ON (cae.entity_id = caev27.entity_id AND caev27.attribute_id = 27)
  INNER JOIN sys_country country ON caev27.value = country.country_code

  -- phone
  INNER JOIN customer_address_entity_varchar caev31 ON (cae.entity_id = caev31.entity_id AND caev31.attribute_id = 31)

  -- company
  INNER JOIN customer_address_entity_varchar caev24 ON (cae.entity_id = caev24.entity_id AND caev24.attribute_id = 24);;

-- Delete Duplicate Address 2
UPDATE shopify_customer_address SET
	address2 = ''
WHERE
	address1 != '' AND
	address1 = address2;;

-- Format First Name to Aaaaa if no spaces
UPDATE shopify_customer_address SET
    first_name = CONCAT(UCASE(LEFT(first_name, 1)), SUBSTRING(LOWER(first_name), 2))
WHERE
  first_name NOT LIKE '%-%' AND
  first_name NOT LIKE '% %' AND
  LENGTH(first_name) > 3;;

-- Format Last Name to Aaaaa if no spaces
UPDATE shopify_customer_address SET
  last_name = CONCAT(UCASE(LEFT(last_name, 1)), SUBSTRING(LOWER(last_name), 2))
WHERE
  last_name NOT LIKE '% %' AND
  last_name NOT LIKE '%-%' AND
  last_name NOT LIKE 'Mc%' AND
  last_name NOT LIKE 'Mac%' AND
  last_name NOT LIKE 'O`%' AND
  last_name NOT LIKE 'O\'%' AND
  LENGTH(last_name) > 2;;

-- Drop the Temp Table
DROP TABLE IF EXISTS tmp_recent_order_address;;

-- Format First Name to Aaaaa if no spaces
UPDATE shopify_customer_address SET
    first_name = TRIM(CONCAT(UCASE(LEFT(first_name, 1)), SUBSTRING(LOWER(first_name), 2)))
WHERE
  first_name NOT LIKE '%-%' AND
  first_name NOT LIKE '% %' AND
  LENGTH(first_name) > 3;;

-- Format Last Name to Aaaaa if no spaces
UPDATE shopify_customer_address SET
    last_name = TRIM(CONCAT(UCASE(LEFT(last_name, 1)), SUBSTRING(LOWER(last_name), 2)))
WHERE
  last_name NOT LIKE '% %' AND
  last_name NOT LIKE '%-%' AND
  last_name NOT LIKE 'Mc%' AND
  last_name NOT LIKE 'Mac%' AND
  last_name NOT LIKE 'O`%' AND
  last_name NOT LIKE 'O\'%' AND
  LENGTH(last_name) > 2;;

-- Clear Double Quotes
UPDATE `shopify_customer_address` SET `Company` = REPLACE(`Company`, '"', "");;

/* Normalize Phone Numbers */

-- Split Exenstions
UPDATE shopify_customer_address SET phone = LOWER(phone);;
UPDATE shopify_customer_address SET phone = REPLACE(phone, 'ext:', ';') WHERE phone LIKE '%ext:%';;
UPDATE shopify_customer_address SET phone = REPLACE(phone, 'ext.', ';') WHERE phone LIKE '%ext.%';;
UPDATE shopify_customer_address SET phone = REPLACE(phone, 'ext', ';') WHERE phone LIKE '%ext%';;
UPDATE shopify_customer_address SET phone = REPLACE(phone, 'x', ';') WHERE phone LIKE '%x%';;

UPDATE shopify_customer_address SET
	phone_ext = TRIM(SUBSTRING_INDEX(phone, ';', -1)),
	phone = TRIM(SUBSTRING_INDEX(phone, ';', 1))
WHERE phone LIKE '%;%';;

-- Strip Non Digits from US Numbers
UPDATE shopify_customer_address SET
	phone = STRIP_NON_DIGIT(phone)
WHERE
	LENGTH(STRIP_NON_DIGIT(phone)) = 10;;

-- Remove Bad Phone Numbers
UPDATE shopify_customer_address SET
	phone = '', phone_ext = ''
WHERE
	phone IN (
    '8888862342', '5128400233', '5126739891', '5129660631', '8888888888',
    '5122003201', '888 888 888', '5555555555', '0000000000',
    '--',  'tbd', 'n/a', 'na', '1111111', '111111111', '2222222', '512-000-000'
  );;

UPDATE shopify_customer_address SET
	phone = '', phone_ext = ''
WHERE
	LENGTH(phone) = 5;;

-- Reformat Number
UPDATE shopify_customer_address SET
	phone = CONCAT(SUBSTR(phone,1,3),'-', SUBSTR(phone,4,3), '-', SUBSTR(phone,7))
WHERE
	LENGTH(phone) = 10;;

-- Recombine Phone
UPDATE shopify_customer_address SET
	phone = CONCAT(phone, ';ext=', phone_ext)
WHERE
	phone_ext != '';;

-- Reorder Table such that the next logical update an happen.
-- We are tagging the '1st' the phone number used and then
-- moving other uses of that phone number to the shopify
-- customer 'notes' field by other email addresses
-- 1. Drop Primary Key
-- 2. Reorder
-- 3, Run-Update
-- 4. Add Primary Key
ALTER TABLE `shopify_customer_address` DROP `id`;;

ALTER TABLE shopify_customer_address ORDER BY phone, email;;

-- Populate the PhoneCount index
UPDATE shopify_customer_address,
	(
SELECT DISTINCT
	  @phone as prv_phone,
	  @email as prv_email,
	  ca.phone,
	  ca.email,
	  @i := IF(ca.phone != @phone, 1,  IF(ca.email != @email, @i+1, @i)) AS idx,
	  @phone := ca.phone,
	  @email := ca.email
	FROM
	  shopify_customer_address ca
	  CROSS JOIN (SELECT @i := 0, @phone := '', @email := '') AS init
	WHERE
		ca.phone != ''
	) as i
SET shopify_customer_address.phone_idx = i.idx
WHERE
	shopify_customer_address.email = i.email AND
	shopify_customer_address.phone = i.phone;;

-- Preserve Uniqueness of Phone Number by moving the Duplicate Phone to the 'Note' field
-- (per Shopify Technical Support)
UPDATE
	shopify_customer c
	INNER JOIN shopify_customer_address ca ON c.email = ca.email
SET
	c.note = ca.phone,
	ca.phone = ''
WHERE
	ca.phone_idx > 1 AND
	ca.phone != '';;

-- Add Primary Key Back
ALTER TABLE `shopify_customer_address` ADD `id` INT UNSIGNED NOT NULL  AUTO_INCREMENT  PRIMARY KEY FIRST;;


/** ====================== META FIELDS ====================== **/
/**
Note aboute Customer Meta Field:
1. Below we are using Customer Group as the only meta field.
   If there are other groupings then modify appropriately with your own code.
**/
INSERT INTO shopify_customer_metafield
(
  `email`,
  `key`,
  `description`,
  `namespace`,
  `value`,
  `value_type`
)
SELECT DISTINCT
  so.customer_email as email,
  'Legacy Customer Group',
  'Customer Group we used to Classify Customers',
  'MLC',
  CASE
	WHEN cg.customer_group_code IS NULL THEN 'Direct: Consumer Online'
	WHEN cg.customer_group_code = 'NOT LOGGED IN' THEN 'Direct: Consumer Online'
	ELSE cg.customer_group_code
  END as consumer_group_code,
  'string'
 FROM
	sales_flat_order so
	INNER JOIN shopify_customer sc ON sc.email = so.customer_email
	LEFT OUTER JOIN sales_flat_order_address oa ON oa.entity_id = so.billing_address_id
    LEFT OUTER JOIN customer_entity c
    	LEFT OUTER JOIN customer_group cg ON c.group_id = cg.customer_group_id
    	ON c.entity_id = so.customer_id
ON DUPLICATE KEY UPDATE
  `value` = CONCAT(`value`, ', ',  CASE
	WHEN cg.customer_group_code IS NULL THEN 'Direct: Consumer Online'
	WHEN cg.customer_group_code = 'NOT LOGGED IN' THEN 'Direct: Consumer Online'
	ELSE cg.customer_group_code
  END);;

-- Save First Order Date
INSERT INTO shopify_customer_metafield
(
  `email`,
  `key`,
  `description`,
  `namespace`,
  `value`,
  `value_type`
)
SELECT DISTINCT
  sc.email,
  'Created Date',
  'Date Customer was Created',
  'MLC',
  DATE_FORMAT(MIN(so.created_at), '%Y-%m-%d'),
  'string'
FROM
  shopify_customer sc
	INNER JOIN sales_flat_order so ON sc.email = so.customer_email
GROUP BY
  sc.email;;




/** ====================== TAGS ====================== **/
/**
Note aboute Customer Tags:
1. We have our own internal segmentation and tagging struture so you will have to write your
   own code here to populate any values.
**/

UPDATE
	shopify_customer sc
	INNER JOIN bi_f_magento_customer mc ON mc.email = sc.email
SET
	sc.tags = mc.rfm_segment;;


