#C:\Ruby31-x64\bin ruby

require 'net/http'
require 'optparse'
require 'colorize'
require "net/https"
require 'uri'
require 'socksify/http'
require 'nokogiri'
require 'watir'


def send_notification(dir, sub)
  url = URI.parse("https://api.pushover.net/1/messages.json")
  req = Net::HTTP::Post.new(url.path)
  req.set_form_data({
    :token => "...",
    :user => "...",
    :message => "ecce Finished! \n#{dir} Directories Found. \n#{sub} Active Subdomains Found.",
    #:message => "#{u}/#{word}",
  })
  res = Net::HTTP.new(url.host, url.port)
  res.use_ssl = true
  res.verify_mode = OpenSSL::SSL::VERIFY_PEER
  res.start {|http| http.request(req) }
end

def get_links(browser, file_path)
  links = []
  
  browser.goto(file_path)      
  
  links = browser.links.map { |link| link.href }    

  return links.uniq
end

def get_prints(browser, url, file_path, verbose)  

  puts "->  #{url}".light_green if verbose

  # Check if the file already exists
  unless File.exist?(file_path)
    FileUtils.mkdir_p(File.dirname(file_path))
    browser.goto(url)       
    sleep 5    
    browser.screenshot.save file_path    
  end   
end


def extract_emails(browser, data, type, uri)
  emails = []  
  begin
    data.each do |item|
      # Determine the URL based on the type
      url = type == :directories ? "#{uri}/#{item}" : "http://#{item}"
      browser.goto(url)
  
      # Get all text-containing elements
      elements = browser.elements(:xpath => "//*[text()]")
      
  
      # Extract email addresses from the text of each element
      elements.each do |element|
        text = element.text
        
        # Use regex to find email addresses and add them to the list
        emails.concat(text.scan(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/))
      end
    end
    # Remove duplicates and flatten the list (although `concat` already flattens it)
    emails.uniq!
  rescue => e
    # Log the error message
    puts "An error occurred: #{e.message}"
  end   
end


# subdomain enumeration in progress
def enumerate_subdomains(stripped_url, threads, verbose)
  
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
  Dir.mkdir(File.join(stripped_url, "sub")) unless File.exist?(File.join(stripped_url, "sub"))
  
  # 2 - Checking if the domains are accessible + Adding threads
  # ----------------------------------------------------------------
  active_subdomains = []    

  # Grabbing the prints name to save time
  active_subdomains = Dir["#{stripped_url}/sub/*.png"].map { |path| File.basename(path, '.png') }
  puts "->  #{active_subdomains.join("\n->  ")} ".red
  
  lines_per_thread = (subdomains.size / threads.to_f).ceil
  threads_lines = subdomains.each_slice(lines_per_thread).to_a
  threads = []

  threads_lines.each do |lines|    
    thread = Thread.new do
      lines.each do |subdomain|
        begin
          next if active_subdomains.include?("#{subdomain}")
          response = Net::HTTP.get_response(URI("http://#{subdomain}"))
          puts "->  #{subdomain}" if verbose
          if response.code == "200" or response.code.start_with?("3")
            active_subdomains << subdomain        
            puts "->  #{active_subdomains[-1]}".light_green
          end
        rescue Exception => e
          # puts e
        end
      end
    end 
    
    # add the thread to the array
    threads << thread
  end  

  # wait for all threads to complete
  threads.each(&:join)  
 
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

  # Grabbing the prints name to save time
  directories = Dir["#{stripped_url}/dir/*.png"].map { |path| File.basename(path, '.png') }
  puts "->  #{directories.join("\n->  ")} ".red

  # create an array of threads
  threads = []

  # loop through each set of lines
  threads_lines.each do |lines|
    # create a new thread
    thread = Thread.new do
      begin 
        # counter to the pausable requests
        counter = 0        
        
        # loop through each line in the set
        lines.each do |line|
          # send a request to the URL with the word as a directory
          word = line.strip          

          next if directories.include?("#{word}")
          
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
          if response.code == '200' or response.code.start_with?("3")
            directories << word
            
            puts "->  #{word} ".light_green        
              
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

  opts.on("-d", "--directories", "Enumerate directories based on a Wordlist") do |dir|
    options[:dir] = dir
  end

  opts.on("-s", "--subdomains", "Enumerate subdomains") do |subdomains|
    options[:subdomains] = subdomains
  end

  opts.on("-p", "--print", "Take Screenshots") do |p|
    options[:prints] = p
  end

  opts.on("-l", "--links", "Grab the Links") do |links|
    options[:links] = links
  end

  opts.on("-e", "--emails", "Extract Emails") do |emails|
    options[:emails] = emails
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
else
  #response = Net::HTTP.get_response(URI("#{options[:url]}"))  
  
  uri = URI(options[:url])

  # Create a new Net::HTTP instance
  http = Net::HTTP.new(uri.host, uri.port)

  # Enable SSL/TLS if URI scheme is HTTPS
  if uri.scheme == 'https'
    http.use_ssl = true
    
    # Disable SSL certificate verification
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  begin
    # Make an HTTP GET request to the URI
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    puts "Checking URL ... OK\n".light_green   

  rescue Exception => e
    puts e
    puts ""
    #puts "Checking URL ... OFF\nVerify the connectivity before.\n".red  
    exit               
  end
