#!/bin/bash

#Definir variables de FTP
HOST='10.26.62.90'
USER='Administrator'
PASSWD='Admin1'
dia_semana_pasada=`echo $(date +%Y%m%d -d "1 week ago")`
		ftp -in $HOST<<FINFTP
                user $USER $PASSWD
                binary
		prompt off
		cd $dia_semana_pasada
		mdelete *
		cd ..
		rmdir $dia_semana_pasada
                bye
FINFTP

