@echo off
@echo Generating BBN3 Online.gba 
cd /d %~dp0
flips -a "../patches/BBN3_Online.bps" %1 "../Netplay/BBN3 Online.gba"
@echo Finished
timeout 5
exit