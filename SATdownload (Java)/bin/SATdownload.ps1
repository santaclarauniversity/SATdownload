#
# Script to aid in the execution of SATdownload.jar
#

$CONFIG_FILE="config.properties"
$BIN_DIR=Split-Path -parent $MyInvocation.MyCommand.Source

cd $BIN_DIR
java -jar SATdownload.jar --config=$CONFIG_FILE