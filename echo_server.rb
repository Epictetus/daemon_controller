#!/usr/bin/env ruby
require 'socket'
require 'optparse'

options = {
	:port => 3230,
	:chdir => "/",
	:log_file => "/dev/null",
	:wait1 => 0,
	:wait2 => 0
}
parser = OptionParser.new do |opts|
	opts.banner = "Usage: echo_server.rb [options]"
	opts.separator ""
	
	opts.separator "Options:"
	opts.on("-p", "--port PORT", Integer, "Port to use. Default: 3230") do |value|
		options[:port] = value
	end
	opts.on("-C", "--change-dir DIR", String, "Change working directory. Default: /") do |value|
		options[:chdir] = value
	end
	opts.on("-l", "--log-file FILENAME", String, "Log file to use. Default: /dev/null") do |value|
		options[:log_file] = value
	end
	opts.on("-P", "--pid-file FILENAME", String, "Pid file to use.") do |value|
		options[:pid_file] = File.expand_path(value)
	end
	opts.on("--wait1 SECONDS", Numeric, "Wait a few seconds before writing pid file.") do |value|
		options[:wait1] = value
	end
	opts.on("--wait2 SECONDS", Numeric, "Wait a few seconds before opening server socket.") do |value|
		options[:wait2] = value
	end
end
begin
	parser.parse!
rescue OptionParser::ParseError => e
	puts e
	puts
	puts "Please see '--help' for valid options."
	exit 1
end

if options[:pid_file]
	if File.exist?(options[:pid_file])
		STDERR.puts "*** ERROR: pid file #{options[:pid_file]} exists."
		exit 1
	end
end

pid = fork do
	Process.setsid
	fork do
		STDIN.reopen("/dev/null", 'r')
		STDOUT.reopen(options[:log_file], 'a')
		STDERR.reopen(options[:log_file], 'a')
		STDOUT.sync = true
		STDERR.sync = true
		Dir.chdir(options[:chdir])
		File.umask(0)
		if options[:pid_file]
			sleep(options[:wait1])
			File.open(options[:pid_file], 'w') do |f|
				f.write(Process.pid)
			end
			at_exit do
				File.unlink(options[:pid_file]) rescue nil
			end
		end
		sleep(options[:wait2])
		server = TCPServer.new('localhost', options[:port])
		begin
			puts "*** #{Time.now}: echo server started"
			while (client = server.accept)
				puts "#{Time.now}: new client"
				begin
					while (line = client.readline)
						puts "#{Time.now}: client sent: #{line.strip}"
						client.puts(line)
					end
				rescue EOFError
				ensure
					puts "#{Time.now}: connection closed"
					client.close rescue nil
				end
			end
		rescue SignalException
			exit 2
		rescue => e
			puts e.to_s
			puts "    " << e.backtrace.join("\n    ")
			exit 3
		ensure
			puts "*** #{Time.now}: echo server exited"
		end
	end
end
Process.waitpid(pid)
