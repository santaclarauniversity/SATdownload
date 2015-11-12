#SATdownload
Copyright (C) 2015 Santa Clara University<br>For licensing information, please refer to the licenses in the license folder.

This package was developed to give organizations two options to download SAT score files from [CollegeBoard's PAScoresDwnld web service](https://collegereadiness.collegeboard.org/educators/higher-ed/reporting-portal-help#features).  Specifically, the tools contained in here are for those organizations who do not have a way to consume the notification email to trigger a download event of the new file.

Contained in here are two implementations that can be executed from the command line.  The first is SATdownload.js (located in the [SATdownload (node.js)](https://github.com/santaclarauniversity/SATdownload/tree/master/SATdownload%20%28node.js%29)).  This script requires node.js to be installed on your system.  Please refer to the documentation in that file for instructions on how to configure it and then for how to run it.

The second implementation is SATdownload.jar (located in the bin directory of [SATdownload (Java)](https://github.com/santaclarauniversity/SATdownload/tree/master/SATdownload%20%28Java%29)). This is a runnable JAR file with all of the required Apache Maven libraries bundled in.  This JAR file relies on the options set inside the config.properties file (a sample is also in the bin directory).  To aid in the execution of this JAR file, sample shell and PowerShell scripts are in the bin directory.  This project was build using Java SE 8, but should be compatible with any Java SE 5 or later JVM.

Finally, these directories are Eclipse Projects.  I recommend the following plugins if you wish to do your own development:
* [M2Eclipse](https://eclipse.org/m2e/)
* [Nodeclipse](http://www.nodeclipse.org/updates/)
