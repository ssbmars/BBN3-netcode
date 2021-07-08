@echo off
start "" EmuHawk --lua="tango.lua"
ping 192.0.2.1 -n 1 -w 1000 >nul
start "" EmuHawk --lua="tango.lua" --config="config2.ini"