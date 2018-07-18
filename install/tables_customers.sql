/*
Staging Tables for the Magento SQL to Shopify API
- Customer Export / Import
*/

-- Create syntax for TABLE 'shopify_customer'
DROP TABLE IF EXISTS `shopify_customer`;
CREATE TABLE `shopify_customer` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `shopify_id` bigint(20) DEFAULT NULL,
  `magento_id` int(20) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `first_name` varchar(255) DEFAULT NULL,
  `last_name` varchar(255) DEFAULT NULL,
  `accepts_marketing` smallint(1) DEFAULT '1',
  `tags` varchar(255) DEFAULT '',
  `note` text,
  `tax_exempt` smallint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_customer_address'
DROP TABLE IF EXISTS `shopify_customer_address`;
CREATE TABLE `shopify_customer_address` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `magento_id` int(20) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
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
  `is_default` smallint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- Create syntax for TABLE 'shopify_customer_fix'
DROP TABLE IF EXISTS `shopify_customer_fix`;
CREATE TABLE `shopify_customer_fix` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(255) DEFAULT NULL,
  `duplicate_email` varchar(255) DEFAULT NULL,
  `phone` varchar(255) DEFAULT NULL,
  `final_email` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

-- Create syntax for TABLE 'shopify_customer_metafield'
DROP TABLE IF EXISTS `shopify_customer_metafield`;
CREATE TABLE `shopify_customer_metafield` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(255) DEFAULT NULL,
  `key` varchar(50) DEFAULT NULL,
  `namespace` varchar(50) DEFAULT NULL,
  `value` varchar(255) DEFAULT NULL,
  `value_type` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;