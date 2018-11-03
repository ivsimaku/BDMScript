#!/bin/bash

# Title:                Casa_Systems_Channel_Count_Release2_2.sh
# Description:          This Script will take the Files and Processes which are available under directory <Dir_Path_Input>
# Parameter Required:   No
# Author:               Anil Kumar Meenavalli
# Date:                 02/21/2018
# Version:              2.2
# Script Created by LIQUIDHUB INDIA PVT Ltd.

#################################################################################################################################
#                                               Futures in 2.2 version                                                          #
#################################################################################################################################
#
#       ==> Process the log files from "$Dir_Path_Input" location and processed files moved to $Archive_dir & $Error_dir
#           up on execution status.
#
#       ==> Output Log file will send over mail to $rcpt recipient and keep a copy in Archive location.
#
#       ==> Script will Collect the data from QAM,UPS,CSC & BDM Card Modules & place the output data in $Output & $Archive_dir
#
#       ==> If we want to trace the job execution following are the key files to cross check $output,$logfile,$error_log_trace
#
#       ==> We have implemented the new logic to process the latest details of the serial number, if it detects the same
#	   serial number with multiple occurrences.
#
#
##################################################################################################################################

#################################################################################################################
##                                              Directory PATH Declarations                                    ##
#################################################################################################################

Dir_Path=/home/isimaku/data            #Working Directory: Which contains Files , Archive & Error directories.
Error_dir=$Dir_Path/Error_dir           #Error Directory: To Collect the Failure Files
Archive_dir=$Dir_Path/Archive_dir       #Archive Directory: To collect the successfully processed files.
Dir_Path_Input=$Dir_Path/config          #Files Locations which needs to be Process.
Dir_Path_Output=$Dir_Path/Output
mkdir -p $Dir_Path/.Config              #Creating Runtime Directory to hold process files.
Temp_Dir_Path=$Dir_Path/.Config         #Varibale to save Temporary directory path.
output="$Dir_Path_Output/output_$(date +%m_%d_%Y_%H_%M).txt"       #Creating the output file including runtime date in it's name
logfile="$Archive_dir/logfile_$(date +%m_%d_%Y_%H_%M).txt"         #Creating the logfile file including runtime date in it's name
error_log_trace="$Archive_dir/error_log_trace_$(date +%m_%d_%Y_%H_%M).txt" #Creating the error log file including runtime date in it's name

################################################################################################################
##                                              Varibale Declarations                                         ##
################################################################################################################

T_S_No=0 # To collect Total number of Files to process
S_S_No=0 # To Collect Success Files Count

################################################################################################################
##                                              Mail alias Declarations                                       ##
################################################################################################################

rcpt=mlefebvre@casa-systems.com  # Mail aliases to send the mails.


################################################################################################################
##                            Moving to the Input Files Location Under Working Directory                      ##
################################################################################################################

cd $Dir_Path_Input || exit 2


################################################################################################################
##                                              Starting the File Processing                                  ##
################################################################################################################

shopt -s nullglob;

