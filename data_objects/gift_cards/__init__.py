"""
Gift Cards
~~~~~~~~~~
Handling Gift Card Export.
Must be run AFTER customers is imported.
Must be run BEFORE customers is imported.

Priming Tables used:
- *_gift_card

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
    db_executable_sql = "populate_shopify_gift_card.sql"

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
                     `code`,
                     `initial_value`,
                     `balance`,
                     `currency`,
                     `expires_on`,
                     `user_id`,
                     `disabled_at`,
                     `note`,
                     `shopify_id`
                    FROM shopify_gift_card
                    WHERE shopify_id IS NULL
                    ORDER BY `code`
                    """

                # run sql
                self.log(sql)
                cursor.execute(sql)
                records = cursor.fetchall()
                for r in records:

                    code = r.get("code")

                    # reset balance to initial value
                    r["note"] = "Initial Balance: %s" % r.get("initial_value")
                    r["initial_value"] = r.get('balance')

                    if r["initial_value"] == 0:
                        r["initial_value"] = 0.01

                    # code must be 8 chars so append "-000" to end
                    code_length = len(r["code"])
                    if code_length < 8:

                        # add padding
                        padding = 8 - code_length - 1

                        # add note
                        if r.get("note"):
                            r["note"] = r["note"] + "\n Original Code was %s. Had to add padding to make 8 chars." % code
                        else:
                            r["note"] = "Original Code was %s. Had to add padding to make 8 chars." % code

                        # change code
                        r["code"] = code + "-" + ("0" * padding)

                    # base record
                    payload = {
                      "gift_card": r
                    }

                    # put data
                    self.log(payload)
                    if r.get("shopify_id"):
                        result = self.api_send('/gift_cards/%s.json' % r.get("shopify_id"), payload, "put")
                    else:
                        result = self.api_send('/gift_cards.json', payload, "post")

                    # write the shopify id
                    if result.get("gift_card"):

                        shopify_id = result.get("gift_card", {}).get("id")

                        sql = """
                            UPDATE shopify_gift_card
                            SET shopify_id = %s
                            WHERE code = '%s';
                        """ % (shopify_id, code)

                        self.execute(sql, keep_alive=True)

                        # Disable Gift Card
                        if payload["gift_card"].get("disabled_at"):
                            endpoint = '/gift_cards/%s/disable.json' % shopify_id
                            result = self.api_send(endpoint, None, "post")

                    # todo: update if exist? set shopify_id if exist?

        finally:
            self.close_db_connection()

        pass