/**
 * SATdownload.js
 * Copyright (C) 2015 Santa Clara University
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * For a copy of the GNU General Public License, v3.0, please refer to
 * <https://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 * Additional Terms:
 *   1. Santa Clara University reserves the right to refuse support of the
 *      software at any time.  We are not obligated to assist in documenting,
 *      debugging, customizing, testing or otherwise explaining or supporting
 *      the software.
 *   2. Your institution may share the software (or derivative work) only for
 *      educational or research purposes and must do so without charging any
 *      fees.  This requirement revokes the permission in section 4 to charge
 *      a fee for this or any derivative work.
 */

/**
 * This script will use the PAScoresDwnld API from CollegeBoard to download SAT
 * score files.  To use this from the command line, node.js will need to be
 * installed.  It can be downloaded from: https://nodejs.org/download/.  Once
 * installed, the script can be executed as follows:
 *   node SATdownload.js
 *
 * Before using, make sure to modify the config options in initConfig below.
 *
 * NOTE: This script is based on the sample file provided by CollegeBoard at:
 * https://collegereadiness.collegeboard.org/zip/pascoredwnld-javascript-sample.zip
 * The sample was accessed 2015-09-25.
 *
 * Additional documentation on the functions provided by CollegeBoard may be
 * found at:
 * https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features
 *
 * Exit Codes:
 *   0 - Success
 *   1 - Unknown option
 *   2 - Invalid file number provided
 *   3 - Error reading the counter file
 *
 * Author: Brian Moon (bmoon@scu.edu)
 * Date: 2015-10-09
 * Copyright: Santa Clara University
 *
 * Change Log:
 * 2015-10-30 - Modified calls to downloadFile() to use only the file name and
 *              not the file path. Changed exit code to be 0 when a file was
 *              successfully downloaded.
 * 2015-11-06 - Created the counter file to keep track of the last control
 *              number successfully downloaded.  Also added command line
 *              options to specify the control number (--filenum) or file name
 *              (--filename).
 */
"use strict";

/*****************************************************************************
 **************************** MODIFY THIS SECTION ****************************
 *****************************************************************************/
var initConfig = {
  scoredwnldHost: 'scoresdownload.collegeboard.org',
  scoredwnldPort: '443',
  localFilePath: 'C:/SAT/inbound/',
  fileExtension: 'txt',
  counterFile: 'C:/SAT/scripts/SATdownload.counter',
  username:'Your_User_Name',
  password:'Your_Password',
  orgID: 'Your_Org_ID',
  sysOrgID: 'Your_System_Org_ID', // This was only needed when the full path to the file was used
  downloadConsecutiveFiles: true,
  writeCounterFile: true,
  fileNumPadding: 6
};

/*****************************************************************************
 ******************************* DO NOT MODIFY *******************************
 *****************************************************************************/
var https = require('https'),
  fs = require('fs');


/**
 * This function will get a token and download link for the for the file.  No
 * modifications were made other than the log statements.
 *
 * Original code can be found at:
 * https://collegereadiness.collegeboard.org/zip/pascoredwnld-javascript-sample.zip
 *
 * @param config    initConfig object
 * @param filePath    Full path of file to download
 * @param callback    Function to call once the token has been received
 * @return void
 */
var downloadFile = function(config, filePath, callback) {
  log("Getting download link for " + filePath);
  var postData = {"username":config.username,"password":config.password};
  var options = {
    hostname: config.scoredwnldHost,
    port: config.scoredwnldPort,
    path: '/pascoredwnld/file?filename='+filePath,
    method: 'POST',
    rejectUnauthorized: false,
    requestCert: true,
    agent: false,
    json:true,
    headers: {
      'Content-Type': 'application/json',
      'Accept':'application/json'
    }
  };

  var request = https.request(options,
    function(response) {
      var body = "";
      if (response.statusCode === 200) {
        response.setEncoding('utf8');
        response.on('data', function (data) {
          body = body + data;
        });
        response.on('end', function() {
          log('getDownloadFileLink succeeded: ' + body);
          var jsonObj = JSON.parse(body);
          callback(jsonObj.fileUrl, jsonObj.filePath, config.localFilePath);
        });
      }
      else {
        log('getDownloadFileLink failed: ' + response.statusCode);
        if(fileNum>1) process.exit(0);
        else process.exit(1);
      }
      // Add timeout.
      request.setTimeout(12000, function () {
        log('getRecentDownloadLinks time out');
        request.abort();
      });
    });

  request.write(JSON.stringify(postData));
  request.end();
};


