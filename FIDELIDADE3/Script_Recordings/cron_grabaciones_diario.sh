#!/bin/bash

#Lanzar como cron 10-15 min despuéde la jornada de trabajo para volcar todas las grabaciones

script_grabaciones=/opt/oracle/export_grabaciones/volcado_grabaciones.sh
tmp_grabaciones=/opt/oracle/export_grabaciones/tmp
Dir_Fidelidade=/home/icd/icddir/bin/Y\:/6/0
hoy=`echo $(date +%Y%m%d)`

for grabacion in `find $Dir_Fidelidade/$hoy/ -name "*.V3"`
do
	if [ -f $grabacion ];
	then
		sh -x $script_grabaciones $grabacion
	fi 
done

rm -rf $tmp_grabaciones/*

