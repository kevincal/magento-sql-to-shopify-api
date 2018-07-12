/*
	Shopify Product CSV Generator

	Populates shopify_product in a couple passes.
	1. Create the Base Record
	2. Adds the Variant
	3. Adds the Images
	4. Adds the Metafields

	This script is using hard coded attribute ids.

	Note: Using double semi-colons as delimiter as this file is parsed by a Python Script

*/

-- Reset Tables
TRUNCATE TABLE shopify_product;;
TRUNCATE TABLE shopify_product_variant;;
TRUNCATE TABLE shopify_product_image;;
TRUNCATE TABLE shopify_product_metafield;;


/** ====================== BASE PRODUCT RECORD ====================== **/
/**
Notes about Product Record:
1. We use URL KEY as the Handle
2. Assuming Simple Store, 1 Store = store_id = 0
**/


-- Create Base Product Record
INSERT INTO shopify_product
(
  `magento_id`,
  `handle`,
  `title`,
  `body_html`,
  `metafields_global_title_tag`,
  `metafields_global_description_tag`,
  `vendor`,
  `product_type`,
  `published`,
  `published_at`,
  `published_scope`,
  `tax_exempt`,
  `tags`
)
SELECT DISTINCT
  p.entity_id AS magento_id,
  url_key.value AS `handle`,
  TRIM(title.value) AS `title`,
  description.value AS `body_html`,
  IFNULL(meta_title.value, '') AS `metafields_global_title_tag`,
  IFNULL(meta_description.value, '') AS `metafields_global_description_tag`,
  'Maggie Louise' AS `vendor`,
  CASE
  	WHEN p.attribute_set_id = 9 THEN 'Chocolate Gift Box'
  	ELSE 'Other'
  END AS `product_type`,
  CASE
    WHEN pstatus.value = 2 THEN 0 -- 2 == Disabled
    ELSE 1
  END AS `published`,
  p.created_at AS `published_at`,
  'web' AS `published_scope`,
  0 AS `tax_exempt`,
  TRIM(tags.value) AS tags
FROM
  catalog_product_entity p
  INNER JOIN catalog_product_entity_varchar AS url_key ON (p.entity_id = url_key.entity_id AND url_key.attribute_id = 97)
  INNER JOIN catalog_product_entity_varchar AS title ON (p.entity_id = title.entity_id AND title.attribute_id = 71)
  INNER JOIN catalog_product_entity_text AS description ON (p.entity_id = description.entity_id AND description.attribute_id = 72)
  LEFT OUTER JOIN catalog_product_entity_varchar AS meta_title ON (p.entity_id = meta_title.entity_id AND meta_title.attribute_id = 82)
  LEFT OUTER JOIN catalog_product_entity_varchar AS meta_description ON (p.entity_id = meta_description.entity_id AND meta_description.attribute_id = 84)
  INNER JOIN catalog_product_entity_int AS pstatus ON (p.entity_id = pstatus.entity_id AND pstatus.attribute_id = 96)
  LEFT OUTER JOIN catalog_product_entity_text AS tags ON (p.entity_id = meta_description.entity_id AND meta_description.attribute_id = 199);;


/** ====================== PRODUCT VARIANT ====================== **/
/**
Notes about Product Variant
1. Our catalog is simple products so this must be modidified for more complicated options
**/
INSERT INTO shopify_product_variant
(
  `handle`,
  `fulfillment_service`,
  `inventory_management`,
  `price`,
  `requires_shipping`,
  `sku`,
  `taxable`,
  `weight`,
  `weight_unit`
)
SELECT DISTINCT
  sp.handle,
  'manual' AS `fulfillment_service`,
  'shopify' AS `inventory_management`,
  price.value AS `price`,
  1 AS `requires_shipping`,
  TRIM(pe.sku) AS `sku`,
  CASE
    WHEN tax_class.value = 2 THEN 1 -- 2 = Taxable Goods
    ELSE 0
  END AS `taxable`,
  weight.value AS `weight`,
  'lb' AS `weight_unit`
