#!/bin/sh

# get current path
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
if [ -z "$MY_PATH" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  echo 'FAIL'
  exit 1  # fail
fi

# execute file
$MY_PATH/magento-sql-to-shopify-api/bin/python2.7 $MY_PATH/run.py $@
