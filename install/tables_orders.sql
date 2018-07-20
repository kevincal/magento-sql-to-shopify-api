/*
Staging Tables for the Magento SQL to Shopify API
- Order Export / Import
*/

-- Create syntax for TABLE 'shopify_order'
DROP TABLE IF EXISTS `shopify_order`;
CREATE TABLE `shopify_order` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `shopify_id` bigint(20) DEFAULT NULL,
  `magento_id` int(20) DEFAULT NULL,
  `email` varchar(255) DEFAULT '',
  `name` varchar(255) DEFAULT '',
  `phone` varchar(255) DEFAULT '',
  `subtotal_price` decimal(10,2) DEFAULT 0,
  `total_discounts` decimal(10,2) DEFAULT 0,
  `total_line_items_price` decimal(10,2) DEFAULT 0,
  `total_price` decimal(10,2) DEFAULT 0,
  `total_tax` decimal(10,2) DEFAULT 0,
  `total_weight` int(10) DEFAULT 0,
  `customer_locale` varchar(10) DEFAULT 'en-US',
  `cancel_reason` varchar(255) DEFAULT NULL,
  `cancelled_at` DATETIME DEFAULT NULL,
  `closed_at` DATETIME DEFAULT NULL,
  `currency` varchar(3) DEFAULT 'USD',
  `financial_status` varchar(50) DEFAULT NULL,
  `processed_at` DATETIME DEFAULT NULL,
  `processing_method` varchar(50) DEFAULT '',
  `taxes_included` smallint(1) DEFAULT 0,
  `fulfillment_status` varchar(50) DEFAULT NULL,
  `source_name` VARCHAR(10) DEFAULT 'api',
  `tags` varchar(255) DEFAULT '',
  `note` TEXT,
  `comments` TEXT,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_order_address'
DROP TABLE IF EXISTS `shopify_order_address`;
CREATE TABLE `shopify_order_address` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `magento_id` int(10) DEFAULT NULL,
  `first_name` varchar(255) DEFAULT NULL,
  `last_name` varchar(255) DEFAULT NULL,
  `company` varchar(255) DEFAULT NULL,
  `address1` varchar(255) DEFAULT NULL,
  `address2` varchar(255) DEFAULT NULL,
  `city` varchar(255) DEFAULT NULL,
  `province` varchar(50) DEFAULT NULL,
  `country_code` varchar(2) DEFAULT NULL,
  `zip` varchar(255) DEFAULT NULL,
  `phone` varchar(255) DEFAULT NULL,
  `phone_ext` varchar(10) DEFAULT '',
  `phone_idx` int(11) DEFAULT '0',
  `is_shipping` smallint(1) DEFAULT 0,
  `is_billing` smallint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_order_discount'
DROP TABLE IF EXISTS `shopify_order_discount`;
CREATE TABLE `shopify_order_discount` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `code` varchar(255) DEFAULT NULL,
  `type` varchar(50) DEFAULT NULL,
  `amount` DECIMAL(10,2) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_order_fulfillment'
DROP TABLE IF EXISTS `shopify_order_fulfillment`;
CREATE TABLE `shopify_order_fulfillment` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  `tracking_company` varchar(50) DEFAULT NULL,
  `tracking_number` varchar(50) DEFAULT NULL,
  `location_id` varchar(50) DEFAULT NULL,
  `created_at` DATETIME DEFAULT NULL,
  `updated_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_order_line_item'
DROP TABLE IF EXISTS `shopify_order_line_item`;
CREATE TABLE `shopify_order_line_item` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `sku` varchar(255) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `fulfillment_service` varchar(50) DEFAULT 'manual',
  `fulfillment_status` varchar(50) DEFAULT NULL,
  `quantity` int(10) DEFAULT NULL,
  `price` decimal(10,2) DEFAULT 0,
  `grams` int(10) DEFAULT NULL,
  `total_tax` decimal(10,2) DEFAULT 0,
  `total_discount` decimal(10,2) DEFAULT 0,
  `requires_shipping` smallint(1) DEFAULT 1,
  `taxable` smallint(1) DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_order_metafield'
DROP TABLE IF EXISTS `shopify_order_metafield`;
CREATE TABLE `shopify_order_metafield` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `key` varchar(50) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `namespace` varchar(50) DEFAULT NULL,
  `value` TEXT DEFAULT NULL,
  `value_type` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_order_shipping_line'
DROP TABLE IF EXISTS `shopify_order_shipping_line`;
CREATE TABLE `shopify_order_shipping_line` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `code` varchar(100) DEFAULT NULL,
  `price` DECIMAL(10,2) DEFAULT 0,
  `source` varchar(50) DEFAULT '',
  `title` varchar(100) DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_order_tax_line'
DROP TABLE IF EXISTS `shopify_order_tax_line`;
CREATE TABLE `shopify_order_tax_line` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `rate` DECIMAL(6,4) DEFAULT 0,
  `price` DECIMAL(10,2) DEFAULT 0,
  `title` varchar(50) DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_order_transaction'
DROP TABLE IF EXISTS `shopify_order_transaction`;
CREATE TABLE `shopify_order_transaction` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) DEFAULT NULL,
  `authorization` varchar(255) DEFAULT NULL,
  `gateway` varchar(50) DEFAULT 'authorize_net',
  `kind` varchar(50) DEFAULT 'sale',
  `status` varchar(50) DEFAULT 'success',
  `amount` DECIMAL(10,2) DEFAULT 0,
  `gift_card_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
