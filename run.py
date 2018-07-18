#!/usr/bin/python
"""
Magento SQL to Shopify API Import Utility
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This command line utility that pulls data from Magento CE 1.9x SQL tables and pushes
data into the Shopify+ API.

Currently Supports:
 - Customers
 - Orders

(for Products, the Transporter App can be used)

"""

# library
import argparse
import inspect
import traceback

from terminaltables import AsciiTable

# get objects
import data_objects

# main
def main():
    '''This function parses and return arguments passed in'''

    # Assign description to the help doc
    parser = argparse.ArgumentParser(
        description='Script runs to run the Magento SQL -> Shopify API Export/Import Utility.')

    # Add arguments
    parser.add_argument(
        '-l', '--list', action="store_true", help='List Available Objects', required=False)
    parser.add_argument(
        '-o', '--objects', type=str, help='Objects to export / import. Comma-separated. ', required=False, default=None)
    parser.add_argument(
        '--prime', action="store_true", help='Prime Utility. Populate Staging Tables only.', required=False)
    parser.add_argument(
        '--push', action="store_true", help='Push Utility. Push data from Staging Tables into Shopify API', required=False)
    parser.add_argument(
        '-r', '--run', action="store_true",  help='Run Push then Pull Utilities', required=False)
    parser.add_argument(
        '-v', '--verbose', action="store_true",  help='Verbosity. 0=Silent, 1=Debug', required=False)

    # Array for all arguments passed to script
    args = parser.parse_args()

    # get available modules
    objects = []
    all_objects = inspect.getmembers(data_objects, inspect.ismodule)
    for o in all_objects:
        if hasattr(o[1], 'Object'):
            objects.append(o)

    # Output List of Modules if --list / -l is passed.
    if args.list:
        table_data = list()
        table_data.append(['Object', 'Description'])
        for o in all_objects:

            # skip over classes files
            if o[0] == "classes":
                continue

            # build ascii table
            table_data.append([o[0], o[1].__doc__.strip()])

        table = AsciiTable(table_data)
        table.inner_row_border = True

        # output
        print "\nBelow is a list of available objects that can be run using the -o / --objects argument.\n"
        print table.table

    # filter objects
    if args.objects:
        selected_objects = []
        object_list = [o for o in args.objects.split(',')]
        for o in all_objects:
            if o[0] in object_list:
                selected_objects.append(o)
        objects = selected_objects

    # run Modules
    prime_flag = args.prime
    push_flag = args.push

    if args.run:
        prime_flag = True
        push_flag = True

    if prime_flag or push_flag:

        if args.verbose:

            print "Running Utility..."
            print "Objects: ", [o[0] for o in objects]

        for o in objects:

            if args.verbose:
                print "---------- " + o[0] + " ------------------------------------------------------------ "

            # set verbose
            verbose = 1 if args.verbose else 0

            # if DataObject
            if hasattr(o[1], "DataObject"):

                obj = o[1].DataObject(verbose=verbose)

                if prime_flag:
                    try:
                        if args.verbose:
                            print "\nPRIMING:"
                            obj.prime()
                    except Exception as err:
                        traceback.print_exc()
                        obj.log(err)
                if push_flag:
                    try:
                        if args.verbose:
                            print "\nPUSHING:"
                        obj.push()
                    except Exception as err:
                        traceback.print_exc()
                        obj.log(err)

    # Return all variable values
    return True

# run main
main()
