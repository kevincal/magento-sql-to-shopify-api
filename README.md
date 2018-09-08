# magento-sql-to-shopify-api

Python Scripts to pull data directly from Magento SQL and push into Shopify API

Currently supporting CE 1.9x

# READ FIRST

We had custom tables in use for our Magento Instance.  We use these tables in the Priming SQL scripts.  You should fork this app and customize your own PRIMING SQL.
ie., grep for 'sales_mlc_order' or 'personalize'

We also did not use complicated objects so did not have to worry about variants or relationships between products. We also had a small number of SKUs (<1000)

USE AT YOUR OWN RISK. I MADE THIS PUBLIC AS A GUIDE FOR OTHERS. IT IS NOT A MAGIC BULLET.

## WORKFLOW IN A NUTSHELL
First I compartmentalize the basic objects I want to import and ensure they're in the correct order of import: Products, Customers, Gift Cards, Orders
 
For each object type, we PRIME a set of staging tables that enable us to run transforms on the data to ensure they fit the shopify model.
 
After priming the tables, we PUSH the data from the staging tables into the Shopify API.
 
## IMPORTANT
YOU CANNOT USE THIS OUT OF THE BOX. I created some intermediary tables and had some logic in my magento app that you may want to remove. ie., I kept track of target ship date in a sales_mlc_order table.   This code is meant to be a guide only.


    /** TARGET SHIP DATE / DESIRED DELIVERY = **/
    UPDATE
        shopify_order o
        INNER JOIN sales_mlc_order mlc ON mlc.order_id = o.magento_id
    SET
        o.target_ship_date = mlc.target_ship_date,
        o.desired_delivery_date = mlc.desired_delivery_date;;
 

## NUANCES

* If using GIFT CARDS, you'll need that API activated by your Launch Manager
* My recommendation is to setup several staging instances and test. ie. abc-qa-1.myshopify.com, abc-qa-2.myshopify.com, abc-qa-3.myshopify.com
* LocationID is required and there is no easy way to get it from the Shopify Admin site.  Inside a python shell you can query it easily enough.

```
# endppoint
endpoint = "/locations.json"

# build api params
shopify_api_url = "https://%s:%s@%s/admin" % (config["shopify"]["key"],
                                                      config["shopify"]["password"],
                                                      config["shopify"]["url"])

# build headers
headers = {'content-type': 'application/json'}

# build API url
api_url = shopify_api_url + endpoint

r = requests.get(api_url, headers=headers)
print r.json()
```

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

Note: Several Indexes were added to some of the flat tables to speed up PRIMING queries.
ie., order_id on sales_flat_shipment and sales_flat_order


# Basic Workflow

1. Setup Store
1. Create New Private App
1. Give App Read & Write Permissions including Storefront API
1. Copy a settings.*.py file using the domain for * and update the API url, key and password for new store
1. Open your API Explorer and get the location id for the new store

# Command Line

	$ run.sh --help


