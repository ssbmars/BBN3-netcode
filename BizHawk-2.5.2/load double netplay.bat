@echo off
start "" EmuHawk --lua="bbn3_netplay.lua" BBN3\BBN3.gba
TIMEOUT /T 4
start "" EmuHawk --lua="bbn3_netplay.lua" --config="config2.ini" BBN3\BBN3p2.gba