#C:\Ruby31-x64\bin ruby

# require the net/http library and the optparse library
require 'net/http'
require 'optparse'
require 'colorize'
require "net/https"
require 'resolv'
require 'uri'
require 'socksify/http'


def send_notification(n)
  url = URI.parse("https://api.pushover.net/1/messages.json")
  req = Net::HTTP::Post.new(url.path)
  req.set_form_data({
    :token => "aszgvewecgao89j2k53py51qg9sos2",
    :user => "u8nsnx6bbn6iqbimhoafuth4pjz98e",
    :message => "ecce Finished! #{n} Directories Found.",
    #:message => "#{u}/#{word}",
  })
  res = Net::HTTP.new(url.host, url.port)
  res.use_ssl = true
  res.verify_mode = OpenSSL::SSL::VERIFY_PEER
  res.start {|http| http.request(req) }
end


# subdomain enumeration in progress
def enumerate_subdomains(url, wordlist = 'teste.txt')
  # read the wordlist into an array
  lines = File.readlines(wordlist)

  # initialize an array to store the subdomains
  subdomains = []

  host = url.match(/https?:\/\/www.([^\/]+)/)[1]
  # puts host

  # iterate over the lines in the wordlist
  lines.each do |line|
    # construct the subdomain URL
    
    subdomain_url = "http://#{line.chomp}.#{host}"
    # puts subdomain_url

    # check if the subdomain is valid
    begin
      # use the Resolv class to resolve the subdomain
      Resolv.getaddress(subdomain_url)

      # if the subdomain is valid, add it to the array
      subdomains << subdomain_url
      puts "➞  "+"#{subdomain_url} ".light_green 
    rescue Resolv::ResolvError
      # if the subdomain is not valid, do nothing
    end
  end

  # return the array of subdomains
  subdomains
end


# function for enumerating directories
def enumerate_directories(url, wordlist, threads, verbose, stealth)

  #----------------------------------------------------------------------

   # start with an empty list of directories
  directories = []

  # read the wordlist file
  lines = File.readlines(wordlist)

  # split the lines into threads
  lines_per_thread = (lines.size / threads.to_f).ceil
  threads_lines = lines.each_slice(lines_per_thread).to_a

  # create an array of threads
  threads = []

  # loop through each set of lines
  threads_lines.each do |lines|
    # create a new thread
    thread = Thread.new do

      begin 

        counter = 0

        # loop through each line in the set
        lines.each do |line|
          # send a request to the URL with the word as a directory
          word = line.strip
          uri = URI("#{url}/#{word}/")             
          
          # Stealth Mode
          if stealth

            # rotate IP through TOR 
            hakuna = Net::HTTP::SOCKSProxy('127.0.0.1', 9150)
            response = hakuna.get_response(uri)
            
            # for each 150 requests
            if counter % 150 == 0        
              # sleep for 60 seconds
              # puts 'zzz'
              sleep(60)

              #kiki = 'https://ident.me'
              #puts hakuna.get(URI(kiki)) 
            end       
          else 
            response = Net::HTTP.get_response(uri)         
          end
          
          # add a counter after the request
          counter += 1

          # Verbose mode prints every word of the wordlist
          puts "->  #{word}" if verbose                               

          # if the response is a 200 OK, add the word to the list of directories
          if response.code == '200'
            directories << word
            
            puts "->  #{word} ".light_green                       

          elsif response.code == '301'
            response = Net::HTTP.follow_redirection(response)                  
          end          
          
        end
      rescue Exception => e
        puts e                
      end

    end

    # add the thread to the array
    threads << thread
  end

  # wait for all threads to complete
  threads.each(&:join)

  # return the list of directories
  directories 
end

puts "
_______ _______ _______ _______
|______ |       |       |______
|______ |_____  |_____  |______ ".colorize(:red)

puts "
65 63 63 65".colorize(:red)
 

puts "\n\n"
# parse the command-line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ecce.rb [options]"

  opts.on("-u URL", "--url URL", "URL to enumerate") do |url|
    options[:url] = url
  end

  opts.on("-w WORDLIST", "--wordlist WORDLIST", "Wordlist file") do |wordlist|
    options[:wordlist] = wordlist
  end

  opts.on("-t THREADS", "--threads THREADS", "Number of threads") do |threads|
    options[:threads] = threads.to_i
  end
  
  opts.on("-n", "--notification", "Send push notification via Pushover API") do |n|
    options[:notification] = n
  end

  opts.on("-s", "--subdomains", "Enumerate subdomains") do |subdomains|
    options[:subdomains] = subdomains
  end

  opts.on("-v", "--verbose", "Prints verbose output") do |v|
    options[:verbose] = v
  end

  opts.on("-x", "--stealth", "Stealth Mode uses TOR + paused requests") do |x|
    options[:stealth] = x
  end

  opts.on("-o OUTPUT", "--output OUTPUT", "Output file") do |output|
    options[:output] = output
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

# check that the required options are specified
if !options[:url]
  puts "URL is a required option: -u URL".red
  exit
end

# use the default wordlist if none is specified
if !options[:wordlist]
  options[:wordlist] = "dir2copy.txt"
end

# use the default number of threads if none is specified
if !options[:threads]
  options[:threads] = 25
end


# start the timer
start_time = Time.now

# CALL THE ENUMERATE METHOD >>>>>>>>>>>>>>>>>>>>>
puts "Directories at #{options[:url]}:"
directories = enumerate_directories(options[:url], options[:wordlist], options[:threads], options[:verbose], options[:stealth])
# puts directories

# stop the timer
end_time = Time.now
elapsed_time = end_time - start_time

if elapsed_time > 60
  elapsed_time = elapsed_time / 60
  puts "\nElapsed time: #{elapsed_time} minutes"
else 
  puts "\nElapsed time: #{elapsed_time} seconds"
end

# Notification via Pushover 
if options[:notification]
  send_notification(directories.size)
end

# Save the output
if options[:output]
    File.open(options[:output], mode: "w") do |file|
      directories.each do |dir|
        file.puts dir
      end
    end
    puts "Results written to #{options[:output]}"
  end

# if the subdomains flag is set, enumerate the subdomains
if options[:subdomains]
  subdomains = enumerate_subdomains(options[:url])
  puts "\nSubdomains at #{options[:url]}:"
  puts subdomains
  puts "Number of subdomains: #{subdomains.size}"
end
