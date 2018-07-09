"""
Data Object Classes
~~~~~~~~~~~~~~~~~~~
Global Classes that make adding addition Export-Import scripts easy.
"""

# standard library imports
from datetime import datetime
import os

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
        if self.verbose == 1:
            print datetime.now().strftime('%Y-%m-%d %H:%M:%S'), '|', msg

    def prime(self, *args, **kwargs):
        """Primes the Staging Tables"""

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

