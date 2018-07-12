/*
	Shopify Order CSV Generator

	Populates shopify_order in a couple passes.
	1. Create the Base Order Record
	2. Creates the Transactions
	3. Creates the Fulfillments
	4. Creates any Refunds (if available)

	Note: Using double semi-colons as delimiter as this file is parsed by a Python Script

*/

-- Reset Tables
TRUNCATE TABLE shopify_order;;

/** ====================== BASE ORDER RECORD ====================== **/
/**
Notes about Order Record:
1. We are normalizing email address by lowercasing and triming white space.
2. We attempt to fix any basic case formatting on first and last names
3. (TODO) We have created a manual 'fix' process in which possible duplictae customers
   can be fixed by remapping email addresses. ie., kevin@hotmal.com and kevin@hotmail.com
   have the same phone number, we want to map orders from kevin@hotmal.com to the correct
   kevin@hotmail.com customer record.

**/