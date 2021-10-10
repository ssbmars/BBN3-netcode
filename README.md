

# Experimental BBN3 Netplay

The main netplay script is "\BizHawk-2.5.2\bbn3_netplay.lua"

There are two batch files for launching the netplay script. "Launch Netplay.bat" in the root directory will load one instance.
There is also a "load tango double.bat" file in the BizHawk folder which will launch two local instances, good for testing stuff on local host.

## BizHawk prerequisite installer
This netplay solution uses the scripting features provided by BizHawk emulator.  
This installer needs to be ran once before BizHawk will work properly.  
https://github.com/TASVideos/BizHawk-Prereqs/releases


# Misc

It seems that a decently fast computer is needed in order to run Bizhawk at an acceptable speed. 
If your PC can't run two local instances of the netplay script without experiencing slowdowns, then it is likely to struggle with online play.

According to Bizhawk's documentation, the scripting feature is only compatible with 64bit Windows systems.  
There is nothing we can do about this. The Bizhawk developers simply haven't brought the scripting capabilities to Linux or Mac.  
There are future netplay solutions in the works that will have improved platform accessibility, but they will take longer to deliver on.
