#!/bin/bash

sshpass -p "isimaku1" scp BDMScript.sh isimaku@50.206.125.232:/home/isimaku
if [ $? == "0" ]
then
	echo "SUCCESS"
else
	echo "FAILED!"
fi;