/**
 * This function will download a file based on the URL obtained in
 * downloadFile().  After the file has been downloaded, if
 * initConfig.downloadConsecutiveFiles is set to 'true', then downloadFile()
 * will be called to download the next file from the same date.
 *
 * Modifications to this function:
 *   1. Log statements
 *   2. Functionality to try to download the next file if successful
 *
 * Original code can be found at:
 * https://collegereadiness.collegeboard.org/zip/pascoredwnld-javascript-sample.zip
 *
 * @param url        Download URL
 * @param filePath    Full path of file to download
 * @param localFilePath    Directory to download the file to
 * @return void
 */
var download = function(url, filePath, localFilePath) {
  var request = https.get(url, function (response) {
    if (response.statusCode === 200) {
      var fileName = null; //response.headers['content-disposition'].split('filename=')[1];
      if (!fileName) {
        fileName = filePath.substring(filePath.lastIndexOf("/") + 1);
      }
      var file = fs.createWriteStream(localFilePath+fileName);
      response.pipe(file);
      file.on('finish', function () {
        file.close();
      });
      log('File Downloaded: ' + localFilePath+fileName);

      // Launch next download
      if(initConfig.downloadConsecutiveFiles) {
        if (initConfig.writeCounterFile) fs.writeFileSync(initConfig.counterFile, fileNum, 'utf8');
        fileName = initConfig.orgID + '_' + new Date(date).toFormattedDateString() + '_' + pad(++fileNum, initConfig.fileNumPadding) + '.' + initConfig.fileExtension;
        //filePath = '/assessments/reporting/' + initConfig.sysOrgID + '/HED/SAT/ESR/' + fileName;
        downloadFile(initConfig, fileName, download);
      }
    } else {
      log("download: Download of " + filePath + " failed with status code " + response.statusCode);
    }
    request.setTimeout(30000, function () {
      log('download time out');
      request.abort();
    });
  });
  request.end();
};


/**
 * Format the date as YYYYMMDD
 *
 * @param void
 * @return Formatted Date String
 */
Date.prototype.toFormattedDateString = function() {
  // Get Year as YYYY
  var year = this.getFullYear();

  // Get and format Month as MM
  var month = this.getMonth() + 1;
  if(month < 10) {
    month = "0" + month;
  }

  // Get and format Day as DD
  var day = this.getDate();
  if(day < 10) {
    day = "0" + day;
  }

  // Return the formatted date string
  return '' + year + month + day;
}


/**
 * Format the date as YYYY-MM-DD HH:MM:SS
 *
 * @param void
 * @return Formatted Date String
 */
Date.prototype.toFormattedDateTimeString = function() {
  // Get Year as YYYY
  var year = this.getFullYear();

  // Get and format Month as MM
  var month = this.getMonth() + 1;
  if(month < 10) {
    month = "0" + month;
  }

  // Get and format Day as DD
  var day = this.getDate();
  if(day < 10) {
    day = "0" + day;
  }

  // Get and format Hour as HH
  var hour = this.getHours();
  if(hour < 10) {
    hour = "0" + hour;
  }

  // Get and format Minute as MM
  var minute = this.getMinutes();
  if(minute < 10) {
    minute = "0" + minute;
  }

  // Get and format Seconds as SS
  var seconds = this.getSeconds();
  if(seconds < 10) {
    seconds = "0" + seconds;
  }

  // Return formatted Date/Time string
  return year + "-" + month + "-" + day + " " + hour + ":" + minute + ":" + seconds;
}


