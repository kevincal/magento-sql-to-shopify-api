"""
Products
~~~~~~~~
Handling Product Export

Priming Tables used:
- *_product
_ *_product_variant
_ *_product_image
_ *_product_metafield

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
    db_executable_sql = "populate_shopify_product.sql"

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
                      `handle`,
                      `title`,
                      `body_html`,
                      `metafields_global_title_tag`,
                      `metafields_global_description_tag`,
                      `vendor`,
                      `product_type`,
                      `published`,
                      `published_at`,
                      `published_scope`,
                      `tax_exempt`,
                      `tags`
                    FROM shopify_product
                    ORDER BY magento_id DESC
                    """

                # run sql
                self.log(sql)
                cursor.execute(sql)
                records = cursor.fetchall()
                for r in records:

                    handle = r.get("handle")

                    # base record
                    payload = {
                      "product": {
                        "handle": handle,
                        "title": r.get("handle"),
                        "body_html": r.get("body_html"),
                        "metafields_global_title_tag": r.get("metafields_global_title_tag"),
                        "metafields_global_description_tag": r.get("metafields_global_description_tag"),
                        "vendor": r.get("vendor"),
                        "product_type": r.get("product_type"),
                        "published": r.get("published"),
                        "published_at": r.get("published_at"),
                        "published_scope": r.get("published_scope"),
                        "tax_exempt": r.get("tax_exempt"),
                        "tags": r.get("tags"),
                        "variants": [],
                        "images": [],
                        "metafields": []
                        }
                    }

                    # get variant
                    variant_sql = """
                        SELECT
                          `handle`,
                          `fulfillment_service`,
                          `inventory_management`,
                          `price`,
                          `requires_shipping`,
                          `sku`,
                          `taxable`,
                          `weight`,
                          `weight_unit`
                        FROM shopify_product_variant
                        WHERE handle = '%s'
                        """ % handle

                    self.log(variant_sql)
                    cursor.execute(variant_sql)
                    payload["product"]["variants"] = list(cursor.fetchall())

                    # get image
                    image_sql = """
                        SELECT
                          `handle`, 
                          `position`, 
                          `src`
                        FROM shopify_product_image
                        WHERE handle = '%s'
                        """ % handle

                    self.log(image_sql)
                    cursor.execute(image_sql)
                    payload["product"]["images"] = list(cursor.fetchall())

                    # get meta field info
                    metafields_sql = """
                        SELECT
                          `key`,
                          `namespace`,
                          `value`,
                          `value_type`
                        FROM shopify_product_metafield
                        WHERE handle = '%s'
                    """ % handle

                    self.log(metafields_sql)
                    cursor.execute(metafields_sql)
                    payload["product"]["metafields"] = list(cursor.fetchall())

                    self.log(payload)

                    # put data
                    result = self.api_send('/products.json', payload, "post")

                    # write the shopify id
                    if result.get("product"):

                        shopify_id = result.get("product", {}).get("id")

                        sql = """
                            UPDATE shopify_product
                            SET shopify_id = %s
                            WHERE handle = '%s';
                        """ % (shopify_id, handle)

                        self.execute(sql, keep_alive=True)

                    # todo: update if exist? set shopify_id if exist?

        finally:
            self.close_db_connection()

        pass