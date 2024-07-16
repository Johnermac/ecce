
<h1 align="center">
  <br>
  Web Directory Enumeration Tool  
  <br>
  <br>
  <img src="https://user-images.githubusercontent.com/115858996/216793627-01f11973-f8fd-4ee8-8fe7-0c0787488d84.png">
  <br>  
</h1>


<b>To Install: </b>

```bash
bundle install
```

<b>Example:</b>

```bash
ruby ecce.rb -u https://www.google.com -d -s -p -e -l
```


<b>Note:</b>

```bash
-> To use stealth mode: the Tor browser must be opened and connected
-> On Linux: do not run as 'root'
-> Ensure that you have permission to the current directory to save the prints
-> mv /usr/bin/firefox-esr /usr/bin/firefox
```


<b>Further improvements: </b>

```bash
-> alternatives to stealth mode +vpn/proxies
-> recursive mode
-> incorporate robots to the directories
-> detect file uploads
-> graphical output 
