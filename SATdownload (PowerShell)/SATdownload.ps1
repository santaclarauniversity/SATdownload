###############################################################################
# SATdownload.ps1
# Copyright (C) 2017 Santa Clara University
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

<#
.SYNOPSIS
  Download SAT score files from CollegeBoard
.DESCRIPTION
  This script will use the PAScoresDwnld API from CollegeBoard to download SAT score files.  This program has been designed so that it can run from the command line in an automated fashion and keep track of the last file number to successfully download.

  In order to use this, a config file is needed (see SATdownload.conf).  At the very least, this file must specify the username, password, orgID, and localFilePath.
.PARAMETER All
  Download all files currently available.
.PARAMETER ConfigFile
  Specify the path and file name of the config file. Default is SATdownload.conf.
.PARAMETER FileName
  Specify the exact file name to download.
.PARAMETER FromDate
  Download all files that have been posted since a certain date.  A time can also be specified with the date.  If no time is given, then 12:00:00 AM is assumed.  The time zone used is specified in the configuration file (default value is the system time zone).
.LINK
  Documenation on the PAScoresDwnld API can be found at https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#download-using-a-web-service
.NOTES
  Author: Brian Moon
  Version: 2.0
  Copyright: Santa Clara University

  Change Log:
  Version 2.0
    With the addition of the File Directory Listing API from Collegeboard, the following new parameters have been introduced:
      -All
      -FromDate

    These paramters allow the user to download all files that have been posted, or only those files that have been posted after a specified date and time.

    With the change in the filename to no longer include a sequence number, the following options have been removed from the config file:
      counterFile
      downloadConsecutiveFiles      
      fileExtension
      fileNumPadding

    The following parameters have also been removed:
      -Date
      -FileNum

    The following functions have also been removed:
      Get-NextFileName
      Pad-Number
#>
[cmdletbinding()]
Param(
  [Parameter(Mandatory=$True)]
    [String]$ConfigFile = "SATdownload.conf",
  [switch]$All,
  [String]$FileName,
  [DateTime]$FromDate
)


#############
# Functions #
#############

<#
.SYNOPSIS
  Download the specified file from SAT
.DESCRIPTION
  Use the PAScoresDwnld web service to download a file.  A pre-signed URL will be obtained using the filename, username, and password.  This URL will then be used to download the file.
.LINK
  For additional documentation on the web service function, please see: https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#feature
.PARAMETER FileName
  Name of SAT score file to download
#>
function Download-File {
  Param(
    [Parameter(Mandatory=$True)]
      [String]$FileName
  )

  # Create REST request and attempt to get the fileURL
  $Header = @{ 'Content-Type' = 'application/json'; 'Accept' = 'application/json'}
  $Body = @{ username = "$($Config.username)"; password = "$($Config.password)" } | ConvertTo-Json

  try {
    $Response = Invoke-RestMethod -Method Post -Uri "$($Config.scoredwnldUrlRoot)/pascoredwnld/file?filename=$FileName" -Headers $Header -Body $Body
  } catch {
    Write-Log "Error getting download URL for file $FileName"
    Write-Log "Request URL: $($Config.scoredwnldUrlRoot)/pascoredwnld/file?filename=$FileName"
    Write-Log "Response Code: $($PSItem.Exception.Response.StatusCode.value__)"
    Write-Log "Response Description: $($PSItem.Exception.Response.StatusDescription)"
    return
  }
  
  Write-Log "Response Content: $Response"
  Write-Log "Downloading file: $($Response.fileName)"
  try {
    Invoke-RestMethod -Method Get -Uri $Response.fileUrl -OutFile $(Join-Path -Path $Config.localFilePath -ChildPath $FileName)
  } catch {
    Write-Log "Error downloading file $FileName from $($Response.fileUrl)"
    Write-Log "Response Code: $($PSItem.Exception.Response.StatusCode.value__)"
    Write-Log "Response Description: $($PSItem.Exception.Response.StatusDescription)"
    return
  }
}

<#
.SYNOPSIS
  Generate a list of all files available for download.
.PARAMETER FromDate
  Optional parameter to specify a date to list all files posted after.  The Time Zone used is specified in the Config object.
.OUTPUTS
  Array of files
