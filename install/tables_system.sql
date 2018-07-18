/*
Staging Tables for the Magento SQL to Shopify API
 */

-- Create syntax for TABLE 'shopify_log'
DROP TABLE IF EXISTS `shopify_log`;
CREATE TABLE `shopify_log` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `object` varchar(255) DEFAULT NULL,
  `key` varchar(255) DEFAULT NULL,
  `message` varchar(255) DEFAULT NULL,
  `data` TEXT DEFAULT NULL,
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `object_key` (`object`, `key`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;