#!/bin/sh
HOST=megamind.local
FILE=/tmp/fump.$$
( sleep 5; open `egrep '^[\t ]+http://' ${FILE}`; rm ${FILE} ) &
ssh jkh@${HOST} '(cd Src/Notebooks; jupyter notebook --no-browser --ip=0.0.0.0 )' 2>&1 |tee ${FILE}
