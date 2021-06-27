@echo off
start "" EmuHawk --lua="tango.lua"
sleep 1
start "" EmuHawk --lua="tango.lua" --config="config2.ini"