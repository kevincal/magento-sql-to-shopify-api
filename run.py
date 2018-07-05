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


# main
def main():
    '''This function parses and return arguments passed in'''

    # Assign description to the help doc
    parser = argparse.ArgumentParser(
        description='Script runs the MLC BI utilities.')

    # Add arguments
    parser.add_argument(
        '-l', '--list', action="store_true", help='List Available ETL Modules', required=False)
    parser.add_argument(
        '-m', '--modules', type=str, help='Import modules to run. Comma-separated. ', required=False, default=None)
    parser.add_argument(
        '-r', '--run', action="store_true",  help='Run Modules', required=False)
    parser.add_argument(
        '-v', '--verbose', action="store_true",  help='Verbosity. 0=Silent, 1=Debug', required=False)

    # Array for all arguments passed to script
    args = parser.parse_args()

    # get available modules
    etl_modules = []
    all_modules = inspect.getmembers(objects, inspect.ismodule)
    for m in all_modules:
        if hasattr(m[1], 'Wrangler'):
            etl_modules.append(m)

    # Output List of Modules if --list / -l is passed.
    if args.list:
        table_data = list()
        table_data.append(['Module', 'Description'])
        for m in etl_modules:
            table_data.append([m[0], m[1].__doc__.strip()])

        table = AsciiTable(table_data)
        table.inner_row_border = True

        # output
        print "\nBelow is a list of available modules that can be run using the -m / --modules argument.\n"
        print table.table

    # filter modules
    if args.modules:
        selected_modules = []
        module_list = [m for m in args.modules.split(',')]
        for m in etl_modules:
            if m[0] in module_list:
                selected_modules.append(m)
        etl_modules = selected_modules

    # date range
    date_range = [args.date_start, args.date_end]

    # run Modules
    if args.run:
        if args.verbose:
            print "Running ETL modules..."
            print "Date Range: ", date_range
            print "Modules: ", [m[0] for m in etl_modules]

        for m in etl_modules:

            if args.verbose:
                print "---------- " + m[0] + " ------------------------------------------------------------ "

            # set verbose
            verbose = 1 if args.verbose else 0

            # if Wrangler
            if hasattr(m[1], "Wrangler"):
                w = m[1].Wrangler(verbose=verbose)

                try:
                    if args.verbose:
                        print "\nEXTRACTING:"
                    w.extract(date_range=date_range)
                except Exception as err:
                    traceback.print_exc()
                    w.log(err)

                try:
                    if args.verbose:
                        print "\nLOADING:"
                    w.load()
                except Exception as err:
                    traceback.print_exc()
                    w.log(err)

            # if Wrangler
            if hasattr(m[1], "Pusher"):
                p = m[1].Pusher(verbose=verbose)

                try:
                    if args.verbose:
                        print "\nPUSHING:"
                    p.push()
                except Exception as err:
                    traceback.print_exc()
                    p.log(err)


    # Return all variable values
    return True

# run main
main()