.LINK
  For details on the file information included, please refer to the "File Directory Listing API" available at
  https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#download-using-a-web-service
#>
function Get-FileListing {
  Param(
    [DateTime]$FromDate
  )
  
  # Create REST::Client
  # Create REST request and attempt to get the fileURL
  $Header = @{ 'Content-Type' = 'application/json'; 'Accept' = 'application/json'}
  $Body = @{ username = $Config.username; password = $Config.password } | ConvertTo-Json

  try {
   # Attempt to get file listing
    if($FromDate) {
      $Response = Invoke-RestMethod -Method Post -Uri "$($Config.scoredwnldUrlRoot)/pascoredwnld/files/list?fromDate=$($FromDate.ToString("yyyy-MM-ddTHH:mm:ss$($Config.GMTOffset)"))" -Headers $Header -Body $Body
    } else {
      $Response = Invoke-RestMethod -Method Post -Uri "$($Config.scoredwnldUrlRoot)/pascoredwnld/files/list" -Headers $Header -Body $Body
    }
    
  } catch {
    if($FromDate) {
      Write-Log "Error getting list of files posted since $FromDate"
    } else {
      Write-Log "Error getting list of all files"
    }
    Write-Log "Response Code: $($PSItem.Exception.Response.StatusCode.value__)"
    Write-Log "Response Description: $($PSItem.Exception.Response.StatusDescription)"
    return
  }
  
  return $Response.files
}

<#
.SYNOPSIS
  Print license information to the console
#>
function Write-License {
  Write-Output "ACTdownload.ps1  Copyright (C) 2017  Santa Clara University"
  Write-Output "This program comes with ABSOLUTELY NO WARRANTY.  This is free software, and you"
  Write-Output "are welcome to redistribute it under certain conditions.  For those conditions,"
  Write-Output "please refer to the License section in the header of this file."
}

<#
.SYNOPSIS
  Print a time-stamped log message
.PARAMETER Message
  Log message to print
#>
function Write-Log {
  [cmdletbinding()]
  Param(
    [Parameter(Mandatory=$True)]
      [String]$Message
  )
  
  $time = $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")
  Write-Output "$time`t$Message"
}


#############
# Main Body #
#############
Write-License

# Initialize global variables and set defaults
$writeCounterFile = $True;

# Set default config
$Config = @{
  scoredwnldUrlRoot = "https://scoresdownload.collegeboard.org";
  GMTOffset = "zz00"
}

# Load Config
if(!$(Test-Path $ConfigFile)) {  
  Write-Error "Count not find config file $ConfigFile"
  exit 3
}
Write-Log "Loading config file $ConfigFile"
switch -Regex -File $ConfigFile {
  # Comments
  "^((#|;|//).*)$" { continue }
  # Load values
  "^(.+?)\s*=\s*(.*)" {
    $name,$value = $matches[1..2]
    $Config[$name] = $value.Trim().Replace("`"", "")
  }
}

# Check if the user has selected to download all files in the directory
if($All) {
  # Get listing of available files
  $FileList = Get-FileListing
  # Check to see if there are any files available
  if(!$FileList) {
    Write-Log "No files to download."
    exit 0
  }
  # Iterate through list of files and download
  foreach ($File in $FileList) {
    Write-Log "File name: $($file.fileName)"
    Download-File -FileName $file.fileName
  }
  Write-Log "All downloads are complete."
  exit 0
}

# Check if fromDate has been set
elseif($FromDate) {
  # Get listing of available files from the specified date
  $FileList = Get-FileListing -FromDate $FromDate
  # Check to see if there are any files available
  if(!$FileList) {
    Write-Log "No files to download."
    exit 0
  }
  # Iterate through list of files and download
  foreach ($File in $FileList) {
    Write-Log "File name: $($file.fileName)"
    Download-File -FileName $file.fileName
  }
  Write-Log "All downloads are complete."
  exit 0
}

# Check if fileName has been set
elseif($FileName) {
  Write-Log "Getting download URL for $FileName"
  Download-File -FileName $FileName

  Write-Log "Done!"
}

else {
  Write-Log "You must specify whether to download all files (-All), a specific file (-FileName), or all files posted after a specific date (-FromDate)"
  exit 1
}