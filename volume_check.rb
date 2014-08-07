#!/usr/bin/env ruby

# Check DAS Volumes and Disks
# Copyright Henri Shustak 2014

# Versions
# 1.0 initial release
# 1.1 resolved path issue related to diskutil (work around)
# 1.2 bug fixes + added a verbose option which means that no log will be wrtitten and instead progress is displayed.

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

# Initial checks
if ARGV.length != 1
	puts "Usage Example (1) : ./volume_check.rb /path/to/volume_check.log"
  puts "                    # Note that this output file may be overwirtten if it exists."
  puts ""
  puts "Usage Exmaple (2) : ./volume_check.rb --verbose"
  puts "                    # Note this will result in progress being displayed on standard error / standard out."
  puts "                    # in addition, use of the --verbose option will mean that logging to a file will not take place."
  puts ""
	exit -1
end

# Check if verbose mode is enabled (pretty crappy implimentation, patches welcomed)
if @log_file_output_path.to_s == "--verbose" 
  @verbose_mode_enabled = true
  @log_file_output_path = "/dev/null"
end

# Ensure that "/usr/sbin/" is part of the search path - for some reason diskutil is still not found. Added an absolute path.
ENV["PATH"] = `echo $PATH:/usr/sbin/`

# Check attached volumes which are disks
volumes_to_check = `df -l | grep /dev/disk | awk -F "%    " '{print $2}'`.split("\n")
disks_to_check = `#{@diskutil_absolute_path} list | grep ^/dev/`

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
	`#{@diskutil_absolute_path} info #{d.chomp} | grep "Content (IOContent):      GUID_partition_scheme" 2> /dev/null`
	if $? == 0
        	check_disk(d.chomp)
        	@disk_check_id += 1
	end
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

# Check for errors
if @volume_or_disk_error_detected
	# generate and populate a temporary log file
  if @verbose_mode_enabled == false
  	temporary_log_file = `mktemp /tmp/volume_check.XXXXXXXXXXXXX`.chomp
  	`/bin/echo -n "Disk Check Report Generated : " >> "#{temporary_log_file}" ; date >> "#{temporary_log_file}" ; echo "" >> "#{temporary_log_file}"`
  	dump_data_to_log(temporary_log_file)
  	`mv "#{temporary_log_file}" "#{@log_file_output_path}"`
  else
    puts ""
    puts "--------------------------------------------------------"
    puts ""
    puts " ERRORS DETECTED WITH ONE OR MORE DRIVE(S) / VOLUME(S)!"
    puts ""
    puts "--------------------------------------------------------"
    puts ""
  end
	exit 1
end

exit 0


