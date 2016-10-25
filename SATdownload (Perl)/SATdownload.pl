#!/usr/bin/perl
use strict;
use warnings;
use 5.012;
###############################################################################
# SATdownload.pl
# Copyright (C) 2016 Santa Clara University
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# For a copy of the GNU General Public License, v3.0, please refer to
# <https://www.gnu.org/licenses/gpl-3.0.en.html>.
#
# Additional Terms:
#   1. Santa Clara University reserves the right to refuse support of the
#      software at any time.  We are not obligated to assist in documenting,
#      debugging, customizing, testing or otherwise explaining or supporting
#      the software.
#   2. Your institution may share the software (or derivative work) only for
#      educational or research purposes and must do so without charging any
#      fees.  This requirement revokes the permission in section 4 to charge
#      a fee for this or any derivative work.
###############################################################################
###############################################################################
# This script will use the PAScoresDwnld API from CollegeBoard to download SAT
# score files. This program has been designed so that it can run from the
# command line in an automated fashion and keep track of the last file number
# to successfully download.
#
# In order to use this, a config file is needed (see SATdownload.conf). At the
# very least, this file must specify the username, password, orgID, and
# localFilePath.
#
# At run-time, the following options may be set:
# --all
#   Download all files currently available.
#
# --config=CONFIGFILE
#   Specify the path and file name of the config file. Default is
#   SATdownload.conf.
#
# --date=DATE
#   Specify date of file to download.  Default is today's date.
#   Recommended format is YYYY/MM/DD.
#
# --filenum=NUM
#   Specify the job number to start searching from.  This is the last
#   part of the file name.  Default is the next number in the counter
#   file.
#
# --filename=FILENAME
#   Specify the exact file name to download.
#
# --fromdate=DATE
#   Download all files that have been posted since a certain date.  Date should
#   be in the format yyyy-MM-dd.
#
# --fromdatetime=DATETIME
#   Download all files that have been posted since a specified date and time.
#   The date and time should be in the format yyyy-MM-dd'T'HH:mm:ss.  For
#   example: 2016-01-30T23:11:55.  The Time Zone used is specified in the
#   configuration file (if not set, UTC is assumed).
#
# -h | --help
#   Display this help information.
#
# Documenation on the PAScoresDwnld API can be found at
# https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#download-using-a-web-service
#
# Exit Codes:
#  0 - Success
#  1 - Unknown option
#  2 - Cannot write file
#  3 - Error downloading a file
#  500 - Internal error
#
# Author: Brian Moon (bmoon@scu.edu)
# Version: 2.0
# Copyright: Santa Clara University
#
# Change Log:
# Version 2.0
#   With the addition of the File Directory Listing API from Collegeboard, the
#   following new parameters have been introduced:
#     --all
#     --fromdate
#     --fromdatetime
#   These paramters allow the user to download all files that have been posted,
#   or only those files that have been posted after a specified date and time. 

use constant TRUE => 1;
use constant FALSE => 0;
use Config::General qw(ParseConfig);
use File::Spec;
use JSON;
use Mozilla::CA;
use POSIX qw(strftime);
use REST::Client;


#############
# Main Body #
#############
printLicense();

# Initialize global variables and set defaults
my $configFile = "SATdownload.conf";
my $date = strftime("%Y%m%d", localtime);
my $downloadAll = FALSE;
my $exit_code = 0;
my $fileNum = "";
my $fileName = "";
my $fromDate = "";
my $writeCounterFile = TRUE;

# Set default config
my %defaultConfig = (
  scoredwnldUrlRoot => "https://scoresdownload.collegeboard.org",
  counterFile => "SATdownload.counter",
  downloadConsecutiveFiles => TRUE,
  fileExtension => "txt",
  fileNumPadding => 6,
  GMTOffset => "+0000"
);

