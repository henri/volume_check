#!/usr/bin/env ruby

# Check DAS Volumes and Disks
# Copyright Henri Shustak 2014
#
# Licence under GNU GPL 3 or later
# http://www.gnu.org/licenses/gpl.txt

# About : 
# The name volume_check.rb is slightly misleading as it is also designed to check disk parititions,
# when supported by the operating system. This script is a wrapper for diskutil and is designed to be run on
# Mac OS X systems to check the file system integerty of partitions and also the disk parition maps of DAS systems.
# Project website : http://www.lucid.technology/tools/osx/volume-check

# Versions
# 1.0 initial release
# 1.1 resolved path issue related to diskutil (work around)
# 1.2 bug fixes + added a verbose option which means that no log will be wrtitten and instead progress is displayed.
# 1.3 added option to skip checking of the boot volume.
# 1.4 added support for Mac OS 10.6 and possibly earlier versions of Mac OS X (please report back to the project)
# 1.5 impproved support and bug fixes for Mac OS 10.7
# 1.6 impproved support and bug fixes for Mac OS 10.11
# 1.7 will now generate a report even if there are no errors detected

# Internal variables
@volume_or_disk_error_detected = false
@volume_check_id = 0
@volume_check_name = []
@volume_check_device_name = []
@volume_check_return_codes = []
@volume_check_return_results = []
@disk_check_id = 0
@disk_check_name = []
@disk_check_return_codes = []
@disk_check_return_results = []
@log_file_output_path = ARGV[0]
@diskutil_absolute_path="/usr/sbin/diskutil"
@verbose_mode_enabled = false
@skip_boot_volume_check_enabled = false
@num_arguments = ARGV.length
@system_greter_than_107 = true
@system_greter_than_106 = true
@darwin_major_version = ""

# Initial checks
if (@num_arguments == 0) || (@num_arguments == 1 && ARGV[0] == "--skipbootvolume") || (@num_arguments == 2 && ARGV[0] != "--skipbootvolume" && ARGV[0] != "--verbose") || (@num_arguments >= 3) || ( ARGV[0] == "--help" ) || ( ARGV[0] == "-h" )
  puts ""
	puts "Usage Example (1) : ./volume_check.rb /path/to/volume_check.log"
  puts "                    # Note that this output file may be overwirtten if it exists."
  puts ""
  puts "Usage Exmaple (2) : ./volume_check.rb --verbose"
  puts "                    # Note this will result in progress being displayed on standard error / standard out."
  puts "                    # in addition, use of the --verbose option will mean that logging to a file will not take place."
  puts ""
  puts "Usage Exmaple (3) : ./volume_check.rb --skipbootvolume /path/to/volume_check.log"
  puts "                    # The boot volume will not be checked. Note, that the disk upon which boot volume resides"
  puts "                    # will be checked even with this argument."
  puts ""
	exit -1
end

# Check if the system version is 10.7 or later - this changes the information formating reported by the 'df' command
@darwin_major_version = `uname -v | awk '{print $4}' | awk -F "." '{print $1}'`
if @darwin_major_version.to_i <= 11 then
  @system_greter_than_107 = false
end
if @darwin_major_version.to_i <= 10 then
  @system_greter_than_106 = false
end

# Check if verbose and skip boot volume check is enabled (pretty crappy implimentation, patches welcomed)
if ARGV[0].to_s == "--skipbootvolume" || ARGV[1].to_s == "--skipbootvolume"
  @skip_boot_volume_check_enabled = true
  @log_file_output_path = ARGV[1]
end

# Check if verbose mode is enabled (pretty crappy implimentation, patches welcomed)
if ARGV[0].to_s == "--verbose" || ARGV[1].to_s == "--verbose" 
  @verbose_mode_enabled = true
  @log_file_output_path = "/dev/null"
end

# Ensure that "/usr/sbin/" is part of the search path - for some reason diskutil is still not found. Added an absolute path.
ENV["PATH"] = `echo $PATH:/usr/sbin/`

# Check attached volumes which are disks
if @skip_boot_volume_check_enabled == true
  if @system_greter_than_107 == true then
    # running 10.7 or later
    volumes_to_check = `df -l | grep /dev/disk | awk '{ $1=$1; print }' | awk -F "% " '{print $3}' | grep -v -x "/"`.split("\n") 
  else
    # running 10.6 or earlier
    volumes_to_check = `df -l | grep /dev/disk | awk '{ $1=$1; print }' | awk -F "% " '{print $2}' | grep -v -x "/"`.split("\n")     
  end
else
  if @system_greter_than_107 == true then
    # running 10.7 or later
    volumes_to_check = `df -l | grep /dev/disk | awk '{ $1=$1; print }' | awk -F "% " '{print $3}'`.split("\n")
  else
    # running 10.6 or earlier
    volumes_to_check = `df -l | grep /dev/disk | awk '{ $1=$1; print }' | awk -F "% " '{print $2}'`.split("\n")
  end
end 
disks_to_check = `#{@diskutil_absolute_path} list | grep "^/dev/" | awk '{print $1}'`.split("\n")
# volumes_to_check = `df -l | grep /dev/disk | awk -F "%    " '{print $2}'`.split("\n")
# disks_to_check = `#{@diskutil_absolute_path} list | grep ^/dev/`

