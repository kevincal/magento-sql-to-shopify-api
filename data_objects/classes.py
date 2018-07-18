"""
Data Object Classes
~~~~~~~~~~~~~~~~~~~
Global Classes that make adding addition Export-Import scripts easy.
"""

# standard library imports
from datetime import date, datetime
import decimal
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

        # config
        config = self.config

        # default JSON Response Content
        response = {}

        # build api params
        shopify_api_url = "https://%s:%s@%s/admin" % (config["shopify"]["key"],
                                                      config["shopify"]["password"],
                                                      config["shopify"]["url"])

        # build headers
        headers = {'content-type': 'application/json'}

        # build API url
        api_url = shopify_api_url + endpoint
        self.log("Sending Data via '%s' to %s" % (method, api_url))

        # post
        data = None
        if payload:
            data = json.dumps(payload, default=self.json_serial)

        if method == "post":
            r = requests.post(api_url, data=data, headers=headers)
            response = r.json()

        # debug
        self.log(response)

        # process errors
        if response.get("errors"):

            # pull object details
            obj = payload.keys()[0]
            if obj == "customer":
                key = payload[obj].get("email")
            if obj == "gift_card":
                key = payload[obj].get("code")
            if obj == "order":
                key = payload[obj].get("name")
            if obj == "product":
                key = payload[obj].get("handle")

            self.log("API ERROR RETURNED")

            error_log = {
                "object": obj,
                "key": key,
                "message": json.dumps(response.get("errors")),
                "data": json.dumps(payload, default=self.json_serial)
            }

            self.write_results("shopify_log", [error_log,], keep_alive=True)

        # return the JSON Response Content
        return response

    def close_db_connection(self):
        """Closes the database connection"""

        # close db connection
        self.db_connection.close()

    def execute(self, sql, keep_alive=False):
        """Executes SQL Statement"""

        # get connection
        db_connection = self.get_db_connection()

        # run SQL
        try:
            with db_connection.cursor() as cursor:
                self.log(sql)
                cursor.execute(sql)
            db_connection.commit()
        finally:
            if not keep_alive:
                self.close_db_connection()

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
                msg = json.dumps(msg, default=self.json_serial)
            print datetime.now().strftime('%Y-%m-%d %H:%M:%S'), '|', msg

    def json_serial(self, obj):
        """JSON serializer for objects not serializable by default json code"""

        if isinstance(obj, (datetime, date)):
            return obj.isoformat()

        if isinstance(obj, decimal.Decimal):
            return str(obj)

        raise TypeError("Type %s not serializable" % type(obj))

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
                        # self.log(sql)
                        cursor.execute(sql, None)
                db_connection.commit()
        finally:
            self.close_db_connection()

    def push(self, *args, **kwargs):
        """Pushes data from the Staging Tables to Shopify API"""
        pass

    def write_results(self, db_table_name=None, results=None, rule=None, keep_alive=False):
        """
        Writes the results directly into a table.
        Note: This assumes each row dict has the exact same keys as the column names are derived
        off the first row
        """

        # get default table name
        if not db_table_name:
            db_table_name = self.db_table_name

        if results and len(results) > 0:

            # get db connection
            db_connection = self.get_db_connection()

            # build insert SQL
            columns = results[0].keys()
            columns_names = ["`" + c + "`" for c in columns]
            columns_values = ["%(" + c + ")s" for c in columns]
            column_names_sql = ", ".join(columns_names)
            column_values_sql = ", ".join(columns_values)

            if rule == "IGNORE":
                sql_insert = """
                    INSERT IGNORE INTO {0}
                        ( {1} )
                    VALUES
                        ( {2} )
                    """.format(db_table_name, column_names_sql, column_values_sql)
            else:
                sql_insert = """
                    INSERT INTO {0}
                        ( {1} )
                    VALUES
                        ( {2} )
                    """.format(db_table_name, column_names_sql, column_values_sql)

            try:
                with db_connection.cursor() as cursor:

                    # Insert Records
                    self.log(sql_insert)
                    cursor.executemany(sql_insert, results)

                # commit
                db_connection.commit()

            except Exception as e:

                print "error"
                import sys
                import traceback
                exc_type, exc_value, exc_traceback = sys.exc_info()
                lines = traceback.format_exception(exc_type, exc_value, exc_traceback)
                print ''.join('!! ' + line for line in lines)  # Log it or whatever here
                raise

            finally:

                # close
                if not keep_alive:
                    self.close_db_connection()
