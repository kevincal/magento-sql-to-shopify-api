"""
Customers
~~~~~~~~~
Handling Customer Export

Priming Tables used:
- *_customer
_ *_customer_address
_ *_customer_note

"""

# standard library imports
from datetime import date, datetime
import os

# related third party imports
import pymysql.cursors

# local application/library specific imports
from settings import config


# local application/library specific imports
from data_objects.classes import BaseDataObject


# main
class DataObject(BaseDataObject):

    # parameters
    db_executable_sql = "populate_shopify_customer.sql"

    def __init__(self, *args, **kwargs):

        # get current file path
        file_path = os.path.realpath(
            os.path.join(os.getcwd(), os.path.dirname(__file__)))

        # call super init
        super(DataObject, self).__init__(file_path=file_path, *args, **kwargs)

    def push(self, *args, **kwargs):
        """Pushes data from the Staging Tables to Shopify API"""
        self.log("Build JSON and do API Stuff")
        pass