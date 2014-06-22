#!/usr/bin/env ruby

# Check DAS Volumes and Disks
# Copyright Henri Shustak 2014

# Version 1.0 initial release

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

# Initial checks
if ARGV.length != 1
	puts "Usage : ./volume_check.rb /path/to/volume_check.log  #note that this output file may be overwirtten if it exists."
	exit -1
end

# Ensure that "/usr/sbin/" is part of the search path
ENV["PATH"] = `echo $PATH:/usr/sbin/`

# Check attached volumes which are disks
volumes_to_check = `df -l | grep /dev/disk | awk -F "%    " '{print $2}'`.split("\n")
disks_to_check = `diskutil list | grep ^/dev/`

def check_volume (volume2check)
	#puts "Checking Volume : #{volume2check}"
	@volume_check_name[@volume_check_id] = volume2check.to_s
	@volume_check_device_name[@volume_check_id] = `df "#{volume2check.to_s}" | tail -n 1 | awk '{print $1}' 2> /dev/null`.chomp
	verify_volume_result = `diskutil verifyVolume "#{volume2check.to_s}" 2>&1`
	@volume_check_return_codes[@volume_check_id] = $?.exitstatus
	@volume_check_return_results[@volume_check_id] = verify_volume_result
	@volume_or_disk_error_detected = true if @volume_check_return_codes[@volume_check_id] != 0
end

def check_disk (disk2check)
    #puts "Checking Disk : #{disk2check.to_s}"
	@disk_check_name[@disk_check_id] = disk2check.to_s
    verify_disk_result = `diskutil verifyDisk "#{disk2check.to_s}" 2>&1`
	@disk_check_return_codes[@disk_check_id] = $?.exitstatus
	@disk_check_return_results[@disk_check_id] = verify_disk_result
	@volume_or_disk_error_detected = true if @disk_check_return_codes[@disk_check_id] != 0
end

volumes_to_check.each { |v|
	check_volume(v)
	@volume_check_id += 1
}

disks_to_check.each { |d|
	# only checks this disk if the disk features a GUID parition map
	`diskutil info #{d.chomp} | grep "Content (IOContent):      GUID_partition_scheme" 2> /dev/null`
	if $? == 0
        	check_disk(d.chomp)
        	@disk_check_id += 1
	end
}


def dump_data_to_log (log_file)
	@disk_check_id = 0
	@disk_check_return_codes.each { |d|
		`echo "Verification Return Status : #{@disk_check_return_codes[@disk_check_id].to_s}\tDisk Device Name : #{@disk_check_name[@disk_check_id].to_s}" >> "#{log_file}"`
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
	temporary_log_file = `mktemp /tmp/volume_check.XXXXXXXXXXXXX`.chomp
	`/bin/echo -n "Disk Check Report Generated : " >> "#{temporary_log_file}" ; date >> "#{temporary_log_file}" ; echo "" >> "#{temporary_log_file}"`
	dump_data_to_log(temporary_log_file)
	`mv "#{temporary_log_file}" "#{@log_file_output_path}"`
	exit 1
end

exit 0