def check_volume (volume2check)
	@volume_check_name[@volume_check_id] = volume2check.to_s
	@volume_check_device_name[@volume_check_id] = `df "#{volume2check.to_s}" | tail -n 1 | awk '{print $1}' 2> /dev/null`.chomp
	if @verbose_mode_enabled == false
    verify_volume_result = `#{@diskutil_absolute_path} verifyVolume "#{volume2check.to_s}" 2>&1`
    @volume_check_return_codes[@volume_check_id] = $?.exitstatus
    @volume_check_return_results[@volume_check_id] = verify_volume_result
  else
    puts ""
    puts "-" * 72
    puts "Checking Volume : #{volume2check}"
    run_command_with_realtime_output("#{@diskutil_absolute_path} verifyVolume \"#{volume2check.to_s}\"")
    @volume_check_return_codes[@volume_check_id] = $?.exitstatus
  end
	@volume_or_disk_error_detected = true if @volume_check_return_codes[@volume_check_id] != 0
end

def check_disk (disk2check)
	@disk_check_name[@disk_check_id] = disk2check.to_s
  if @verbose_mode_enabled == false
    verify_disk_result = `#{@diskutil_absolute_path} verifyDisk "#{disk2check.to_s}" 2>&1`
    @disk_check_return_codes[@disk_check_id] = $?.exitstatus
    @disk_check_return_results[@disk_check_id] = verify_disk_result
  else
    puts ""
    puts "-" * 72
    puts "Checking Disk : #{disk2check.to_s}"
    run_command_with_realtime_output("#{@diskutil_absolute_path} verifyDisk \"#{disk2check.to_s}\"")
    @disk_check_return_codes[@disk_check_id] = $?.exitstatus
  end
	@volume_or_disk_error_detected = true if @disk_check_return_codes[@disk_check_id] != 0
end

def run_command_with_realtime_output (command)
  require 'pty'
  PTY.spawn command do |r, w, pid|
    begin
      r.sync
      r.each_line { |l| puts "#{l.strip}" }
    rescue Errno::EIO => e
      # simply ignoring any errors
    ensure
      ::Process.wait pid
    end
  end
  return 1 unless $? && $?.exitstatus == 0
  return 0
end

volumes_to_check.each { |v|
  check_volume(v)
  @volume_check_id += 1
}

disks_to_check.each { |d|
	# only checks this disk if the disk features a GUID parition map
    # if @system_greter_than_106 == true then
  	`#{@diskutil_absolute_path} info #{d.chomp} | grep "Content (IOContent):      GUID_partition_scheme" 2> /dev/null`
  	if $? == 0
          	check_disk(d.chomp)
          	@disk_check_id += 1
  	end
    #else
      # 10.6 and earlier ; commented out because verifyDisk on 10.6 and earlier reports as depreciated 
      #                    and fails to work as expected for a depreciated command.
    	# `#{@diskutil_absolute_path} info #{d.chomp} | grep "Partition Type:           GUID_partition_scheme" 2> /dev/null`
    	# if $? == 0
      #       	check_disk(d.chomp)
      #       	@disk_check_id += 1
    	# end
    #end
}


def dump_data_to_log (log_file)
	@disk_check_id = 0
	@disk_check_return_codes.each { |d|
		disk_manufacture = `#{@diskutil_absolute_path} info #{@disk_check_name[@disk_check_id].to_s} | grep "Device / Media Name:" | awk -F "Device / Media Name:      " '{print $2}'`.chomp
		disk_capacity = `#{@diskutil_absolute_path} info #{@disk_check_name[@disk_check_id].to_s} | grep "Total Size:" | awk '{print $3" "$4 }'`.chomp
		`echo "Verification Return Status : #{@disk_check_return_codes[@disk_check_id].to_s}\tDisk Device Name : #{@disk_check_name[@disk_check_id].to_s}\tDisk Information : #{disk_manufacture} #{disk_capacity}" >> "#{log_file}"`
		`echo "#{@disk_check_return_results[@disk_check_id].to_s.chomp}" | sed 's/^/	/' >> "#{log_file}"` if @disk_check_return_codes[@disk_check_id] != 0
		@disk_check_id += 1
	}
  `echo "" >> "#{log_file}"`
	@volume_check_id = 0
  @volume_check_return_codes.each { |v|
	  `echo "Verification Return Status : #{@volume_check_return_codes[@volume_check_id].to_s}\tVolume Device Name : #{@volume_check_device_name[@volume_check_id].to_s}\tVolume Name : #{@volume_check_name[@volume_check_id].to_s}" >> "#{log_file}"`
	  `echo "#{@volume_check_return_results[@volume_check_id].to_s.chomp}" | sed 's/^/	/' >> "#{log_file}"` if @volume_check_return_codes[@volume_check_id] != 0
    @volume_check_id += 1
	}
end

# generate and populate a temporary log file, then move (destructive) to the specified output logfile.
if @verbose_mode_enabled == false
  temporary_log_file = `mktemp /tmp/volume_check.XXXXXXXXXXXXX`.chomp
  `/bin/echo -n "Disk Check Report Generated : " >> "#{temporary_log_file}" ; date >> "#{temporary_log_file}" ; echo "" >> "#{temporary_log_file}"`
  dump_data_to_log(temporary_log_file)
  `mv "#{temporary_log_file}" "#{@log_file_output_path}"`
end

# Check for errors
if @volume_or_disk_error_detected
else
  puts ""
  puts "--------------------------------------------------------"
  puts ""
  puts " ERRORS DETECTED WITH ONE OR MORE DRIVE(S) / VOLUME(S)!"
  puts ""
  puts "--------------------------------------------------------"
  puts ""
  exit 1  
end

exit 0