FROM
  catalog_product_entity pe
  INNER JOIN shopify_product sp ON sp.magento_id = pe.entity_id
  INNER JOIN catalog_product_entity_decimal AS price ON (pe.entity_id = price.entity_id AND price.attribute_id = 75)
  LEFT OUTER JOIN catalog_product_entity_decimal AS weight ON (pe.entity_id = weight.entity_id AND weight.attribute_id = 80)
  LEFT OUTER JOIN catalog_product_entity_int AS tax_class ON (pe.entity_id = tax_class.entity_id AND tax_class.attribute_id = 122);;


/** ====================== PRODUCT IMAGE ====================== **/
/**
Notes about Product Image
1.
**/
INSERT INTO shopify_product_image
(
  `handle`,
  `position`,
  `src`
)
SELECT DISTINCT
  sp.handle,
  gv.position,
  CONCAT('https://mlc.imgix.net/media/catalog/product', g.value) AS src
FROM
  catalog_product_entity pe
  INNER JOIN shopify_product sp ON sp.magento_id = pe.entity_id
  INNER JOIN catalog_product_entity_media_gallery g ON g.entity_id = pe.entity_id
  INNER JOIN catalog_product_entity_media_gallery_value gv ON gv.value_id = g.value_id
WHERE
  	gv.disabled = 0
ORDER BY
	sp.handle, gv.position;;



/** ====================== META FIELDS ====================== **/
/**
Note aboute Products Meta Field:
1. These attributes are MLC attributes
2. We look for attributes in both catalog_product_entity_varchar and catalog_product_entity_text
**/
INSERT INTO shopify_product_metafield
(
  `handle`,
  `key`,
  `namespace`,
  `value`,
  `value_type`
)
SELECT DISTINCT
	sp.handle,
	CASE
		WHEN e.attribute_id = 193 THEN 'quote'
		WHEN e.attribute_id = 189 THEN 'ingredients'
		WHEN e.attribute_id = 201 THEN 'short-description'
		WHEN e.attribute_id = 188 THEN 'title'
		WHEN e.attribute_id = 190 THEN 'description'
	END AS metafield_key,
	CASE
		WHEN e.attribute_id IN (188, 190) THEN 'google-shopping-feed'
		ELSE 'details'
	END as metafield_namespace,
	REPLACE(e.value, '"', '\'') as metafield_value,
	'string' as metafield_value_type
FROM
  catalog_product_entity pe
  INNER JOIN shopify_product sp ON sp.magento_id = pe.entity_id
  INNER JOIN catalog_product_entity_varchar e ON e.entity_id = pe.entity_id AND e.entity_type_id = 4
WHERE
	e.attribute_id IN (193,188,189,190,201) AND
	e.value IS NOT NULL AND
	e.value != ''
ORDER BY
	sp.handle, e.attribute_id;;

INSERT INTO shopify_product_metafield
(
  `handle`,
  `key`,
  `namespace`,
  `value`,
  `value_type`
)
SELECT DISTINCT
	sp.handle,
	CASE
		WHEN e.attribute_id = 193 THEN 'quote'
		WHEN e.attribute_id = 189 THEN 'ingredients'
		WHEN e.attribute_id = 201 THEN 'short-description'
		WHEN e.attribute_id = 188 THEN 'title'
		WHEN e.attribute_id = 190 THEN 'description'
	END AS metafield_key,
	CASE
		WHEN e.attribute_id IN (188, 190) THEN 'google-shopping-feed'
		ELSE 'details'
	END as metafield_namespace,
	REPLACE(e.value, '"', '\'') as metafield_value,
	'string' as metafield_value_type
FROM
  catalog_product_entity pe
  INNER JOIN shopify_product sp ON sp.magento_id = pe.entity_id
  INNER JOIN catalog_product_entity_text e ON e.entity_id = pe.entity_id AND e.entity_type_id = 4
WHERE
	e.attribute_id IN (193,188,189,190,201) AND
	e.value IS NOT NULL AND
	e.value != ''
ORDER BY
	sp.handle, e.attribute_id;;


