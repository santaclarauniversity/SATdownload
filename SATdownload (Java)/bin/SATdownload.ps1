#
# Script to aid in the execution of SATdownload.jar
#

$CONFIG_FILE=SATdownload.conf
$VERSION=1.1
$BIN_DIR=Split-Path -parent $MyInvocation.MyCommand.Source

cd $BIN_DIR
java -jar SATdownload-$VERSION.jar --config=$CONFIG_FILE