
<h1 align="center">
  <br>
  Web Directory Enumeration Tool  
  <br>
  <br>
  <img src="https://user-images.githubusercontent.com/115858996/216793627-01f11973-f8fd-4ee8-8fe7-0c0787488d84.png">
  <br>  
</h1>



<b>Example:</b>
```bash
ruby ecce.rb -u https://www.google.com -s -p -e -l
```



<b>Note:</b>

```bash
-> To use stealth mode: the Tor browser must be opened and connected
-> On Linux: do not run as 'root'
-> Ensure that you have permission to the current directory to save the prints
-> mv /usr/bin/firefox-esr /usr/bin/firefox
```

<b>Gem Requirements: </b>

```bash
gem install colorize -v 0.8.1
gem install socksify -v 1.7.1
gem install nokogiri -v 1.13.7
gem install selenium-webdriver -v 4.7.1
gem install watir -v 7.2.2
```

<b>Further improvements: </b>
```bash
-> alternatives to stealth mode +vpn/proxies
-> recursive mode
-> incorporate robots to the directories
-> detect file uploads
-> graphical output 
