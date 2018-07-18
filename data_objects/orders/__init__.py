"""
Orders
~~~~~~
Handling Order Export
Must be run after PRODUCTS and CUSTOMERS.

Priming Tables used:
- *_order

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
    db_executable_sql = "populate_shopify_order.sql"

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

                # get records
                sql = """
                    SELECT 
                      `email`,
                      `name`,
                      `phone`,
                      `subtotal_price`,
                      `total_line_items_price`,
                      `total_discounts`,
                      `total_price`,
                      `total_tax`,
                      `total_weight`,
                      `customer_locale`,
                      `currency`,
                      NULL AS `source_name`,
                      `processed_at`,
                      `cancel_reason`,
                      `cancelled_at`,
                      `tags`,
                      `comments`
                    FROM shopify_order
                    WHERE email = 'kcallahan@gmail.com'
                    ORDER BY email
                    LIMIT 2
                    """

                # run sql
                self.log(sql)
                cursor.execute(sql)
                records = cursor.fetchall()
                for r in records:

                    order_name = r.get("name")

                    # base record
                    payload = {
                        "order": r
                        }
                    payload["order"]["billing_address"] = {}
                    payload["order"]["shipping_address"] = {}

                    payload["order"]["line_items"] = []
                    payload["order"]["transactions"] = []
                    payload["order"]["tax_lines"] = []
                    payload["order"]["discount_codes"] = []
                    payload["order"]["fulfillments"] = []
                    payload["order"]["shipping_lines"] = []
                    payload["order"]["metafields"] = []

                    payload["order"]["refunds"] = []

                    # confirmations
                    payload["order"]["suppress_notifications"] = True
                    payload["order"]["send_receipt"] = False
                    payload["order"]["send_fulfillment_receipt"] = False

                    # comments
                    comments = r.get("comments")
                    payload["order"].pop('comments', None)
                    payload["order"]["note_attributes"] = [
                        {
                            "name": "Legacy Comments",
                            "value": comments
                        }
                    ]

                    # get address info
                    address_sql = """
                        SELECT DISTINCT
                              `first_name`, `last_name`, `company`,
                              `address1`, `address2`, 
                              `city`, `province`,`country_code`, `zip`,
                              `phone`,
                              `is_billing`, `is_shipping`
                        FROM shopify_order_address
                        WHERE name = '%s'
                    """ % order_name

                    self.log(address_sql)
                    cursor.execute(address_sql)
                    addresses = cursor.fetchall()
                    for a in addresses:
                        if a.get("is_billing"):
                            a.pop('is_billing', None)
                            a.pop('is_shipping', None)
                            payload["order"]["billing_address"] = a
                        if a.get("is_shipping"):
                            a.pop('is_billing', None)
                            a.pop('is_shipping', None)
                            payload["order"]["shipping_address"] = a

                    # get line items
                    attribute_sql = """
                        SELECT
                          `sku`,
                          `title`,
                          `fulfillment_service`,
                          `fulfillment_status`,
                          `quantity`,
                          `price`,
                          `grams`,
                          -- `total_tax`,
                          `total_discount`,
                          `requires_shipping`
                          -- , `taxable`
                        FROM shopify_order_line_item
                        WHERE name = '%s'
                    """ % order_name

                    self.log(attribute_sql)
                    cursor.execute(attribute_sql)
                    payload["order"]["line_items"] = list(cursor.fetchall())

                    # get transactions
                    attribute_sql = """
                        SELECT
                          `authorization`,
                          `gateway`,
                          `amount`,
                          `kind`,
                          `status`
                        FROM shopify_order_transaction
                        WHERE name = '%s'
                    """ % order_name

                    self.log(attribute_sql)
                    cursor.execute(attribute_sql)
                    payload["order"]["transactions"] = list(cursor.fetchall())

                    # get tax lines
                    attribute_sql = """
                        SELECT
                          `rate`,
                          `price`,
                          `title`
                        FROM shopify_order_tax_line
                        WHERE name = '%s'
                    """ % order_name

                    self.log(attribute_sql)
                    cursor.execute(attribute_sql)
                    payload["order"]["tax_lines"] = list(cursor.fetchall())

                    # get discounts
                    attribute_sql = """
                        SELECT
                          `code`,
                          `type`,
                          `amount`
                        FROM shopify_order_discount
                        WHERE name = '%s'
                    """ % order_name

                    self.log(attribute_sql)
                    cursor.execute(attribute_sql)
                    payload["order"]["discount_codes"] = list(cursor.fetchall())

                    # get fulfillments
                    attribute_sql = """
                        SELECT
                          `status`,
                          `tracking_company`,
                          `tracking_number`,
                          6948946038 as location_id
                        FROM shopify_order_fulfillment
                        WHERE name = '%s'
                    """ % order_name

                    self.log(attribute_sql)
                    cursor.execute(attribute_sql)
                    payload["order"]["fulfillments"] = list(cursor.fetchall())

                    # get shipping lines
                    attribute_sql = """
                        SELECT
                          `code`,
                          `price`,
                          `source`,
                          `title`
                        FROM shopify_order_shipping_line
                        WHERE name = '%s'
                    """ % order_name

                    self.log(attribute_sql)
                    cursor.execute(attribute_sql)
                    payload["order"]["shipping_lines"] = list(cursor.fetchall())

                    # get shipping lines
                    attribute_sql = """
                        SELECT
                          `code`,
                          `price`,
                          `source`,
                          `title`
                        FROM shopify_order_shipping_line
                        WHERE name = '%s'
                    """ % order_name

                    self.log(attribute_sql)
                    cursor.execute(attribute_sql)
                    payload["order"]["shipping_lines"] = list(cursor.fetchall())

                    # get meta field info
                    metafields_sql = """
                        SELECT
                          `key`,
                          `namespace`,
                          `value`,
                          `value_type`
                        FROM shopify_order_metafield
                        WHERE name = '%s'
                    """ % order_name

                    self.log(metafields_sql)
                    cursor.execute(metafields_sql)
                    payload["order"]["metafields"] = list(cursor.fetchall())

                    # put data
                    self.log(payload)
                    result = self.api_send('/orders.json', payload, "post")

                    # write the shopify id
                    if result.get("order"):

                        shopify_id = result.get("order", {}).get("id")

                        sql = """
                            UPDATE shopify_order
                            SET shopify_id = %s
                            WHERE `name` = '%s';
                        """ % (shopify_id, order_name)

                        self.execute(sql, keep_alive=True)

                        # Close Orders
                        if payload["order"].get("closed_at"):
                            endpoint = '/orders/%s/close.json' % shopify_id
                            result = self.api_send(endpoint, None, "post")

                        # Cancel Orders
                        if payload["order"].get("cancelled_at"):
                            endpoint = '/orders/%s/cancel.json' % shopify_id
                            result = self.api_send(endpoint,
                                {
                                    'reason': payload["order"].get("cancel_reason")
                                }, "post")

                    # todo: update if exist?



        finally:
            self.close_db_connection()

        pass