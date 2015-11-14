#!/usr/bin/perl
use strict;
use warnings;
use 5.012;
###############################################################################
# SATdownload.pl
# Copyright (C) 2015 Santa Clara University
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
# score files.
#
# Documenation on the PAScoresDwnld API can be found at
# https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features
#
# Author: Brian Moon (bmoon@scu.edu)
# Version: 1.0
# Copyright: Santa Clara University

use constant TRUE => 1;
use constant FALSE => 0;
use Config::General qw(ParseConfig);
use JSON;
use POSIX qw(strftime);
use REST::Client;
use DATA::Dump qw(dump ddx);

#############
# Main Body #
#############
printLicense();

# Initialize variables and set defaults
my $configFile = "SATdownload.conf";
my $date = strftime("%Y%m%d", localtime);
my $fileNum = -1;
my $fileName = "";
my $writeCounterFile = TRUE;

# Set default config
my %defaultConfig = (
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

if($fileNum ne "") {
  $writeCounterFile = FALSE;
}
if($fileName ne "") {
  $writeCounterFile = FALSE;
  $config{downloadConsecutiveFiles} = FALSE; 
}


# Get current counter
#if($fileNum < 0) {
#  $fileNum = readCounterFile($config{counterFile});
#}

#if(!$fileName) {
#  $fileName = $config{orgID}."_".$date."_".pad($fileNum,$config{fileNumPadding}).".".$config{fileExtension};
#}

if(!$fileName) {
  $fileName = getNextFileName();
}
my $successfulDownload = FALSE;

do {
  logMsg("Getting download URL for $fileName");
  $successfulDownload = downloadFile($fileName);
  if($successfulDownload && $writeCounterFile) {
    writeFile($config{counterFile}, $fileNum) or die "Error writing to counter file!";
  }
  ++$fileNum;
  getNextFileName();
} while($config{downloadConsecutiveFiles} && $successfulDownload);
logMsg("Done!");

#############
# Functions #
#############
sub downloadFile {
  my ($fileName) = @_;
  my $client = REST::Client->new();
  $client->addHeader('Content-Type', 'application/json');
  $client->addHeader('Accept', 'application/json');
  $client->POST($config{scoredwnldUrlRoot}.'/pascoredwnld/file?filename='.$fileName, to_json({username => $config{username}, password => $config{password}}));
  
  my $json = JSON->new->allow_nonref;
  logMsg("Response Code: ".$client->responseCode());
  if($client->responseCode() == 200) {
    logMsg("Response Code: ".$client->responseCode());
    my $responseContent = $json->decode($client->responseContent());
    logMsg("Response Content: ".$json->pretty->encode($responseContent));
  
    return download($responseContent->{"fileUrl"}, $fileName);
  } else {
    return FALSE;
  }
}

sub download {
  my ($fileUrl) = $_[0];
  my ($fileName) = $_[1];
  logMsg("File URL: ".$fileUrl);
  my $client = REST::Client->new();
  $client->GET($fileUrl);
  if($client->responseCode() == 200) {
    logMsg("Saving file to $config{localFilePath}$fileName");
    return writeFile($config{localFilePath}.$fileName, $client->responseContent());
  } else {
    logMsg("Could not download file! Response Code: ".$client->responseCode());
    logMsg("Content: ".$client->responseContent());
  }
  return FALSE;
}

sub getNextFileName {
  if($fileNum < 0) {
    $fileNum = readFile($config{counterFile}) + 1;
  }

  return $fileName = $config{orgID}."_".$date."_".pad($fileNum,$config{fileNumPadding}).".".$config{fileExtension};
}

sub readFile {
  chomp(my $text = do {
    open( my $fh, $_[0] ) or return 0;
    local $/ = undef;
    <$fh>;
  });
  return $text;  
}

sub logMsg {
  my ($msg) = @_;
  my $time = strftime("%Y-%m-%d %H:%M:%S", localtime);
  println($time."\t".$msg);
}

sub pad {
  my ($str) = $_[0];
  my ($len) = $_[1];
  
  while(length($str) < $len) {
   $str = "0" . $str;
  }
  return $str;
}

sub println {
 print @_, "\n";
}

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

sub printLicense {
  println("SATdownload.pl  Copyright (C) 2015  Santa Clara University");
  println("This program comes with ABSOLUTELY NO WARRANTY.  This is free software, and you");
  println("are welcome to redistribute it under certain conditions.  For those conditions,");
  println("please refer to the License section in the header of this file.\n");
}

sub writeFile {
  my ($fileName) = $_[0];
  my ($fileContent) = $_[1];
  open (my $fh, '>', $fileName) or die "Could not open file '$fileName' to write: $!";
  print $fh $fileContent;
  close $fh;
  return TRUE;
}