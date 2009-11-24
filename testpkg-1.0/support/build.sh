#!/bin/bash

TRIP_URL=http://grencez.codelove.org/drop/${TRIP_NAME}-${TRIP_VERSION}.tar.gz

wget -O - $TRIP_URL | tar xvz \
&& cd $TRIP_NAME-$TRIP_VERSION \
&& make

