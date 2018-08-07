"""
Customers
~~~~~~~~~
Handling Customer Export.
Must be run before GIFT_CARDS and before ORDERS.

Priming Tables used:
- *_customer

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
                    FROM shopify_customer c
                    WHERE 
                      c.shopify_id IS NULL
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
                              `first_name`, `last_name`, 
                              `company`,
                              `address1`, `address2`, 
                              `city`, 
                              `province`, `country_code`, `zip`,
                              `phone`,
                              `is_default` as `default`
                        FROM shopify_customer_address
                        WHERE email = '%s'
                    """ % c.get("email")

                    self.log(address_sql)
                    cursor.execute(address_sql)
                    addresses = list(cursor.fetchall())
                    fixed_addresses = []
                    for a in addresses:
                        a["city"] = a.get("city").title()
                        a["address1"] = a.get("address1").title()
                        a["address2"] = a.get("address2").title()
                        fixed_addresses.append(a)

                    payload["customer"]["addresses"] = fixed_addresses

                    # get default phone number
                    for a in payload["customer"]["addresses"]:
                        if a.get("default"):
                            payload["customer"]["phone"] = a.get("phone")

                    # get meta field info
                    metafields_sql = """
                        SELECT
                          `key`,
                          `description`,
                          `namespace`,
                          `value`,
                          `value_type`
                        FROM shopify_customer_metafield
                        WHERE email = '%s'
                    """ % c.get("email")

                    self.log(metafields_sql)
                    cursor.execute(metafields_sql)
                    payload["customer"]["metafields"] = list(cursor.fetchall())

                    # put data
                    print "Pushing %s." % (c.get("email"),)
                    self.log(payload)
                    result = self.api_send('/customers.json', payload, "post")

                    # if specific errors
                    if result.get("errors"):

                        errors = result.get("errors")

                        # invalid phone -> pop phone off to the 'notes' field
                        if isinstance(errors.get("phone"), list):

                            if "is invalid" in errors.get("phone") or "has already been taken" in errors.get("phone"):

                                addresses = payload["customer"]["addresses"]
                                updated_addresses = []

                                # loop through addresses
                                old_phone = ""
                                for a in addresses:
                                    phone = a.get("phone")
                                    if phone and phone != old_phone:
                                        old_phone = phone
                                        if payload.get("notes"):
                                            payload["notes"] = payload.get("notes") + ", " + phone
                                        else:
                                            payload["notes"] = phone

                                    a["phone"] = ""

                                    updated_addresses.append(a)

                                payload["customer"]["addresses"] = updated_addresses

                                # put data again
                                print "Pushing AGAIN %s." % (c.get("email"),)
                                self.log(payload)
                                result = self.api_send('/customers.json', payload, "post")

                    # write the shopify id
                    if result.get("customer"):
                        shopify_id = result.get("customer", {}).get("id")
                        sql = """
                            UPDATE shopify_customer
                            SET shopify_id = %s
                            WHERE email = '%s';
                        """ % (shopify_id, c.get("email"))

                    self.execute(sql, keep_alive=True)

                    # todo: update if exist? set shopify_id if exist?

        finally:
            self.close_db_connection()

        pass