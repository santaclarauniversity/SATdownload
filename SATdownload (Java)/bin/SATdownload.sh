#!/bin/bash
#
# Script to aid in the execution of SATdownload.jar
#

CONFIG_FILE=config.properties
JAVA=/usr/bin/java
BIN_DIR=$(/usr/bin/dirname $0)

cd $BIN_DIR
$JAVA -jar SATdownload.jar --config=$CONFIG_FILE