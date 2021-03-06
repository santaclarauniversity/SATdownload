SATdownload
Copyright (C) 2015 Santa Clara University
For licensing information, please refer to the licenses in the license folder.

This package was developed to give organizations two options to download SAT
score files from CollegeBoard's PAScoresDwnld web service.  Specifically, the
tools contained in here are for those organizations who do not have a way to
consume the notification email to trigger a download event of the new file.

Contained in here are two implementations that can be executed from the command
line.  The first is SATdownload.js (located in the JavaScript directory).  This
script requires node.js to be installed on your system.  Please refer to the
documentation in that file for instructions on how to configure it and then for
how to run it.

The second implementation is SATdownload.jar (located in the bin directory).
This is a runnable JAR file with all of the required Apache Maven libraries
bundled in.  This JAR file relies on the options set inside the
config.properties file (a sample is also in the bin directory).  To aid in the
execution of this JAR file, sample shell and PowerShell scripts are in the bin
directory.  This project was build using Java SE 8, but should be compatible
with any Java SE 5 or later JVM.

Finally, this directory itself is an Eclipse Project using the M2Eclipse plugin
(https://eclipse.org/m2e/).  If you wish to make any changes to it, you are
welcome to do so.  JavaDoc is available in the doc directory. 