#C:\Ruby31-x64\bin ruby

# require the net/http library and the optparse library
require 'net/http'
require 'optparse'
require 'colorize'
require "net/https"
require 'uri'
require 'socksify/http'
require 'nokogiri'
require 'watir'


def send_notification(n)
  url = URI.parse("https://api.pushover.net/1/messages.json")
  req = Net::HTTP::Post.new(url.path)
  req.set_form_data({
    :token => "...",
    :user => "...",
    :message => "ecce Finished! #{n} Directories Found.",
    #:message => "#{u}/#{word}",
  })
  res = Net::HTTP.new(url.host, url.port)
  res.use_ssl = true
  res.verify_mode = OpenSSL::SSL::VERIFY_PEER
  res.start {|http| http.request(req) }
end


# subdomain enumeration in progress
def enumerate_subdomains(stripped_url)
  
  # 1 - Getting subdomains from crt.sh
  url = "https://crt.sh/?q=#{stripped_url}"
  response = Net::HTTP.get(URI(url))
  html_doc = Nokogiri::HTML(response)

  subdomains = []
  html_doc.css('td').each do |td|
    subdomains += td.text.scan(/[a-z0-9]+\.#{Regexp.escape(stripped_url)}/)
  end

  subdomains = subdomains.uniq

  # Screenshots of the valid subdomains
  Dir.mkdir(File.join(stripped_url, "sub")) unless File.exists?(File.join(stripped_url, "sub"))
  browser = Watir::Browser.new :firefox, headless: true

  # 2 - Checking if the domains are accessible
  active_subdomains = []

  subdomains.each do |subdomain|
    begin
      response = Net::HTTP.get_response(URI("http://#{subdomain}"))
      if response.code == "200" or response.code.start_with?("3")
        active_subdomains << subdomain

        browser.goto("http://#{subdomain}")     
        browser.screenshot.save "#{stripped_url}/sub/#{subdomain}.png"
      end
    rescue StandardError
      # if subdomain not exists or dns can't be resolved
    end
  end  
  browser.close
  return subdomains,active_subdomains
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

  if /^(http|https|www)/i.match?(url)  
    stripped_url = url.gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")
  end

  # Watir browser to take screenshots 
  Dir.mkdir(stripped_url) unless File.exists?(stripped_url) 
  Dir.mkdir(File.join(stripped_url, "dir")) unless File.exists?(File.join(stripped_url, "dir"))
  #browser = Watir::Browser.new :firefox, headless: false

  # create an array of threads
  threads = []

  # loop through each set of lines
  threads_lines.each do |lines|
    # create a new thread
    thread = Thread.new do

      begin 

        # counter to the pausable requests
        counter = 0

        # watir browser
        browser = Watir::Browser.new :firefox, headless: true

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
            
            # take screenshots using Watir            
            browser.goto("#{uri}")  
            browser.screenshot.save "#{stripped_url}/dir/#{word}.png"                                   

          elsif response.code == '301'
            response = Net::HTTP.follow_redirection(response)   
            puts "R ->  #{word} ".light_blue                
          end          
          
        end
        browser.close
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
  options[:wordlist] = "teste2.txt"
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


# if the subdomains flag is set, enumerate the subdomains
if options[:subdomains]
  if /^(http|https|www)/i.match?(options[:url])  
    stripped_url = options[:url].gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")      
  else
    stripped_url = options[:url]  
  end
  
  subdomains, active_subdomains = enumerate_subdomains(stripped_url)
  
  #puts "\nSubdomains at #{stripped_url}:"     
end


# Save the output
if options[:output].nil?
  puts "\nDirectories Found:".colorize(:light_green) +"\n  #{directories.join("\n  ")}"

  if options[:subdomains]
    puts "Subdomains found:".colorize(:light_green) +"\n  #{subdomains.join("\n  ")}"
    puts "Active subdomains:".colorize(:light_green)  +"\n  #{active_subdomains.join("\n  ")}" 

  end
  puts "\n"
else
  begin
    File.open(options[:output], 'w') do |file|
      file.puts "Directories found:"
      directories.each {|dir| file.puts "  #{dir}"}
      file.puts "Subdomains found:"
      subdomains.each {|subdomain| file.puts "  #{subdomain}"}
      file.puts "Active subdomains:"
      active_subdomains.each {|active| file.puts "  #{active}"}
    end    
  rescue StandardError
    # puts 'The subdomain enum is not set'
  end
  puts "\nResults written to #{options[:output]}"
end



