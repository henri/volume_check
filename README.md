# Volume & Partition Check #

<h1><img src="http://discussions.apple.com/servlet/JiveServlet/showImage/2-18359334-115214/images.jpeg" valign="middle"/></h1>

About
--------

This is an open source (GPL v3 or later) wrapper script to 'diskutil' which is designed to make checking DAS (directly attached storage) as simple as possible.

License: [GNU GPL 3.0 License][1]


Requirements
---------
 - Mac OS X 10.6 or later (may work with earlier versions of OS X). Mac OS X 10.7 or later is reccomened.
 - Directly Attached Stroage


Usage Instructions
---------

 - Write detailed summary to specified log file '/path/to/volume_check.rb /path/to/logfile.log'
  1. Run the volume_check.rb script and pass in the path to a log file as the first argment. Note, this log file may be overwritten so make sure there is nothing important inside.
  2. Check the error return code. If it is not 0 then there is a problem with one or more of the checked volumes. Open the log file to see additional details.

 - Verbose logging (no log file) results written to standard output in realtime '/path/to/volume_check.rb --verbose'
  1. Run the volume_check.rb script and pass the '--verbose' argument.
  2. Check the error return code. If it is not 0 then there is a problem with one or more of the checked volumes. Check the output of the command for additional details.

 - Skip the boot volume '/path/to/volume_check.rb --skipbootvolume /path/to/logfile.log' / '/path/to/volume_check.rb --skipbootvolume --verbose'
  1. Run the volume_check.rb script and pass the '--skipbootvolume' as the first or second argument. This is useful as checking the boot volume can considerably slow down a system during the verification process.
  2. Check the error return code. If it is not 0 then there is a problem with one or more of the checked volumes. Open the log file or check the output to see additional details. 
  
Helpful Links 
---------
 - The [LBackup Monitoring Storage Systems][2] page provides you with a simple example script which uses sendEmail to send out notifications relating to issues with the file systmems detected by volume_check.rb.

 - [Download a very basic GUI][3] wrapper for checking volumes without the need of resorting to the terminal. 


Notes relating to using the core script within another system
---------

Should you wish to use this script in another system it is important that you adhear to the licence agreement.


  [1]: http://www.gnu.org/copyleft/gpl.html
  [2]: http://www.lbackup.org/monitoring_backup_storage
  [3]: http://www.lucid.technology/download/volume-check-app

