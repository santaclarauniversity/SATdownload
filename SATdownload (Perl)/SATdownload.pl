#!/usr/bin/perl
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

use JSON;
use REST::Client;

#############
# Main Body #
#############
printLicense();
printHelp();
my $num = pad("4", 6);
println($num);

#############
# Functions #
#############

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
  println("SATdownload.js  Copyright (C) 2015  Santa Clara University");
  println("This program comes with ABSOLUTELY NO WARRANTY.  This is free software, and you");
  println("are welcome to redistribute it under certain conditions.  For those conditions,");
  println("please refer to the License section in the header of this file.\n");
}

