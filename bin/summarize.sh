#!/bin/sh
DOC=$1
shift
python3 ~/Bin/summarize-document.py "${DOC}" $*
