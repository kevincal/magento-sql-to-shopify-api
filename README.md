# magento-sql-to-shopify-api

Python Scripts to pull data directly from Magento SQL and push into Shopify API

Currently supporting CE 1.9x

# Requirements

- VirtualEnv
- PIP
- Python 2.7.x (see https://stackoverflow.com/questions/5506110/is-it-possible-to-install-another-version-of-python-to-virtualenv)
- Shopify API Key and Password for your Private App

Note: Yaml is required for ShopifyAPI and it seems that pyYaml requires Python-dev so make sure that it's installed
ie., # apt-get install libpython-dev

# Installation

After GIT cloning into `magento-sql-to-shopify-api` on your server:

	$ cd magento-sql-to-shopify-api
	$ virtualenv magento-sql-to-shopify-api
	$ source magento-sql-to-shopify-api/bin/activate
	(magento-sql-to-shopify-api) $ pip install -r requirements.txt

Note: If you don't have 2.7.x natively installed, you should install it in your .localpython drive and then
create the virtual env using

    $ virtualenv magento-sql-to-shopify-api --python=/home/${USER}/.localpython/bin/python2.7

Next create a settings file with the proper config:

	(magento-sql-to-shopify-api) $ cp settings.py.dist settings.py
	(magento-sql-to-shopify-api) $ vi settings.py

# Database Setup

- Create the staging tables as outlined in [install/staging_tables.sql](install/staging_tables.sql)
- Create the required SQL functions found in [install/functions.sql](install/functions.sql)


# Basic Workflow

TBD

# Command Line

	$ run.sh --help