# Check options
foreach (@ARGV) {
  if(/^--all/) { $downloadAll = TRUE; }
  elsif(/^--config=/) { ($configFile = $_) =~ s/--config=//; }
  elsif(/^--date=/) { ($date = $_) =~ s/--date=|\/|\\//g; }
  elsif(/^--filenum=/) { ($fileNum = $_) =~ s/--filenum=//; }
  elsif(/^--filename=/) { ($fileName = $_) =~ s/--filename=//;  }
  elsif(/^--fromdate=/) { ($fromDate = $_) =~ s/--fromdate=//; $fromDate = $fromDate."T00:00:00" }
  elsif(/^--fromdatetime=/) { ($fromDate = $_) =~ s/--fromdatetime=//;  }
  elsif(/^(-h|--help)$/) { printHelp(); exit 0;}
  else { println("Unknown option: $_"); printHelp(); exit 1;}  
}

# Load Config
my %config = ParseConfig(-ConfigFile => $configFile, -AutoTrue => TRUE, -MergeDuplicateOptions => TRUE, -DefaultConfig => \%defaultConfig);

# Check if the user has selected to download all files in the directory
if($downloadAll) {
  # Get listing of available files
  my @fileListing = getFileListing();
  # Check to see if there are any files available
  if(!@fileListing) {
    logMsg("No files to download.");
    exit 0;
  }
  # Iterate through list of files and download
  for my $file (@fileListing) {
    println("File name: ".$file->{fileName});
    if(!downloadFile($file->{fileName})) {
      $exit_code = 3;
      die "Failed to download $file->{fileName}";
    } 
  }
  logMsg("All downloads are complete.");
  exit 0;
}

# Check if fromDate has been set
if($fromDate ne "") {
  # If date was entered as YYYY/MM/DD convert it to YYYY-MM-DD
  $fromDate =~ s/\//-/g;
  # Get listing of available files from the specified date
  my @fileListing = getFileListing($fromDate);
  # Check to see if there are any files available
  if(!@fileListing) {
    logMsg("No files to download.");
    exit 0;
  }
  # Iterate through list of files and download
  for my $file (@fileListing) {
    println("File name: ".$file->{fileName});
    if(!downloadFile($file->{fileName})) {
      $exit_code = 3;
      die "Failed to download $file->{fileName}";
    } 
  }
  logMsg("All downloads are complete.");
  exit 0;
}

# Check if fileNum has been set
if($fileNum ne "") {
  $writeCounterFile = FALSE;
}

# Check if fileName has been set
if($fileName ne "") {
  $writeCounterFile = FALSE;
  $config{downloadConsecutiveFiles} = FALSE; 
} else {
  $fileName = getNextFileName();
}

# Boolean to track if download was successful
my $successfulDownload = FALSE;

# Attempt to download the file.  If successful and downloadConsecutiveFiles is
# TRUE, continue loop
do {
  logMsg("Getting download URL for $fileName");
  $successfulDownload = downloadFile($fileName);
  if($successfulDownload && $writeCounterFile) {
    # Write counter file
    if(!writeFile($config{counterFile}, $fileNum)) {
      $exit_code = 2;
      die "Error writing to counter file!";
    }
  }
  ++$fileNum;
  getNextFileName();
} while($config{downloadConsecutiveFiles} && $successfulDownload);
logMsg("Done!");


#############
# Functions #
#############

###############################################################################
# Use the PAScoresDwnld web service to download a file.  A pre-signed URL will
# be obtained using the filename, username, and password.  This URL will then
# be passed to download() to get the file.
#
# For additional documentation on the web service function, please see:
# https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features
#
# @param fileName Name of SAT score file to download
# @return TRUE if download was successful
#         FALSE if download failed
sub downloadFile {
  # Verify number of paramters
  if(scalar(@_) != 1) {
    $exit_code = 500;
    die "downloadFile(): Expected one parameter: fileName";
  }
  # Assign local variables
  my ($fileName) = $_[0];
  
  # Create REST::Client and attempt to get the fileURL
  my $client = REST::Client->new();
  $client->addHeader('Content-Type', 'application/json');
  $client->addHeader('Accept', 'application/json');
  $client->POST($config{scoredwnldUrlRoot}.'/pascoredwnld/file?filename='.$fileName, to_json({username => $config{username}, password => $config{password}}));
  
  # Create JSON object to parse the response
  my $json = JSON->new->allow_nonref;
  
  # Print response code to help with debugging
  logMsg("Response Code: ".$client->responseCode());
 
  # Check response code to see if the request was successful
  if($client->responseCode() == 200) {
    # Request was successful.  Use the fileUrl to download the file and return
    # the result of the download attempt.
    my $responseContent = $json->decode($client->responseContent());
    logMsg("Response Content: ".$json->pretty->encode($responseContent));
    return download($responseContent->{"fileUrl"}, $fileName);
  } elsif($client->responseCode() == 404) {
    # fileName does not exist
    my $responseContent = $json->decode($client->responseContent());
    logMsg("Response Content: ".$responseContent->{"message"});
  }else {
    # Other request error
    logMsg("Response content: ".$client->responseContent());
  }
  return FALSE;
}

###############################################################################
# Download and save a file using a pre-signed URL.
#
# For additional documentation, please see:
# https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features
#
# @param fileURL - Pre-signed URL or file to download
# @param fileName - Local path and file name to save file as
# @return TRUE is download was successful
#         FALSE is download or saving the file failed
sub download {
  # Verify number of paramters
  if(scalar(@_) != 2) {
    $exit_code = 500;
    die "download(): Expected two parameters: fileUrl, fileName.";
  }
  
  # Assign local variables
  my ($fileUrl) = $_[0];
  my ($fileName) = $_[1];
  
  # Attempt to download the file
  my $client = REST::Client->new();
  $client->GET($fileUrl);
  
  # Check response code to see if the request was successful
  if($client->responseCode() == 200) {
    # Request was successful.  Attempt to save the file locally and return the
    # result of writing the file.
    logMsg("Saving file to $config{localFilePath}$fileName");
    return writeFile(File::Spec->catfile($config{localFilePath}, $fileName), $client->responseContent());
  } else {
    # Request failed.  Print error information.
    logMsg("Could not download file! Response Code: ".$client->responseCode());
    logMsg("Content: ".$client->responseContent());
  }
  return FALSE;
}

###############################################################################
# Generate the name of the next file in the sequence to download. If counter
# has not been set, then the counter will be read from the counter file.
#
# @return File name
sub getNextFileName {
  # If fileNum has not been set, read from the counter file
  if($fileNum eq "") {
    logMsg("Getting counter from ".$config{counterFile});
    $fileNum = readFile($config{counterFile}) + 1;
  }

  # Return the next file name in the sequence
  return $fileName = $config{orgID}."_".$date."_".pad($fileNum,$config{fileNumPadding}).".".$config{fileExtension};
}

###############################################################################
# Generate a list of all files available for download.
#
# @param fromDate - Optional parameter to specify a date to list all files
#                   posted after.  The date format should be
#                   yyyy-MM-dd'T'HH:mm:ss.  For example: 2016-01-30T23:11:55.
#                   The Time Zone used is specified in the configuration file
#                   (if not set, UTC is assumed).
# @return Array of files.  For details on the file information included, please
#         refer to the "File Directory Listing API" available at
#         https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#download-using-a-web-service
sub getFileListing {
  my($fromDate) = 0;
  # Verify number of paramters
  if(scalar(@_) == 1) {
     $fromDate = $_[0].$config{GMTOffset};
  } elsif(scalar(@_) > 1) {
    $exit_code = 500;
    die "getFileListing(): Too many parameters provided.";
  }
  
  # Create REST::Client
  my $client = REST::Client->new();
  $client->addHeader('Content-Type', 'application/json');
  $client->addHeader('Accept', 'application/json');
  
  # Attempt to get file listing
  if($fromDate) {
    $client->POST($config{scoredwnldUrlRoot}.'/pascoredwnld/files/list?fromDate='.$fromDate, to_json({username => $config{username}, password => $config{password}}));
  } else {
    $client->POST($config{scoredwnldUrlRoot}.'/pascoredwnld/files/list', to_json({username => $config{username}, password => $config{password}}));
  }
  
  # Create JSON object to parse the response
  my $json = JSON->new->allow_nonref;
  
  # Print response code to help with debugging
  logMsg("Response Code: ".$client->responseCode());
 
  # Check response code to see if the request was successful
  if($client->responseCode() == 200) {
    # Request was successful.  Return the list of files.
    my $responseContent = $json->decode($client->responseContent());
    logMsg("Response Content: ".$json->pretty->encode($responseContent));
    # Return null if there are no files to download
    if(!$responseContent->{files}) {
      return;
    }
    # Return array of files available for download
    return @{$responseContent->{files}};
  } else {
    # Other request error
    logMsg("Response content: ".$client->responseContent());
  }
  return;
}

###############################################################################
# Read a local file
#
# @param fileName - File to read
# @return Contents of the file as a String
sub readFile {
  # Verify number of paramters
  if(scalar(@_) != 1) {
    $exit_code = 500;
    die "readFile(): Expected one parameter: fileName";
  }
  my ($fileName) = $_[0];
  
  # Read file
  chomp(my $text = do {
    open( my $fh, $fileName ) or return 0;
    local $/ = undef;
    <$fh>;
  });
  
  # Return the contents of the file as a String
  return $text;  
}

###############################################################################
# Print a time-stamped log message on the console
#
# @param msg Message to print
sub logMsg {
  my ($msg) = @_;
  my $time = strftime("%Y-%m-%d %H:%M:%S", localtime);
  println($time."\t".$msg);
}

###############################################################################
# Pad number with zeroes to get the correct number of digits
#
# @param str - String to pad
# @param len - Number of digits in padded string
# @return Padded string
sub pad {
  # Verify number of paramters
  if(scalar(@_) != 2) {
    $exit_code = 500;
    die "pad(): Expected two paramters: str, len";
  }
  my ($str) = $_[0];
  my ($len) = $_[1];
  
  # Pad str with 0s
  while(length($str) < $len) {
   $str = "0" . $str;
  }
  
  # Return padded string
  return $str;
}

###############################################################################
# Print a message to the console with a new-line character
#
# @param Message to print
sub println {
 print @_, "\n";
}

###############################################################################
# Print help information to the console
#
sub printHelp {
  println("Usage: SATdownload.pl [--all | --config=config.file | --date=DATE | --filenum=NUM | --filename=FILENAME | --fromdate=DATE | --fromdatetime=DATETIME]\n");
  println("Options:");
  println(" --all");
  println("   Download all files currently available.\n");
  println(" --config=CONFIGFILE");
  println("   Specify the path and file name of the config file. Default is"); 
  println("   SATdownload.conf.\n");
  println(" --date=DATE");
  println("   Specify date of file to download.  Default is today's date.");
  println("   Recommended format is YYYY/MM/DD.\n");
  println(" --filenum=NUM");
  println("   Specify the job number to start searching from.  This is the last");
  println("   part of the file name.  Default is the next number in the counter");
  println("   file.\n");
  println(" --filename=FILENAME");
  println("   Specify the exact file name to download.\n");
  println(" --fromdate=DATE");
  println("   Download all files that have been posted since a certain date.  Date should");
  println("   be in the format yyyy-MM-dd.\n");
  println(" --fromdatetime=DATETIME");
  println("   Download all files that have been posted since a specified date and time.");
  println("   The date and time should be in the format yyyy-MM-dd'T'HH:mm:ss.  For");
  println("   example: 2016-01-30T23:11:55.  The Time Zone used is specified in the");
  println("   configuration file (if not set, UTC is assumed).\n");  
  println(" -h | --help");
  println("   Display this help information.\n");
}

###############################################################################
# Print license information to the console
#
sub printLicense {
  println("SATdownload.pl  Copyright (C) 2016  Santa Clara University");
  println("This program comes with ABSOLUTELY NO WARRANTY.  This is free software, and you");
  println("are welcome to redistribute it under certain conditions.  For those conditions,");
  println("please refer to the License section in the header of this file.\n");
}

###############################################################################
# Write a local file.  This will clobber the current file with the new file
# content.
#
# @param fileName - File to read
# @param fileContent - Content to write to the file
# @return TRUE if file write was successful
#         FALSE if file write was unsuccessful
sub writeFile {
  # Verify number of paramters
  if(scalar(@_) != 2) {
    $exit_code = 500;
    die "writeFile(): Expected two parameters: fileName, fileContent";
  }
  my ($fileName) = $_[0];
  my ($fileContent) = $_[1];
  
  # Write file
  if(open (my $fh, '>', $fileName)) {
    binmode($fh);
    print $fh $fileContent;
    close $fh;
    return TRUE;
  } else {
    # Open file to write failed
    $exit_code = 3;
    die "Could not open file '$fileName' to write: $!";
    return FALSE;
  }
}

END {
  $! = $exit_code;
}