/**
 * Send time-stamped log message to the console
 *
 * @param msg    String to be printed
 * @return void
 */
function log(msg) {
  console.log(new Date().toFormattedDateTimeString() + "\t" + msg);
}


/**
 * Print help information
 *
 * @param void
 * @return void
 */
function printHelp() {
  console.log("Usage: node SATdownload.js [--date=DATE | --filenum=NUM | --filename=FILENAME]\n");
  console.log("Options:");
  console.log(" --date=DATE");
  console.log("   Specify date of file to download.  Default is today's date.");
  console.log("   Recommended format is YYYY/MM/DD.  For other valid date strings,");
  console.log("   please refer to http://www.w3schools.com/jsref/jsref_obj_date.asp\n");
  console.log(" --filenum=NUM");
  console.log("   Specify the job number to start searching from.  This is the last");
  console.log("   part of the file name.  Default is the next number in the counter");
  console.log("   file.\n");
  console.log(" --filename=FILENAME");
  console.log("   Specify the exact file name to download.\n");
  console.log(" -h | --help");
  console.log("   Display this help information.");
}


/**
 * Pad number with zeroes to get the correct number of digits
 *
 * @param str    String to pad
 * @param len    Number of digits in padded string
 * @return    Padded string
 */
function pad(str, len) {
  str = "" + str;
  while(str.length < len) {
    str = "0" + str;
  }
  return str;
}

/*************
 * Main Body *
 ************/
// Print License Information
console.log("SATdownload.js  Copyright (C) 2015  Santa Clara University");
console.log("This program comes with ABSOLUTELY NO WARRANTY.  This is free software, and you");
console.log("are welcome to redistribute it under certain conditions.  For those conditions,");
console.log("please refer to the License section in the header of this file.\n");

// Initialize Starting File ID
var fileNum = -1;

// Initialize File Name
var fileName = "";

// Get today's date
var date = new Date().toString();

// Check for date parameter
if(process.argv.length > 2) {
  for(var i = 2; i < process.argv.length; ++i) {
    // Check for date parameter
    if(process.argv[i].indexOf("--date=") == 0) {
      date = process.argv[i].slice(7);
    // Check for filenum parameter
    } else if(process.argv[i].indexOf("--filenum=") == 0) {
      fileNum = process.argv[i].slice(10);
      initConfig.writeCounterFile = false;
      if(fileNum < 0) {
        console.log("File number must be equal to or greater than 0.");
        process.exit(2);
      }
    // Check for filename parameter
    } else if(process.argv[i].indexOf("--filename=") == 0) {
      fileName = process.argv[i].slice(11);
      initConfig.downloadConsecutiveFiles = false;
      initConfig.writeCounterFile = false;
    // Check for help parameter
    } else if(process.argv[i] == "--help" || process.argv[i] == "-h") {
      printHelp();
      process.exit(0);
    // Capture unknown parameters
    } else {
      console.log("Unknown option: " + process.argv[i]);
      printHelp();
      process.exit(1);
    }
  }
}

// Set File Number
if(fileNum < 0) {
  try {
    fileNum = fs.readFileSync(initConfig.counterFile,'utf8');
    ++fileNum;
  } catch(err) {
    if(err.errno == -4058) fileNum = 1;
    else {
      log(err);
      process.exit(3);
    }
  }
}

// Set File Name and Path
if(fileName == "")
  fileName = initConfig.orgID + '_' + new Date(date).toFormattedDateString() + '_' + pad(fileNum, initConfig.fileNumPadding) + '.' + initConfig.fileExtension;
//var filePath = '/assessments/reporting/' + initConfig.sysOrgID + '/HED/SAT/ESR/' + fileName;

// Download file(s) using downloadFile
downloadFile(initConfig, fileName, download);