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
# --config=CONFIGFILE
#   Specify the path and file name of the config file. Default is
#   SATdownload.conf.
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
# -h | --help
#   Display this help information.
#
# Documenation on the PAScoresDwnld API can be found at
# https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features
#
# Exit Codes:
#  0 - Success
#  1 - Unknown option
#  2 - Cannot write file
#  500 - Internal error
#
# Author: Brian Moon (bmoon@scu.edu)
# Version: 1.2
# Copyright: Santa Clara University

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
my $exit_code = 0;
my $fileNum = "";
my $fileName = "";
my $writeCounterFile = TRUE;

# Set default config
my %defaultConfig = (
  scoredwnldUrlRoot => "https://scoresdownload.collegeboard.org",
  counterFile => "SATdownload.counter",
  downloadConsecutiveFiles => TRUE,
  fileExtension => "txt",
  fileNumPadding => 6
);

# Check options
foreach (@ARGV) {
  if(/^--config=/) { ($configFile = $_) =~ s/--config=//; }
  elsif(/^--date=/) { ($date = $_) =~ s/--date=|\/|\\//g; }
  elsif(/^--filenum=/) { ($fileNum = $_) =~ s/--filenum=//; }
  elsif(/^--filename=/) { ($fileName = $_) =~ s/--filename=//;  }
  elsif(/^(-h|--help)$/) { printHelp(); exit 0;}
  else { println("Unknown option: $_"); printHelp(); exit 1;}  
}

# Load Config
my %config = ParseConfig(-ConfigFile => $configFile, -AutoTrue => TRUE, -MergeDuplicateOptions => TRUE, -DefaultConfig => \%defaultConfig);

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
# Read a local file
#
# @param fileName - File to read
# @return Contents of the file as a String
sub readFile {
  # Verify numberof paramters
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
  println("Usage: SATdownload.pl [--date=DATE | --filenum=NUM | --filename=FILENAME]\n");
  println("Options:");
  println(" --config=CONFIGFILE");
  println("   Specify the path and file name of the config file. Default is"); 
  println("   SATdownload.conf.");
  println(" --date=DATE");
  println("   Specify date of file to download.  Default is today's date.");
  println("   Recommended format is YYYY/MM/DD.\n");
  println(" --filenum=NUM");
  println("   Specify the job number to start searching from.  This is the last");
  println("   part of the file name.  Default is the next number in the counter");
  println("   file.\n");
  println(" --filename=FILENAME");
  println("   Specify the exact file name to download.\n");
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