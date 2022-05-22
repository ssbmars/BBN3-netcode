# DEVELOPMENT HAS MOVED
### Follow the new development here: https://github.com/tangobattle/tango  

The netcode implementation in this old repository makes use of the Lua scripting feature provided by Bizhawk. Bizhawk is a general-purpose emulator frontend that uses the mgba core to run GBA games. The Lua environment in Bizhawk ended up enabling a lot of features in this project that I didn't really expect to be possible, but the environment still has its limits, and the performance cost of running Bizhawk left much to be desired. Bizhawk is a large program meant for much more than just GBA games, so it was not well suited to the extremely specialized needs of a good netcode implementation. What we got with Bizhawk was better than anything we had before, but we can do even better.

With that said, I have some good news. A brand new mgba frontend is being developed with the sole purpose of enabling rollback netplay in Battle Network games! Although it will take time to rebuild everything from scratch, this new frontend will support more games and be much faster and much more resource-efficient than Bizhawk. It's a total gamechanger, and for that reason I will be ending active development of the Lua version of the netcode in favor of contributing to the new project. The source code and the playable release for this project will remain publically available in this repository. This repo may receive a few minor updates going forward, but there will be no brand new features.

The new project is named Tango, which used to be the planned name for the Lua version before it was replaced. You might still see references to "tango" in the Lua code, but keep in mind that this old project is not what people are talking about when they refer to Tango.  

For those curious, this is a non-exhaustive list of benefits that Tango will have over this old project.  
• Cross-platform, currently runs on Windows and Mac, has fewer hurdles for supporting additional platforms.  
• Easier setup with just one installer and a built-in setup guide, no prerequisite installations required.  
• The frontend is lightweight and significantly faster.  
• You get to directly run a real exe file to launch Tango instead of running a .bat file. Tango also doesn't have a "Lua Console" window that needs to remain open in order for the netcode to work.  
• The Tango client supports automatic updates.  
• Tango has its own mascot, and it's Bingus the cat.  
• Solutions can be more specialized, for example the higher level code in Tango that hooks into the gba's code makes use of software breakpoints that have no resource cost while the game is not passing over a hooked line of code. Conversely, the method of hooking a gba game with Lua code in Bizhawk incurred a major performance cost that was always in effect, even when the game was not passing over hooked addresses or running any Lua code.  


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
The aforementioned project Tango is cross-platform, at this time supporting Mac, Linux, and Windows. It's recommended that you use Tango.