end


# use the default wordlist if none is specified
if !options[:wordlist]
  options[:wordlist] = "teste2.txt"
end

# use the default number of threads if none is specified
if !options[:threads]
  options[:threads] = 20
end

if /^(http|https|www)/i.match?(options[:url]) 
  stripped_url = options[:url].gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")
end

# Watir browser to take screenshots 
Dir.mkdir(stripped_url) unless File.exist?(stripped_url) 
Dir.mkdir(File.join(stripped_url, "dir")) unless File.exist?(File.join(stripped_url, "dir"))
browser = Watir::Browser.new :firefox, headless: true

# start the timer
start_time = Time.now

if options[:dir]
  # CALL THE Dir enum METHOD 
  puts "Directories at #{options[:url]}:"
  directories = enumerate_directories(options[:url], options[:wordlist], options[:threads], options[:verbose], options[:stealth])
  # puts directories
  
end

# if the subdomains flag is set, enumerate the subdomains
if options[:subdomains]
  if /^(http|https|www)/i.match?(options[:url])  
    stripped_url = options[:url].gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")      
  else
    stripped_url = options[:url]  
  end
  
  puts "\nSubdomains at #{stripped_url}:"
  subdomains, active_subdomains = enumerate_subdomains(stripped_url, options[:threads], options[:verbose])  
      
end


if options[:links]
  links_total = []

  urls_to_process = []
  urls_to_process << "#{options[:url]}/#{dir}" if options[:dir]
  urls_to_process += directories.map { |dir| "#{options[:url]}/#{dir}" } if options[:dir]
  urls_to_process += active_subdomains.map { |sub| "http://#{sub}" } if options[:subdomains]
  urls_to_process << "#{options[:url]}/" if !options[:dir] && !options[:subdomains]

  urls_to_process.each do |url|
    links_total += get_links(browser, url)
  end
end


if options[:emails]
  emails = []
  if options[:dir]
    emails += extract_emails(browser, directories, :directories, options[:url])  
  end
  if options[:subdomains]
    emails += extract_emails(browser, active_subdomains, :subdomains, options[:url])    
  end
  if !options[:dir] && !options[:subdomains]
    emails += extract_emails(browser, [""], :directories, options[:url])
  end
end

# Take Screenshots
if options[:prints]
  puts "\nTaking Screenshots of #{stripped_url}:"
  if options[:dir]
    directories.each do |dir|
      get_prints(browser, "#{options[:url]}/#{dir}", "#{stripped_url}/dir/#{dir}.png", options[:verbose])
    end
  end
  if options[:subdomains]
    active_subdomains.each do |sub|
      get_prints(browser, "http://#{sub}", "#{stripped_url}/sub/#{sub}.png", options[:verbose])
    end
  end
  if !options[:dir] && !options[:subdomains]
    get_prints(browser, "#{options[:url]}/", "#{stripped_url}/dir/#{stripped_url}.png", options[:verbose])
  end
end

# close watir browser
browser.close

# Notification via Pushover 
if options[:notification]
  send_notification(directories.size, active_subdomains.size)
end

# Save the output
if !options[:output] # other option > "options[:output].nil?"
  if options[:dir]
    puts "\nDirectories Found:".colorize(:light_green) +"\n  #{directories.join("\n  ")}"
  end

  if options[:subdomains]
    puts "Subdomains found:".colorize(:light_green) +"\n  #{subdomains.join("\n  ")}"
    puts "Active subdomains:".colorize(:light_green)  +"\n  #{active_subdomains.join("\n  ")}"       
  end

  if options[:links]
    puts "Links captured:".colorize(:light_green) + "\n #{links_total.uniq.sort_by(&:length).join("\n  ")}"
  end 

  if options[:emails]
    puts "Emails captured:".colorize(:light_green) + "\n  #{emails.uniq.sort_by(&:length).join("\n  ")}"
  end
  
  puts "\n"
  # stop the timer
  end_time = Time.now
  elapsed_time = end_time - start_time

else
  begin
    File.open(options[:output], 'w') do |file|
      file.puts "Directories found:"
      directories.each {|dir| file.puts "  #{dir}"}
      file.puts "Subdomains found:"
      subdomains.each {|subdomain| file.puts "  #{subdomain}"}
      file.puts "Active subdomains:"
      active_subdomains.each {|active| file.puts "  #{active}"}
      file.puts "Links captured:"    
      links_total.sort_by(&:size).each { |link| file.puts "  #{link}" }
      file.puts "Emails captured:"    
      emails.sort_by(&:size).each { |email| file.puts "  #{email}" }
    end    
  rescue StandardError
    # puts 'The subdomain enum is not set'
  end
  puts "\nResults written to #{options[:output]}"
end

if elapsed_time > 60
  elapsed_time = elapsed_time / 60
  puts "\nElapsed time: #{elapsed_time} minutes"
else 
  puts "\nElapsed time: #{elapsed_time} seconds"
end
