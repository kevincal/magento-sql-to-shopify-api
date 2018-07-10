"""
Data Object Classes
~~~~~~~~~~~~~~~~~~~
Global Classes that make adding addition Export-Import scripts easy.
"""

# standard library imports
from datetime import datetime
import json
import os
import requests

# related third party imports
import pymysql.cursors

# local application/library specific imports
from settings import config


# main
class BaseDataObject(object):
    """
    BaseDataObject
    ~~~~~~~~~~~~~~
    This base class handles all the fundamentals
    """

    # properties
    config = None
    db_executable_sql = "some.sql"
    file_path = None
    verbose = 0

    def __init__(self, *args, **kwargs):

        # override properties
        for key, value in kwargs.items():
            setattr(self, key, value)

        # load config
        self.config = config

    def api_send(self, endpoint, payload, method="post"):
        """
        Send Data to Shopify API Endpoint
        :param endpoint: ie., "/customers.json"
        :param payload: the dict of the data/object to send to API
        :param method: "post" is only supported
        :return: reqest
        """

        # build api params
        shopify_api_url = "https://%s:%s@%s/admin" % (config["shopify"]["key"],
                                                      config["shopify"]["password"],
                                                      config["shopify"]["url"])

        # build headers
        headers = {'content-type': 'application/json'}

        # build API url
        api_url = shopify_api_url + endpoint
        self.log("Sending Data via '%s' to %s" % (method, api_url))

        if method == "post":
            r = requests.post(api_url, data=json.dumps(payload), headers=headers)

        # return the JSON Response Content
        self.log(r.json())
        return r.json()

    def close_db_connection(self):
        """Closes the database connection"""

        # close db connection
        self.db_connection.close()

    def get_db_connection(self):
        """Get the database connection.  If not exists, it instantiates it."""

        # return the connection
        if hasattr(self, 'db_connection') and self.db_connection.open:
            return self.db_connection

        self.db_connection = pymysql.connect(
            host=self.config["magento-mysql"]["host"],
            user=self.config["magento-mysql"]["user"],
            password=self.config["magento-mysql"]["password"],
            db=self.config["magento-mysql"]["db"],
            port=self.config["magento-mysql"]["port"],
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor)

        return self.db_connection

    def log(self, msg):

        # output
        if self.verbose == 1:
            if isinstance(msg, dict):
                msg = json.dumps(msg)
            print datetime.now().strftime('%Y-%m-%d %H:%M:%S'), '|', msg

    def prime(self, *args, **kwargs):
        """Primes the Staging Tables"""

        # debug
        self.log("Priming Data...")

        # load sql
        with open(os.path.join(self.file_path, self.db_executable_sql), 'r') as f:
            sql_statements = f.read()

        # run sql
        db_connection = self.get_db_connection()

        try:
            sql_list = sql_statements.split(";;")
            for sql in sql_list:
                if sql.strip() != "":
                    with db_connection.cursor() as cursor:
                        self.log(sql)
                        cursor.execute(sql, None)
                db_connection.commit()
        finally:
            self.close_db_connection()

    def push(self, *args, **kwargs):
        """Pushes data from the Staging Tables to Shopify API"""
        pass

