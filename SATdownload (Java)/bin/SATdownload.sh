#!/bin/bash
#
# Script to aid in the execution of SATdownload.jar
#

CONFIG_FILE=SATdownload.conf
VERSION=1.1
JAVA=/usr/bin/java
BIN_DIR=$(/usr/bin/dirname $0)

cd $BIN_DIR
$JAVA -jar SATdownload-${VERSION}.jar --config=$CONFIG_FILE
