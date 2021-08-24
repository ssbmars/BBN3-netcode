@echo off
@echo Generating BBN3 Online Spanish.gba 
cd /d %~dp0
flips -a "../patches/BBN3_Online_Spanish.bps" %1 "../Netplay/BBN3 Online Spanish.gba"
@echo Finished
timeout 5
exit