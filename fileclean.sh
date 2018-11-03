#!/bin/bash
echo "Enter file name:"
read FileName
tr -dc "[:alnum:][:punct:][:space:]\n\t" <$FileName | tr -d $'\r' >$FileName"encoded"
mv $FileName"encoded" $FileName

