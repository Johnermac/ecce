
# https://crt.sh/?q=pucpr.br

require 'colorize'
require 'net/http'
require 'nokogiri'
require 'optparse'
require 'watir'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: sub.rb [options]"

  opts.on("-s", "--subdomain URL", "URL to search for subdomains") do |url|
    options[:url] = url
  end

  opts.on("-o", "--output FILE", "Save Results") do |file|
    options[:output_file] = file
  end
end.parse!

if options[:url].nil?
  puts "Error: Provide [ -s  URL ]"
  exit
end


if /^(http|https|www)/i.match?(options[:url])  
  stripped_url = options[:url].gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")
  #puts url  
else
  stripped_url = options[:url]  
end

# 1 - Getting subdomains from crt.sh

url = "https://crt.sh/?q=#{stripped_url}"
response = Net::HTTP.get(URI(url))
html_doc = Nokogiri::HTML(response)

subdomains = []
html_doc.css('td').each do |td|
  subdomains += td.text.scan(/[a-z0-9]+\.#{Regexp.escape(stripped_url)}/)
end

subdomains = subdomains.uniq

# 2 - Checking if the domains are accessible
active_subdomains = []

def get_links(browser, subdomain)
  browser.goto("http://#{subdomain}")       
  
  links = browser.links.map { |link| link.href }
  links = links.uniq 
  return links
end

def get_prints(browser, subdomain, stripped_url) 
  browser.goto("http://#{subdomain}")      
  browser.screenshot.save "#{stripped_url}/#{subdomain}.png"  
end

links_total = []

# Create the folder and open the browser to get the prints and links
Dir.mkdir(stripped_url) unless File.exists?(stripped_url) 
browser = Watir::Browser.new :firefox, headless: true

subdomains.each do |subdomain|  
  begin
    response = Net::HTTP.get_response(URI("http://#{subdomain}"))
    if response.code == "200" or response.code.start_with?("3")
      active_subdomains << subdomain      
      
      links = get_links(browser, subdomain)
      links_total.concat(links) 
      start_time = Time.now
      get_prints(browser, subdomain, stripped_url)
      end_time = Time.now
      elapsed_time = end_time - start_time

      puts elapsed_time
      #puts "Links captured:".colorize(:light_green) + "\n #{links_total.uniq.join("\n  ")}"
    end    
  rescue StandardError
    # if subdomain not exists or dns can't be resolved
  end    
end
browser.close


if options[:output_file].nil?
  puts "Subdomains found:".colorize(:light_green) +"\n  #{subdomains.join("\n  ")}"
  puts "Active subdomains:".colorize(:light_green)  +"\n  #{active_subdomains.join("\n  ")}"  
  #puts "Links captured:".colorize(:light_green) + "\n #{links_total.uniq.join("\n  ")}"  
  puts "Links captured:".colorize(:light_green) + "\n #{links_total.uniq.sort_by(&:length).join("\n  ")}" 
else 
  File.open(options[:output_file], 'w') do |file|
    file.puts "Subdomains found:"
    subdomains.each {|subdomain| file.puts "  #{subdomain}"}
    file.puts "Active subdomains:"
    active_subdomains.each {|active| file.puts "  #{active}"}   
    file.puts "Links captured:"
    #links_total.each {|link| file.puts "  #{link}"} 
    links_total.sort_by(&:size).each { |link| file.puts "  #{link}" }
  end
  puts "Subdomains and Active subdomains saved to #{options[:output_file]}"
end  