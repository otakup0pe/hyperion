#!/usr/bin/env bash

SCRIPTDIR=$(cd ${0%/*} && pwd)
ROOTDIR="${SCRIPTDIR%/*}"

function reload {
    cd ${ROOTDIR}/plugin
    lua *.lua || exit 1 
    xmllint *.xml || exit 1
    json_pp < D_Hyperion1.json || exit 1
    scp ${ROOTDIR}/plugin/* vera:/etc/cmh-ludl/ && \
        curl 'http://vera:3480/data_request?id=reload' || exit 1
}

OWD=$(pwd)
RC=0
while [ true ] ; do
    dialog --yesno "Deploy that sweet\nsweet\nlua\n\n?" 10 30
    if [ $? == 0 ] ; then
        reload
    else
        cd $OWD
        exit 0
    fi
done
