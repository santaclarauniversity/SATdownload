SATdownload
Copyright (C) 2017 Santa Clara University
For licensing information, please refer to the licenses in the license folder.

This script was developed to give organizations a way to download SAT score
files from CollegeBoard's PAScoresDwnld web service.  Specifically, the tools
contained in here are for those organizations who do not have a way to consume
the notification email to trigger a download event of the new file.

Contained in here is the PowerShell implementation of this tool.  When running
this script there needs to be a configuration file present that at the very
least sets the username, password, orgID, and localFilePath.  For more
information, please refer either to the documentation within the script or to
the help information.