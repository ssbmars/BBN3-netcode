@echo off
cd BizHawk-2.5.2
start "" EmuHawk --lua="test_mmjoin.lua" --config="config2.ini" "Netplay\voidrom.gba"