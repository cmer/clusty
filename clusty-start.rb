#!/usr/bin/env ruby

require 'rubygems'
require 'ostruct'
require 'json'

ONDEMAND_PRICING = {
 "m1.small"  => 0.085,
 "m1.large"  => 0.34,
 "m1.xlarge" => 0.68,
 "m2.xlarge" => 0.50,
 "m2.2xlarge"=> 1.20,
 "m2.4xlarge"=> 2.40,
 "c1.medium" => 0.17,
 "c1.xlarge" => 0.68
}

def run
  if ARGV.size != 3
    puts "Usage: clusty-start {count} {cluster name} {type}"
    puts "Example: clusty-start 2 venus web_server"
    exit 1
  end

  count = ARGV[0].to_i
  cluster = ARGV[1].to_sym
  type = ARGV[2].to_sym
  
  begin
    instance_def = INSTANCE_TYPES[cluster][type]
    raise if instance_def.nil?
  rescue
    puts "Cannot interpret instance type #{cluster}/#{type}."
    exit 1
  end
  
  if instance_def[:type].nil? || instance_def[:type] == :ondemand
    request_ids = start_ondemand_instance(instance_def, count)
  elsif instance_def[:type] == :spot
    request_ids = start_spot_instance(instance_def, count)
  else
    puts "Invalid instance type: #{instance_def[:type]}."
    exit 1
  end
  
  instances = wait_for_instances_to_start(request_ids)
  
  puts "\nYour newly launched instances:"
  instances.each do |i|
    puts "#{i[:instance_id]}\t#{i[:public_host]}\t#{i[:public_ip]}\t#{i[:zone]}"
  end
end


def start_ondemand_instance(instance_def, count)
  options = [
    "#{instance_def[:ami]}",
    "--instance-count #{count}",
    "--region #{instance_def[:region] || DEFAULT_REGION }",
    "--group #{(instance_def[:groups].map {|g| '"' + g + '"'}).join(' --group ')}",
    "--instance-type #{instance_def[:size]}",
    "--key #{instance_def[:keypair] || DEFAULT_KEYPAIR }"
  ]
  
  options << "--user-data-file #{write_user_data_to_disk(instance_def[:user_data])}" if instance_def[:user_data] 

  cmd = "#{ec2_api_tools_path}/ec2-run-instances #{options.join(" ")} 2> /dev/null"
  puts cmd if is_verbose?
  result = `#{cmd}`
  puts result if is_verbose?

  # return instance ids
  result.scan(/\bi\-[a-z0-9]*/)
end

def start_spot_instance(instance_def, count)
  default_max_bid = ONDEMAND_PRICING[instance_def[:size]]
  
  options = [
    "#{instance_def[:ami]}",
    "--instance-count #{count}",
    "--region #{instance_def[:region] || DEFAULT_REGION }",
    "--group #{(instance_def[:groups].map {|g| '"' + g + '"'}).join(' --group ')}",
    "--price #{instance_def[:max_bid] || default_max_bid}",
    "--type one-time",
    "--instance-type #{instance_def[:size]}",
    "--key #{instance_def[:keypair] || DEFAULT_KEYPAIR }"
  ]
  
  options << "--user-data-file #{write_user_data_to_disk(instance_def[:user_data])}" if instance_def[:user_data] 

  cmd = "#{ec2_api_tools_path}/ec2-request-spot-instances #{options.join(" ")} 2> /dev/null"
  puts cmd if is_verbose?
  result = `#{cmd}`
  puts result if is_verbose?

  # return request ids
  result.scan(/sir\-[a-z0-9]*/)
end

def write_user_data_to_disk(user_data)
  file = "/tmp/clusty-#{rand(100000).to_s}"
  File.open(file, "w") { |f| f.print user_data}
  file
end

def ec2_api_tools_path
  @ec2_api_tools_path ||= `which ec2-request-spot-instances`.chomp.split("/")[0..-2].join("/")
end

def wait_for_instances_to_start(request_ids)
  pause = 20
  instances = []
  
  while !request_ids.empty?
    result = `#{ec2_api_tools_path}/ec2-describe-instances 2> /dev/null`

    result.each_line do |l|
      if l.match(/^INSTANCE/) && l.match(/#{request_ids.join("|").gsub("-","\-")}/) && l.match(/\trunning\t/)
        instance = {}
      
        instance[:spot]         = (l.match(/\tspot\t/) ? true : false)
        instance[:request_id]   = (instance[:spot] ? l.match(/#{request_ids.join("|").gsub("-","\-")}/)[0] : nil)
        instance[:size]         = l.match(/[a-z][0-9]\.[a-z]*/)[0]
        instance[:ami]          = l.match(/ami\-[a-z0-9]*/)[0]
        instance[:instance_id]  = l.match(/i\-[a-z0-9]*/)[0]
        instance[:public_host]  = l.match(/[a-z0-9\-\.]*\.amazonaws\.com/)[0]
        instance[:private_host] = l.match(/[a-zA-Z0-9\-\.]*\.internal/)[0]
        instance[:zone]         = l.match(/[a-z]{2}\-[a-z]*\-[0-9][a-z]/)[0]
        instance[:public_ip]    = l.match(/[0-9]{2,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)[0]
        instance[:private_ip]   = l.match(/10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)[0]

        instances << instance
        request_ids.delete(instance[:request_id])
        request_ids.delete(instance[:instance_id])
      end
    end

    unless request_ids.empty?
      print "#{request_ids.size} instance#{request_ids.size > 1 ? "s" : ''} pending...  "
      sleep_with_spinner(pause)
    end
    200.times { print "\b" } # remove the pending line
  end
  instances
end

def sleep_with_spinner(sec)
  a = %w[ | / - \\ ]

  $stdout.sync = true
  start_time = Time.now
  loop do
    print a.unshift(a.pop).last
    sleep 0.1
    print "\b"
    break if Time.now > (start_time + sec)
  end
  print "\b"
end

def is_verbose?
  defined?(VERBOSE) && VERBOSE
end

config_filename = "config.rb"
local_config = File.dirname(__FILE__) + '/' + config_filename

if File.exist?(local_config)
  require config_filename
else
  puts "#{local_config} could not be found."
  exit 1
end

run

