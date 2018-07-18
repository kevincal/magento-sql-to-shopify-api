/*
Staging Tables for the Magento SQL to Shopify API
- Gift Card Export / Import
*/

-- Create syntax for TABLE 'shopify_gift_card'
DROP TABLE IF EXISTS `shopify_gift_card`;
CREATE TABLE `shopify_gift_card` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `shopify_id` bigint(20) DEFAULT NULL,
  `magento_id` int(20) DEFAULT NULL,
  `code` varchar(255) DEFAULT NULL,
  `initial_value` decimal(10,2) DEFAULT NULL,
  `balance` decimal(10,2) DEFAULT NULL,
  `currency` varchar(3) DEFAULT 'USD',
  `expires_on` DATE DEFAULT NULL,
  `user_id` bigint(20) DEFAULT NULL,
  `disabled_at` DATETIME DEFAULT NULL,
  `note` text,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

