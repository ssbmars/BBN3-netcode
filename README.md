

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
Tip: The performance requirement increases when the Delay Buffer is low, and decreases when the Delay Buffer is high. Even with a slow computer, it can still be possible to play by significantly increasing your Delay Buffer in the settings.

According to Bizhawk's documentation, the scripting feature is only fully supported by 64bit Windows systems.  
There are future netplay solutions in the works that will have improved platform accessibility, but they will take longer to deliver on.
We've seen early signs that it may become possible to support Linux in the future. There is no sign that Mac OS will ever be compatible.
