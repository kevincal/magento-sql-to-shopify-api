# magento-sql-to-shopify-api

Python Scripts to pull data directly from Magento SQL and push into Shopify API

Currently supporting CE 1.9x

# Requirements

- VirtualEnv
- PIP
- Python 2.7.6

Note: Yaml is required for ShopifyAPI and it seems that pyYaml requires Python-dev so make sure that it's installed
ie., # apt-get install libpython-dev


# Installation

After GIT cloning into `magento-sql-to-shopify-api` on your server:

	$ cd magento-sql-to-shopify-api
	$ virtualenv --no-site-packages magento-sql-to-shopify-api
	$ source magento-sql-to-shopify-api/bin/activate
	(magento-sql-to-shopify-api) $ pip install -r requirements.txt

Next create a settings file with the proper config:

	(magento-sql-to-shopify-api) $ cp settings.py.dist settings.py
	(magento-sql-to-shopify-api) $ vi settings.py

# Command Line

	$ run.sh --help


