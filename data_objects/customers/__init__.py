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
import os

# related third party imports

# local application/library specific imports

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

        self.log("Pushing Data...")

        # run sql
        db_connection = self.get_db_connection()

        try:

            with db_connection.cursor() as cursor:

                # get customers
                sql = """
                    SELECT 
                    	email, first_name, last_name,
                    	tags, 
                    	IFNULL(note, '') AS note, 
                    	accepts_marketing, tax_exempt
                    FROM shopify_customer
                    ORDER BY email
                    """

                # run sql
                self.log(sql)
                cursor.execute(sql)
                customers = cursor.fetchall()
                for c in customers:

                    # base record
                    payload = {
                        "customer": {
                            "first_name": c.get("first_name"),
                            "last_name": c.get("last_name"),
                            "accepts_marketing": c.get("accepts_marketing"),
                            "email": c.get("email"),
                            "tags": c.get("tags"),
                            "note": c.get("note"),
                            "verified_email": True,
                            "addresses": [],
                            "metafields": [],
                            "send_email_welcome": False,
                            "send_email_invite": False
                            }
                        }

                    # get address info
                    address_sql = """
                        SELECT DISTINCT 
                              `first_name`, `last_name`, `company`,
                              `address1`, `address2`, 
                              `city`, `province`, `country_code`, `zip`,
                              `phone`,
                              `is_default` as `default`
                        FROM shopify_customer_address
                        WHERE email = '%s'
                    """ % c.get("email")

                    self.log(address_sql)
                    cursor.execute(address_sql)
                    payload["customer"]["addresses"] = list(cursor.fetchall())

                    # get default phone number
                    for a in payload["customer"]["addresses"]:
                        if a.get("default"):
                            payload["customer"]["phone"] = a.get("phone")

                    # get meta field info
                    metafields_sql = """
                        SELECT
                          `key`,
                          `namespace`,
                          `value`,
                          `value_type`
                        FROM shopify_customer_metafield
                        WHERE email = '%s'
                    """ % c.get("email")

                    self.log(metafields_sql)
                    cursor.execute(metafields_sql)
                    payload["customer"]["metafields"] = list(cursor.fetchall())

                    self.log(payload)

                    # put data
                    result = self.api_send('/customers.json', payload, "post")

                    # write the shopify id
                    if result.get("customer"):
                        shopify_id = result.get("customer", {}).get("id")
                        sql = """
                            UPDATE shopify_customer
                            SET shopify_id = %s
                            WHERE email = '%s';
                        """ % (c.get("email"), shopify_id)

                    # todo: update if exist? set shopify_id if exist?

        finally:
            self.close_db_connection()

        pass