for Filename in *;         #Picking the Files from Input directory to Variable Filename
do
    ((T_S_No++));
    ################################################################################################################
    ##                                      Verifying the Show system from Filename                               ##
    ################################################################################################################
    
    
    echo "File processing started for the $Filename " >> "$Temp_Dir_Path/logfile.txt"
    echo "--------------------------------------------------------------------------------" >> "$Temp_Dir_Path/logfile.txt"
    
    #The next three lines remove unknown symbols from text to make it readable and clear for unix
    tr -dc "[:alnum:][:punct:][:space:]\n\t" < "$Dir_Path_Input/$Filename" | tr -d $'\r' > "$Dir_Path_Input/""$Filename""encoded"
    rm "$Dir_Path_Input/$Filename"
    mv "$Dir_Path_Input/""$Filename""encoded" "$Dir_Path_Input/$Filename"
    
    grep -i "show syst" "$Dir_Path_Input/$Filename" > /dev/null 2>&1
    if [ $? != 0 ]
    then
        echo "No show system found in file: $Filename and Moving it to $Error_dir Path "  >> "$Temp_Dir_Path/logfile.txt"
        echo "$Filename processed and get the error and moved to $Error_dir with Failed the status "  >> "$Temp_Dir_Path/logfile.txt"
        mv "$Dir_Path_Input/$Filename" "$Error_dir/"
        echo "File processing started for the $Filename " >> "$error_log_trace"
        echo "--------------------------------------------------------------------------------" >> "$error_log_trace"
        echo "No show system found in file $Filename" >> "$error_log_trace"
        echo "$Filename moving to Error directory"   >> "$error_log_trace"
    else
        QAM_Status=0            # Initailizing the Variable to inform if QAM serial in file
        UPS_Status=0            # Initailizing the Variable to inform if UPS serial in file
        CSC_Status=0            # Initailizing the Variable to inform if CSC serial in file
        BDM_Status=0			# Initailizing the Variable to inform if BDM serial in file
        Skipped_Serials=0		# Initializing the Variable to count skipped serials per file
        Serials_Count=0         # Initializing the Variable to count all serials per file
        ###################################################################################################################################
        ##                              Method To Collect the QAM Serial numbers and it's Modules from the File                          ##
        ###################################################################################################################################
        
        
        GET_QAM_SR_NUM ()
        {
            echo "show system exists in the File $Filename" >> $Temp_Dir_Path/logfile.txt
            grep '\<Module.*QAM' "$Dir_Path_Input/$Filename"  > /dev/null 2>&1
            if [ $? != 0 ]
            then
                echo "No QAM found in show system file: $Filename " >> $Temp_Dir_Path/logfile.txt
                echo "No QAM found in show system file: $Filename " >> $Temp_Dir_Path/mailcontent.txt
            else
                QAM_Status=1 #QAM Valid execution status
                cat /dev/null > $Temp_Dir_Path/QAM_Serial_Num.txt # Nullifying the QAM Serial_Num file before process Start
                grep -En "'\<Module'|QAM"  "$Dir_Path_Input/$Filename" | grep -E  "Module" | awk ' { print $1 } ' | cut -d':' -f1 | while read -r QAM_MOD ;
                do
                    ((L_QAM_MOD=QAM_MOD+15))
                    sed -n "$QAM_MOD,$L_QAM_MOD p" "$Dir_Path_Input/$Filename" > $Temp_Dir_Path/Temp_Process_File1.txt
                    grep "Serial_No: Q" $Temp_Dir_Path/Temp_Process_File1.txt | awk ' { print $2 } '  > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        cat /dev/null > $Temp_Dir_Path/Temp_Process_File1.txt   # Nullifying the File For Next process Starts
                    else
                        Serial_Num=$(grep "Serial_No: Q" $Temp_Dir_Path/Temp_Process_File1.txt | head -1 | awk ' { print $2 } ')    #Collecting the QAM Serial No's
                        echo "$Serial_Num" >> $Temp_Dir_Path/QAM_Serial_Num.txt
                    fi
                done
                
                ###############################################################################################################################
                ## Following loop will sort the Unique QAM serial numbers and list the Channel modules for respective unique serial numbers. ##
                ###############################################################################################################################
                Collect_QAM ()
                {
                    ##  Collect Broadcast channels ##
                    grep -E "broadcast chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "Broadcast channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "Broadcast channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                        Broad_DS=NULL
                        echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        Broad_DS=$(grep -E "broadcast chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    ##  Collect docsis channels ##
                    grep -E "docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "docsis channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "docsis channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename"    >> $Temp_Dir_Path/mailcontent.txt
                        DOCSIS_DS=NULL
                        echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        DOCSIS_DS=$(grep -E "docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    ##  Collect RF channels ##
                    grep -E "RF chans"  $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "RF channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "RF channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                        RF_DS=NULL
                        echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        RF_DS=$(grep -E "RF chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    ##  Collect video channels ##
                    grep -E "video chans" $Temp_Dir_Path/Temp_Process_File2.txt  > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "video channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                        echo "video channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename"    >> $Temp_Dir_Path/mailcontent.txt
                        VIDEO_DS=NULL
                        echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        VIDEO_DS=$(grep -E "video chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    # Check if the data collected is longer than 5 lines, which means that we have upstream channels
                    if [ "$(wc -l < $Temp_Dir_Path/Temp_Process_File2.txt)" -gt 5 ]
                    then
                        ##  Collect OFDM channels ##
                        grep -E "OFDM chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            echo "OFDM channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                            echo "OFDM channels not found for QAM_Serial No: $QAM_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                            OFDM_DS=NULL
                            echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                            echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                            ((Skipped_Serials++));
                            continue;
                        else
                            OFDM_DS=$(grep -E "OFDM chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                        fi
                        
                        ##  Collect OFDM chan width  ##
                        grep -E "OFDM chan width" $Temp_Dir_Path/Temp_Process_File2.txt  > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            echo "OFDM channel width not found for QAM_Serial No: $QAM_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                            echo "OFDM channel width not found for QAM_Serial No: $QAM_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                            OFDM_US_WIDTH=NULL
                            echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                            echo "QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                            ((Skipped_Serials++));
                            continue;
                        else
                            OFDM_US_WIDTH=$(grep -E "OFDM chan width" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                        fi;
                    else
                        OFDM_DS=NULL;
                        OFDM_US_WIDTH=NULL;
                    fi;
                    DOCSIS_US=NULL ; OFDMA_US=NULL ; OFDMA_US_WIDTH=NULL ;
                    
                    
                    ################################################################################################################
                    ##                              To collect the QAM data in to logfile                                         ##
                    ################################################################################################################
                    
                    
                    echo  "$QAM_Serial_Num $Broad_DS $DOCSIS_DS $RF_DS $OFDM_DS $VIDEO_DS $OFDM_US_WIDTH $Filename" | tr -d '\015' >> $Temp_Dir_Path/logfile.txt
                    
                    ################################################################################################################
                    ##                      To collect the QAM data in to output file                                             ##
                    ################################################################################################################
                    
                    
                    echo  "$QAM_Serial_Num,$Broad_DS,$DOCSIS_DS,$RF_DS,$OFDM_DS,$VIDEO_DS,$DOCSIS_US,$OFDMA_US,$OFDM_US_WIDTH,$OFDMA_US_WIDTH" | tr -d '\015' >> $Temp_Dir_Path/output.txt
                    
                }
                
                ################################################################################################################
                ##                      To Start the process of each QAM Serial Number                                        ##
                ################################################################################################################
                
                for QAM_Serial_Num in $(cat $Temp_Dir_Path/QAM_Serial_Num.txt)
                do
                    Duplicate_Serial_check=$(grep -c "Serial Number = $QAM_Serial_Num" "$Dir_Path_Input/$Filename" )
                    if [ "$Duplicate_Serial_check" -ge 2 ]
                    then
                        # Following code will pick the last occurence QAM and take next 6 lines in a temporary file.
                        grep -E 'Serial Number|broadcast chans|docsis chans|RF chans|OFDM chans|video chans|OFDM chan width' "$Dir_Path_Input/$Filename" > "$Temp_Dir_Path""/Clean""$Filename"
                        cat /dev/null > $Temp_Dir_Path/duplicate.txt
                        grep -n "$QAM_Serial_Num" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/duplicate.txt
                        echo "Duplicate QAM serial Number : $QAM_Serial_Num  exists in $Filename checking for last occurrence" >> $Temp_Dir_Path/logfile.txt
                        Line=$(tail -1 $Temp_Dir_Path/duplicate.txt | awk ' { print $1 } ' | cut -d':' -f1)
                        ((Line_End=Line+6))
                        sed -n "$Line,$Line_End p" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/Temp_Process_File2.txt
                        # Test and see if within the next 6 lines another serial was captured, if so only capture before the second serial number.
                        if [ "$(grep -c "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt")" -gt "1" ] ;
                        then
                            Line_End=$(grep -n "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt" | tail -1 | awk ' { print $1 } ' | cut -d':' -f1 )
                            ((Line_End--))
                            sed -n "1,$Line_End p" "$Temp_Dir_Path/Temp_Process_File2.txt" > "$Temp_Dir_Path/Temp_Process_File2.txttmp"
                            mv "$Temp_Dir_Path/Temp_Process_File2.txttmp" "$Temp_Dir_Path/Temp_Process_File2.txt"
                        fi;
                        Collect_QAM ## Calling QAM data collection function
                    else
                        grep -En "$QAM_Serial_Num" "$Dir_Path_Input/$Filename" | grep -v "Part_No" > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            echo "No cmodinfoset - QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                            echo "No cmodinfoset - QAM serial number $QAM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                            ((Skipped_Serials++));
                            continue;
                        else
                            grep -E 'Serial Number|broadcast chans|docsis chans|RF chans|OFDM chans|video chans|OFDM chan width' "$Dir_Path_Input/$Filename" > "$Temp_Dir_Path""/Clean""$Filename"
                            Line=$(grep -En "$QAM_Serial_Num" "$Temp_Dir_Path""/Clean""$Filename" | grep -v "Part_No" | grep "Serial Number" | awk ' { print $1 } ' | cut -d':' -f1 )
                            ((Line_End=Line+6))
                            sed -n "$Line,$Line_End p" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/Temp_Process_File2.txt
                            # Test and see if within the next 6 lines another serial was captured, if so only capture before the second serial number.
                            if [ "$(grep -c "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt")" -gt "1" ] ;
                            then
                                Line_End=$(grep -n "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt" | tail -1 | awk ' { print $1 } ' | cut -d':' -f1 )
                                ((Line_End--))
                                sed -n "1,$Line_End p" "$Temp_Dir_Path/Temp_Process_File2.txt" > "$Temp_Dir_Path/Temp_Process_File2.txttmp"
                                mv "$Temp_Dir_Path/Temp_Process_File2.txttmp" "$Temp_Dir_Path/Temp_Process_File2.txt"
                            fi;
                            Collect_QAM ## Calling QAM data collection function
                        fi
                    fi
                done
            fi
        }
        
        ################################################################################################################
        ##             Method to Collect the UPS Serial numbers and it's Modules from File                            ##
        ################################################################################################################
        
        
        GET_UPS_SR_NUM ()
        {
            grep '\<Module.*UPS' "$Dir_Path_Input/$Filename"  > /dev/null 2>&1
            if [ $? != 0 ]
            then
                echo "No UPS found in show system file: $Filename " >> $Temp_Dir_Path/logfile.txt
                echo "No UPS Module found in show system file : $Filename"  >> $Temp_Dir_Path/mailcontent.txt
                
            else
                UPS_Status=1 # UPS Valid execution status
                cat /dev/null > $Temp_Dir_Path/UPS_Serial_Num.txt # Nullifying the UPS Serial_Num file before process Start
                grep -En "'\<Module'|UPS"  "$Dir_Path_Input/$Filename" | grep -E  "Module" | awk ' { print $1 } ' | cut -d':' -f1 | while read -r UPS_MOD ;
                do
                    ((L_UPS_MOD=UPS_MOD+15))
                    sed -n "$UPS_MOD,$L_UPS_MOD p" "$Dir_Path_Input/$Filename" > $Temp_Dir_Path/Temp_Process_File1.txt
                    grep "Serial_No: U" $Temp_Dir_Path/Temp_Process_File1.txt | awk ' { print $2 } ' > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        cat /dev/null > $Temp_Dir_Path/Temp_Process_File1.txt
                    else
                        Serial_Num=$(grep "Serial_No: U" $Temp_Dir_Path/Temp_Process_File1.txt | head -1| awk ' { print $2 } ')
                        echo "$Serial_Num" >> $Temp_Dir_Path/UPS_Serial_Num.txt
                    fi
                done
                
                ###############################################################################################################################
                ## Following loop will sort the Unique UPS serial numbers and list the Channel modules for respective unique serial numbers. ##
                ###############################################################################################################################
                Collect_UPS ()
                {
                    
                    ## Collect docsis channels  ##
                    grep -E "docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "docsis channels not found for UPS_Serial No: $UPS_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "docsis channels not found for UPS_Serial No: $UPS_Serial_Num in $Filename"  >> $Temp_Dir_Path/mailcontent.txt
                        DOCSIS_US=NULL
                        echo "UPS serial number $UPS_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "UPS serial number $UPS_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        DOCSIS_US=$(grep -E "docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    # Check if the data collected is longer than 2 lines, which means that we have upstream channels
                    if [ "$(wc -l < $Temp_Dir_Path/Temp_Process_File2.txt)" -gt 2 ]
                    then
                        ## Collect OFDM channels  ##
                        grep -E "OFDMA chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            echo "OFDMA channels not found for UPS_Serial No: $UPS_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                            echo "OFDMA channels not found for UPS_Serial No: $UPS_Serial_Num in $Filename"  >> $Temp_Dir_Path/mailcontent.txt
                            OFDMA_US=NULL
                            echo "UPS serial number $UPS_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                            echo "UPS serial number $UPS_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                            ((Skipped_Serials++));
                            continue;
                        else
                            OFDMA_US=$(grep -E "OFDMA chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                        fi
                        
                        ## Collect OFDMA channel Width  ##
                        grep -E "OFDMA chan width" $Temp_Dir_Path/Temp_Process_File2.txt  > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            echo "OFDMA channel Width not found for UPS_Serial No: $UPS_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                            echo "OFDMA channel Width not found for UPS_Serial No: $UPS_Serial_Num in $Filename"  >> $Temp_Dir_Path/mailcontent.txt
                            OFDMA_US_WIDTH=NULL
                            echo "UPS serial number $UPS_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                            echo "UPS serial number $UPS_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                            ((Skipped_Serials++));
                            continue;
                        else
                            OFDMA_US_WIDTH=$(grep -E "OFDMA chan width" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                        fi;
                    else
                        OFDMA_US=NULL;
                        OFDMA_US_WIDTH=NULL;
                    fi;
                    Broad_DS=NULL ; DOCSIS_DS=NULL; RF_DS=NULL;  OFDM_DS=NULL ; VIDEO_DS=NULL ; OFDM_US_WIDTH=NULL ;
                    
                    
                    
                    ################################################################################################################
                    ##                         To collect the UPS data in to logfile file                                         ##
                    ################################################################################################################
                    
                    echo  "$UPS_Serial_Num $DOCSIS_US $OFDMA_US $OFDMA_US_WIDTH $Filename" | tr -d '\015' >> $Temp_Dir_Path/logfile.txt
                    
                    ################################################################################################################
                    ##                         To collect the UPS data in to output file                                          ##
                    ################################################################################################################
                    
                    echo  "$UPS_Serial_Num,$Broad_DS,$DOCSIS_DS,$RF_DS,$OFDM_DS,$VIDEO_DS,$DOCSIS_US,$OFDMA_US,$OFDM_US_WIDTH,$OFDMA_US_WIDTH" | tr -d '\015' >> $Temp_Dir_Path/output.txt
                    
                }
                
                ################################################################################################################
                ##                      To Start the process of each UPS Serial Number                                        ##
                ################################################################################################################
                
                for UPS_Serial_Num in $(cat $Temp_Dir_Path/UPS_Serial_Num.txt)
                do
                    Duplicate_Serial_check=$(grep -c "Serial Number = $UPS_Serial_Num" "$Dir_Path_Input/$Filename" )
                    if [ "$Duplicate_Serial_check" -ge 2 ]
                    then
                        # Following code will pick the last occurence UPS and take next 3 lines in a temporary file.
                        grep -E 'Serial Number|docsis chans|OFDMA chans|OFDMA chan width' "$Dir_Path_Input/$Filename" > "$Temp_Dir_Path""/Clean""$Filename"
                        cat /dev/null > $Temp_Dir_Path/duplicate.txt
                        grep -n "$UPS_Serial_Num" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/duplicate.txt
                        echo "Duplicate UPS serial Number : $UPS_Serial_Num  exists in $Filename checking for last occurrence" >> $Temp_Dir_Path/logfile.txt
                        Line=$(tail -1 $Temp_Dir_Path/duplicate.txt | awk ' { print $1 } ' | cut -d':' -f1)
                        ((Line_End=Line+3))
                        sed -n "$Line,$Line_End p" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/Temp_Process_File2.txt
                        # Test and see if within the next 3 lines another serial was captured, if so only capture before the second serial number.
                        if [ "$(grep -c "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt")" -gt "1" ] ;
                        then
                            Line_End=$(grep -n "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt" | tail -1 | awk ' { print $1 } ' | cut -d':' -f1 )
                            ((Line_End--))
                            sed -n "1,$Line_End p" "$Temp_Dir_Path/Temp_Process_File2.txt" > "$Temp_Dir_Path/Temp_Process_File2.txttmp"
                            mv "$Temp_Dir_Path/Temp_Process_File2.txttmp" "$Temp_Dir_Path/Temp_Process_File2.txt"
                        fi;
                        Collect_UPS #Calling the Function
                    else
                        grep -En "$UPS_Serial_Num" "$Dir_Path_Input/$Filename" | grep -v "Part_No"  > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            echo "No cmodinfoset - UPS serial number $UPS_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                            echo "No cmodinfoset - UPS serial number $UPS_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                            ((Skipped_Serials++));
                            continue;
                        else
                            grep -E 'Serial Number|docsis chans|OFDMA chans|OFDMA chan width' "$Dir_Path_Input/$Filename" > "$Temp_Dir_Path""/Clean""$Filename"
                            Line=$(grep -En "$UPS_Serial_Num" "$Temp_Dir_Path""/Clean""$Filename" | grep -v "Part_No" | grep "Serial Number" | awk ' { print $1 } ' | cut -d':' -f1 )
                            ((Line_End=Line+3))
                            sed -n "$Line,$Line_End p" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/Temp_Process_File2.txt
                            # Test and see if within the next 3 lines another serial was captured, if so only capture before the second serial number.
                            if [ "$(grep -c "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt")" -gt "1" ] ;
                            then
                                Line_End=$(grep -n "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt" | tail -1 | awk ' { print $1 } ' | cut -d':' -f1 )
                                ((Line_End--))
                                sed -n "1,$Line_End p" "$Temp_Dir_Path/Temp_Process_File2.txt" > "$Temp_Dir_Path/Temp_Process_File2.txttmp"
                                mv "$Temp_Dir_Path/Temp_Process_File2.txttmp" "$Temp_Dir_Path/Temp_Process_File2.txt"
                            fi;
                            Collect_UPS #Calling the Function
                            
                        fi
                    fi
                done
            fi
        }
        
        ################################################################################################################
        ##             Method to Collect the CSC Serial numbers and it's Modules from File                            ##
        ################################################################################################################
        
        
        GET_CSC_SR_NUM ()
        {
            grep '\<Module.*CSC' "$Dir_Path_Input/$Filename"  > /dev/null 2>&1
            if [ $? != 0 ]
            then
                echo "No CSC found in show system file: $Filename " >> $Temp_Dir_Path/logfile.txt
                echo "No CSC Module found in show system file : $Filename"  >> $Temp_Dir_Path/mailcontent.txt
                
            else
                CSC_Status=1 # CSC Valid execution status
                cat /dev/null > $Temp_Dir_Path/CSC_Serial_Num.txt # Nullifying the CSC Serial_Num file before process Start
                grep -En "'\<Module'|CSC"  "$Dir_Path_Input/$Filename" | grep -E  "Module" | awk ' { print $1 } ' | cut -d':' -f1 | while read -r CSC_MOD ;
                do
                    ((L_CSC_MOD=CSC_MOD+15))
                    sed -n "$CSC_MOD,$L_CSC_MOD p" "$Dir_Path_Input/$Filename" > $Temp_Dir_Path/Temp_Process_File1.txt
                    Null_status=$(grep "Serial_No: C" $Temp_Dir_Path/Temp_Process_File1.txt | awk ' { print $1 } ')
                    s2=Chassis
                    if [ "$Null_status" == "$s2" ]
                    then
                        cat /dev/null > $Temp_Dir_Path/Temp_Process_File1.txt
                    else
                        grep "Serial_No: C" $Temp_Dir_Path/Temp_Process_File1.txt | awk ' { print $2 } ' > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            cat /dev/null > $Temp_Dir_Path/Temp_Process_File1.txt
                        else
                            Serial_Num=$(grep "Serial_No: C" $Temp_Dir_Path/Temp_Process_File1.txt | head -1 | awk ' { print $2 } ')
                            echo "$Serial_Num" >> $Temp_Dir_Path/CSC_Serial_Num.txt
                        fi
                    fi
                    
                done
                
                ###############################################################################################################################
                ## Following loop will sort the Unique CSC serial numbers and list the Channel modules for respective unique serial numbers. ##
                ###############################################################################################################################
                
                Collect_CSC ()
                {
                    
                    ##  Collect Broadcast channels ##
                    grep -E "broadcast chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "Broadcast channels not found for CSC_Serial No: $CSC_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "Broadcast channels not found for CSC_Serial No: $CSC_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                        Broad_DS=NULL
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        Broad_DS=$(grep -E "broadcast chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    ##  Collect DS docsis channels ##
                    grep -E "ds docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "DS docsis channels not found for CSC_Serial No: $CSC_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "DS docsis channels not found for CSC_Serial No: $CSC_Serial_Num in $Filename"    >> $Temp_Dir_Path/mailcontent.txt
                        DOCSIS_DS=NULL
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        DOCSIS_DS=$(grep -E "ds docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    ##  Collect OFDM chan width  ##
                    grep -E "OFDM chan width" $Temp_Dir_Path/Temp_Process_File2.txt  > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "OFDM channel width not found for CSC_Serial No: $CSC_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                        echo "OFDM channel width not found for CSC_Serial No: $CSC_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                        OFDM_US_WIDTH=NULL
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        OFDM_US_WIDTH=$(grep -E "OFDM chan width" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    ##  Collect video channels ##
                    grep -E "video chans" $Temp_Dir_Path/Temp_Process_File2.txt  > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "video channels not found for CSC_Serial No: $CSC_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                        echo "video channels not found for CSC_Serial No: $CSC_Serial_Num in $Filename"    >> $Temp_Dir_Path/mailcontent.txt
                        VIDEO_DS=NULL
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        VIDEO_DS=$(grep -E "video chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    
                    ## Collect US docsis channels  ##
                    grep -E "us docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "US docsis channels not found for CSC_Serial No: $CSC_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "US docsis channels not found for CSC_Serial No: $CSC_Serial_Num in $Filename"  >> $Temp_Dir_Path/mailcontent.txt
                        DOCSIS_US=NULL
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        DOCSIS_US=$(grep -E "us docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    ## Collect OFDMA channel Width  ##
                    grep -E "OFDMA chan width" $Temp_Dir_Path/Temp_Process_File2.txt  > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "OFDMA channel Width not found for CSC_Serial No: $CSC_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                        echo "OFDMA channel Width not found for CSC_Serial No: $CSC_Serial_Num in $Filename"  >> $Temp_Dir_Path/mailcontent.txt
                        OFDMA_US_WIDTH=NULL
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        OFDMA_US_WIDTH=$(grep -E "OFDMA chan width" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ' )
                    fi
                    
                    RF_DS=NULL ; OFDM_DS=NULL ; OFDMA_US=NULL ;
                    
                    
                    ################################################################################################################
                    ##                         To collect the CSC data in to logfile file                                         ##
                    ################################################################################################################
                    
                    echo  "$CSC_Serial_Num,$Broad_DS,$DOCSIS_DS,$RF_DS,$VIDEO_DS,$DOCSIS_US,$OFDM_US_WIDTH,$OFDMA_US_WIDTH" | tr -d '\015' >> $Temp_Dir_Path/logfile.txt
                    
                    ################################################################################################################
                    ##                         To collect the CSC data in to output file                                          ##
                    ################################################################################################################
                    
                    echo  "$CSC_Serial_Num,$Broad_DS,$DOCSIS_DS,$RF_DS,$OFDM_DS,$VIDEO_DS,$DOCSIS_US,$OFDMA_US,$OFDM_US_WIDTH,$OFDMA_US_WIDTH" | tr -d '\015' >> $Temp_Dir_Path/output.txt
                    
                }
                
                ################################################################################################################
                ##                      To Start the process of each CSC Serial Number                                        ##
                ################################################################################################################
                
                for CSC_Serial_Num in $(cat $Temp_Dir_Path/CSC_Serial_Num.txt)
                do
                    Duplicate_Serial_check=$(grep -c "Serial Number = $CSC_Serial_Num" "$Dir_Path_Input/$Filename" )
                    if [ "$Duplicate_Serial_check" -ge 2 ]
                    then
                        # Following code will pick the last occurence CSC and take next 6 lines in a temporary file.
                        grep -E 'Serial Number|broadcast chans|ds docsis chans|OFDM chan width|video chans|us docsis chans|OFDMA chan width' "$Dir_Path_Input/$Filename" > "$Temp_Dir_Path""/Clean""$Filename"
                        cat /dev/null > $Temp_Dir_Path/duplicate.txt
                        grep -n "$CSC_Serial_Num" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/duplicate.txt
                        echo "Duplicate CSC serial Number : $CSC_Serial_Num  exists in $Filename checking for last occurrence" >> $Temp_Dir_Path/logfile.txt
                        Line=$(tail -1 $Temp_Dir_Path/duplicate.txt | awk ' { print $1 } ' | cut -d':' -f1)
                        ((Line_End=Line+6))
                        sed -n "$Line,$Line_End p" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/Temp_Process_File2.txt
                        # Test and see if within the next 6 lines another serial was captured, if so only capture before the second serial number.
                        if [ "$(grep -c "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt")" -gt "1" ] ;
                        then
                            Line_End=$(grep -n "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt" | tail -1 | awk ' { print $1 } ' | cut -d':' -f1 )
                            ((Line_End--))
                            sed -n "1,$Line_End p" "$Temp_Dir_Path/Temp_Process_File2.txt" > "$Temp_Dir_Path/Temp_Process_File2.txttmp"
                            mv "$Temp_Dir_Path/Temp_Process_File2.txttmp" "$Temp_Dir_Path/Temp_Process_File2.txt"
                        fi;
                        Collect_CSC #Calling the Function
                    else
                        
                        grep -En "$CSC_Serial_Num" "$Dir_Path_Input/$Filename" | grep -v "Part_No"  > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            echo "No cmodinfoset - CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                            echo "No cmodinfoset - CSC serial number $CSC_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                            ((Skipped_Serials++));
                            continue;
                        else
                            grep -E 'Serial Number|broadcast chans|ds docsis chans|OFDM chan width|video chans|us docsis chans|OFDMA chan width' "$Dir_Path_Input/$Filename" > "$Temp_Dir_Path""/Clean""$Filename"
                            Line=$(grep -En "$CSC_Serial_Num" "$Temp_Dir_Path""/Clean""$Filename" | grep -v "Part_No" | grep "Serial Number" | awk ' { print $1 } ' | cut -d':' -f1 )
                            ((Line_End=Line+6))
                            sed -n "$Line,$Line_End p" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/Temp_Process_File2.txt
                            # Test and see if within the next 6 lines another serial was captured, if so only capture before the second serial number.
                            if [ "$(grep -c "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt")" -gt "1" ] ;
                            then
                                Line_End=$(grep -n "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt" | tail -1 | awk ' { print $1 } ' | cut -d':' -f1 )
                                ((Line_End--))
                                sed -n "1,$Line_End p" "$Temp_Dir_Path/Temp_Process_File2.txt" > "$Temp_Dir_Path/Temp_Process_File2.txttmp"
                                mv "$Temp_Dir_Path/Temp_Process_File2.txttmp" "$Temp_Dir_Path/Temp_Process_File2.txt"
                            fi;
                            Collect_CSC #Calling the Function
                        fi
                    fi
                done
            fi
        }
        
        
        ###################################################################################################################################
        ##                              Method To Collect the BDM Serial numbers and it's Modules from the File                          ##
        ###################################################################################################################################
        
        
        GET_BDM_SR_NUM ()
        {
            grep '\<Module.*BDM' "$Dir_Path_Input/$Filename"  > /dev/null 2>&1
            if [ $? != 0 ]
            then
                echo "No BDM found in show system file: $Filename " >> $Temp_Dir_Path/logfile.txt
                echo "No BDM found in show system file : $Filename " >> $Temp_Dir_Path/mailcontent.txt
            else
                BDM_Status=1 #BDM Valid execution status
                cat /dev/null > $Temp_Dir_Path/BDM_Serial_Num.txt # Nullifying the BDM Serial_Num file before process Start
                grep -En "'\<Module'|BDM"  "$Dir_Path_Input/$Filename" | grep -E  "Module" | awk ' { print $1 } ' | cut -d':' -f1 | while read -r BDM_MOD ;
                do
                    ((L_BDM_MOD=BDM_MOD+15))
                    sed -n "$BDM_MOD,$L_BDM_MOD p" "$Dir_Path_Input/$Filename" > $Temp_Dir_Path/Temp_Process_File1.txt
                    grep "Serial_No: X" $Temp_Dir_Path/Temp_Process_File1.txt | awk ' { print $2 } '  > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        cat /dev/null > $Temp_Dir_Path/Temp_Process_File1.txt   # Nullifying the File For Next process Starts
                    else
                        Serial_Num=$(grep "Serial_No: X" $Temp_Dir_Path/Temp_Process_File1.txt | head -1 | awk ' { print $2 } ')				#Collecting the BDM Serial No's
                        echo "$Serial_Num" >> $Temp_Dir_Path/BDM_Serial_Num.txt
                    fi
                done
                
                ###############################################################################################################################
                ## Following loop will sort the Unique BDM serial numbers and list the Channel modules for respective unique serial numbers. ##
                ###############################################################################################################################
                Collect_BDM ()
                {
                    ##  Collect broadcast channels ##
                    grep -E "broadcast chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "broadcast channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "broadcast channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                        Broad_DS=NULL
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        Broad_DS=$(grep -E "broadcast chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ')
                    fi
                    
                    ##  Collect ds docsis channels ##
                    grep -E "ds docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "ds docsis channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "ds docsis channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename"    >> $Temp_Dir_Path/mailcontent.txt
                        DOCSIS_DS=NULL
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        DOCSIS_DS=$(grep -E "ds docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ')
                    fi
                    
                    ##  Collect video channels ##
                    grep -E "video chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "video channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                        echo "video channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename"    >> $Temp_Dir_Path/mailcontent.txt
                        VIDEO_DS=NULL
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        VIDEO_DS=$(grep -E "video chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ')
                    fi
                    
                    ##  Collect OFDM channels  ##
                    grep -E "OFDM chan width" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "OFDM channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                        echo "OFDM channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                        OFDM_DS_WIDTH=NULL
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        OFDM_DS_WIDTH=$(grep -E "OFDM chan width" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ')
                    fi
                    
                    ##  Collect us docsis channels ##
                    grep -E "us docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "us docsis channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename" >> $Temp_Dir_Path/logfile.txt
                        echo "us docsis channels not found for BDM_Serial No: $BDM_Serial_Num in $Filename"    >> $Temp_Dir_Path/mailcontent.txt
                        DOCSIS_US=NULL
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        DOCSIS_US=$(grep -E "us docsis chans" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ')
                    fi
                    
                    
                    
                    ##  Collect OFDMA channel width  ##
                    grep -E "OFDMA chan width" $Temp_Dir_Path/Temp_Process_File2.txt > /dev/null 2>&1
                    if [ $? != 0 ]
                    then
                        echo "OFDMA channel width not found for BDM_Serial No: $BDM_Serial_Num in $Filename"  >> $Temp_Dir_Path/logfile.txt
                        echo "OFDMA channel width not found for BDM_Serial No: $BDM_Serial_Num in $Filename"   >> $Temp_Dir_Path/mailcontent.txt
                        OFDMA_US_WIDTH=NULL
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                        echo "BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                        ((Skipped_Serials++));
                        continue;
                    else
                        OFDMA_US_WIDTH=$(grep -E "OFDMA chan width" $Temp_Dir_Path/Temp_Process_File2.txt | cut -d "=" -f2 |tr -d ' ')
                    fi
                    
                    RF_DS=NULL; OFDM_DS=NULL ; OFDMA_US=NULL;
                    
                    
                    ################################################################################################################
                    ##                              To collect the BDM data in to logfile                                         ##
                    ################################################################################################################
                    
                    
                    echo  "$BDM_Serial_Num" "$Broad_DS" "$DOCSIS_DS" "$RF_DS" "$OFDM_DS" "$VIDEO_DS" "$DOCSIS_US" "$OFDMA_US" "$OFDM_DS_WIDTH" "$OFDMA_US_WIDTH" "$Filename" | tr -d '\015' >> $Temp_Dir_Path/logfile.txt
                    
                    ################################################################################################################
                    ##                      To collect the BDM data in to output file                                             ##
                    ################################################################################################################
                    
                    
                    echo  "$BDM_Serial_Num","$Broad_DS","$DOCSIS_DS","$RF_DS","$OFDM_DS","$VIDEO_DS","$DOCSIS_US","$OFDMA_US","$OFDM_DS_WIDTH","$OFDMA_US_WIDTH" | tr -d '\015' >> $Temp_Dir_Path/output.txt
                    
                }
                
                ################################################################################################################
                ##                      To Start the process of each BDM Serial Number                                        ##
                ################################################################################################################
                
                for BDM_Serial_Num in $(cat $Temp_Dir_Path/BDM_Serial_Num.txt)
                do
                    Duplicate_Serial_check=$(grep -c "Serial Number = $BDM_Serial_Num" "$Dir_Path_Input/$Filename" )
                    if [ "$Duplicate_Serial_check" -ge 2 ]
                    then
                        # Following code will pick the last occurence BDM and take next 10 lines in a temporary file.
                        grep -E 'Serial Number|broadcast chans|ds docsis chans|video chans|OFDM chan width|us docsis chans|OFDMA chan width' "$Dir_Path_Input/$Filename" > "$Temp_Dir_Path""/Clean""$Filename"
                        cat /dev/null > $Temp_Dir_Path/duplicate.txt
                        grep -n "$BDM_Serial_Num" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/duplicate.txt
                        echo "Duplicate BDM serial Number : $BDM_Serial_Num  exists in $Filename checking for last occurrence" >> $Temp_Dir_Path/logfile.txt
                        Line=$(tail -1 $Temp_Dir_Path/duplicate.txt | awk ' { print $1 } ' | cut -d':' -f1)
                        ((Line_End=Line+6))
                        sed -n "$Line,$Line_End p" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/Temp_Process_File2.txt
                        # Test and see if within the next 6 lines another serial was captured, if so only capture before the second serial number.
                        if [ "$(grep -c "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt")" -gt "1" ] ;
                        then
                            Line_End=$(grep -n "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt" | tail -1 | awk ' { print $1 } ' | cut -d':' -f1 )
                            ((Line_End--))
                            sed -n "1,$Line_End p" "$Temp_Dir_Path/Temp_Process_File2.txt" > "$Temp_Dir_Path/Temp_Process_File2.txttmp"
                            mv "$Temp_Dir_Path/Temp_Process_File2.txttmp" "$Temp_Dir_Path/Temp_Process_File2.txt"
                        fi;
                        Collect_BDM ## Calling BDM data collection function
                    else
                        grep -En "$BDM_Serial_Num" "$Dir_Path_Input/$Filename" | grep -v "Part_No" > /dev/null 2>&1
                        if [ $? != 0 ]
                        then
                            echo "No cmodinfoset - BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/logfile.txt
                            echo "No cmodinfoset - BDM serial number $BDM_Serial_Num from file $Filename skipped!" >> $Temp_Dir_Path/mailcontent.txt
                            ((Skipped_Serials++));
                            continue;
                        else
                            grep -E 'Serial Number|broadcast chans|ds docsis chans|video chans|OFDM chan width|us docsis chans|OFDMA chan width' "$Dir_Path_Input/$Filename" > "$Temp_Dir_Path""/Clean""$Filename"
                            Line=$(grep -En "$BDM_Serial_Num" "$Temp_Dir_Path""/Clean""$Filename" | grep -v "Part_No" | grep "Serial Number" | awk ' { print $1 } ' | cut -d':' -f1 )
                            ((Line_End=Line+6))
                            sed -n "$Line,$Line_End p" "$Temp_Dir_Path""/Clean""$Filename" > $Temp_Dir_Path/Temp_Process_File2.txt
                            # Test and see if within the next 6 lines another serial was captured, if so only capture before the second serial number.
                            if [ "$(grep -c "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt")" -gt "1" ] ;
                            then
                                Line_End=$(grep -n "Serial Number" "$Temp_Dir_Path/Temp_Process_File2.txt" | tail -1 | awk ' { print $1 } ' | cut -d':' -f1 )
                                ((Line_End--))
                                sed -n "1,$Line_End p" "$Temp_Dir_Path/Temp_Process_File2.txt" > "$Temp_Dir_Path/Temp_Process_File2.txttmp"
                                mv "$Temp_Dir_Path/Temp_Process_File2.txttmp" "$Temp_Dir_Path/Temp_Process_File2.txt"
                            fi;
                            #|| [ "$(wc -l < "$Temp_Dir_Path/Temp_Process_File2.txt")" -lt "7" ]
                            #Line=$(grep -En $BDM_Serial_Num $Dir_Path_Input/$Filename | grep -v "Part_No"|grep "Serial Number"| awk ' { print $1 } ' | cut -d':' -f1 )
                            #let Line_End=$Line+10
                            #sed -n "$Line,$Line_End p" $Dir_Path_Input/$Filename > $Temp_Dir_Path/Temp_Process_File2.txt
                            Collect_BDM ## Calling BDM data collection function
                        fi
                    fi
                done
            fi
        }
        
        
        GET_QAM_SR_NUM  #### Calling QAM Function
        GET_UPS_SR_NUM  #### Calling UPS Function
        GET_CSC_SR_NUM  #### Calling CSC Function
        GET_BDM_SR_NUM	#### Calling BDM Function
        
        ################################################################################################
        ##           Following condition will be decide to categorize the processed file              ##
        ################################################################################################
        
        
        if [ $QAM_Status == 1 ] || [ $UPS_Status == 1 ] || [ $CSC_Status == 1 ] || [ $BDM_Status == 1 ] ;
        then
            Serials_Count=$(cat $Temp_Dir_Path/*_Serial_Num.txt|sed '/^\s*$/d' | wc -l)
            
            
            
            if [ "$Skipped_Serials" == "$Serials_Count" ]
            then
                mv "$Dir_Path_Input/$Filename" "$Error_dir/"
                cat $Temp_Dir_Path/logfile.txt >> "$logfile"
                cat $Temp_Dir_Path/logfile.txt >> "$error_log_trace"
                cat /dev/null > $Temp_Dir_Path/output.txt
                cat /dev/null > $Temp_Dir_Path/logfile.txt
                echo "All serials broken in $Filename"   >> "$logfile"
                echo "All serials broken in $Filename"   >> "$error_log_trace"
                echo "$Filename moving to Error directory"   >> "$logfile"
                echo "$Filename moving to Error directory"   >> "$error_log_trace"
            else
                ((S_S_No++));   # To count the successive process files
                mv "$Dir_Path_Input/$Filename" "$Archive_dir/"
                echo "Serials skipped: $Skipped_Serials" >> $Temp_Dir_Path/logfile.txt
                echo "$Filename processed Successfully...! "  >> $Temp_Dir_Path/logfile.txt
                cat $Temp_Dir_Path/output.txt >> $Temp_Dir_Path/Temp_output.txt
                cat $Temp_Dir_Path/logfile.txt >> "$logfile"
                cat $Temp_Dir_Path/*_Serial_Num.txt|sed '/^\s*$/d'  > "$Archive_dir/$Filename""_Serials"
                rm -rf "$Temp_Dir_Path/*Serial_Num.txt"
                cat /dev/null > $Temp_Dir_Path/output.txt
                cat /dev/null > $Temp_Dir_Path/logfile.txt
                echo "$Filename moving to Archive directory"    >> "$logfile"
            fi
        else
            mv "$Dir_Path_Input/$Filename" "$Error_dir/"
            cat $Temp_Dir_Path/logfile.txt >> "$logfile"
            cat $Temp_Dir_Path/logfile.txt >> "$error_log_trace"
            cat /dev/null > $Temp_Dir_Path/output.txt
            cat /dev/null > $Temp_Dir_Path/logfile.txt
            echo "$Filename moving to Error directory"   >> "$logfile"
            echo "$Filename moving to Error directory"   >> "$error_log_trace"
            
        fi
        
        echo "########################################################"   >> "$logfile"
    fi
done
#    echo Script executed and $S_S_No Files processed Successfully out of $T_S_No and attached the error log | mail -s "Error Report on $(date +%m_%d_%Y) " -a $error_log_trace $rcpt
#   cp $Temp_Dir_Path/Temp_output.txt $output  > /dev/null 2>&1
#   cp $output $Archive_dir/.  > /dev/null 2>&1 # Keep copy of the output file in Archive directory Location.
#   rm -rf $Dir_Path/.Config  #Clearing the Temporary Files directory
#   echo " $S_S_No Files processed Successfully out of $T_S_No "  >> $logfile

ls -l "$error_log_trace" > /dev/null 2>&1
if [ $? != 0 ]
then
    
    echo " $S_S_No Files processed Successfully out of $T_S_No "  >> "$logfile"
    #	 echo Script executed and $S_S_No Files processed Successfully out of $T_S_No and attached the Successive log report | mail -s "Successive Report on $(date +%m_%d_%Y) " -a $logfile $ $rcpt  > /dev/null 2>&1
    cp "$Temp_Dir_Path/Temp_output.txt" "$output"  > /dev/null 2>&1
    cp "$output" "$Archive_dir/."  > /dev/null 2>&1 # Keep copy of the output file in Archive directory Location.
    #rm -rf $Dir_Path/.Config  #Clearing the Temporary Files directory
    
else
    
    #	 echo Script executed and $S_S_No Files processed Successfully out of $T_S_No and attached the error log | mail -s "Error Report on $(date +%m_%d_%Y) " -a $error_log_trace $rcpt > /dev/null 2>&1
    cp "$Temp_Dir_Path/Temp_output.txt" "$output"  > /dev/null 2>&1
    cp "$output" "$Archive_dir/."  > /dev/null 2>&1 # Keep copy of the output file in Archive directory Location.
    #rm -rf $Dir_Path/.Config  #Clearing the Temporary Files directory
    echo " $S_S_No Files processed Successfully out of $T_S_No "  >> "$logfile"
fi