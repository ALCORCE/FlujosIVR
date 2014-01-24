#!/bin/bash

# Previa a la ejecucióel script:
# Crear carpeta DIR_TMP_CONVERTIDO con todos los permisos 777 y usuario y grupo adecuados 

#LANZAR COMO USUARIO ORACLE 

#Declaracióariables (Poner la / final para ambos directorios)
DIR_TMP_CONVERTIDO=/opt/oracle/export_grabaciones/tmp
#Definir variables de FTP
HOST='10.26.62.90'
USER='Administrator'
PASSWD='Admin1'


	#Copiamos fichero audio a directorio temporal
	cp $1 $DIR_TMP_CONVERTIDO
	
	#Obtenemos la variables para obtener los datos de la DB necesarios
        grabacion=`basename $1`
        AgentID=$(basename `dirname $1`)
        Fecha_grabacion=$(basename $(dirname `dirname $1`))
        #Calculamos el mes y borramos 0's delante del mes
        if [ ${Fecha_grabacion:4:1} == '0' ]
        then
            Mes_grabacion=${Fecha_grabacion:5:1}
        else
            Mes_grabacion=${Fecha_grabacion:4:2}
        fi

		#Query de la DB para obtener toda la informacióe la grabació	qu
		query1=$(sqlplus -S icd/icd@ipcc << EOF
                SET NEWPAGE 0
                SET SPACE 0
                SET LINESIZE 80
                SET PAGESIZE 0
                SET ECHO OFF
                SET FEEDBACK OFF
                SET VERIFY OFF
                SET HEADING OFF
                SET MARKUP HTML OFF SPOOL OFF
                SELECT VIRTUALCALLCENTERID,CURRENTSKILLID,CALLID,CALLERNO,CALLEENO,TO_CHAR(BEGINTIME,' HH24MISS') "inicio",TO_CHAR(ENDTIME,' HH24MISS') "fin",CALLTYPE FROM TRECORDINFO$Mes_grabacion WHERE FILENAME LIKE '%${grabacion}';
                exit
		EOF)
		
		resultado=($query1)
		VDN=${resultado[0]}
		SkillGroup=${resultado[1]}
		CallID=${resultado[2]}
		ANI=${resultado[3]}
		DNIS=${resultado[4]}
		Hora_Inicio=${resultado[5]}
		Hora_Fin=${resultado[6]}
		Tipo_llamada=${resultado[7]}
		
	 #Query DB para obtener las fechas de inicio y fin en formato timestamp
                fechas=$(sqlplus -S icd/icd@ipcc << EOF
                SET NEWPAGE 0
                SET SPACE 0
                SET LINESIZE 80
                SET PAGESIZE 0
                SET ECHO OFF
                SET FEEDBACK OFF
                SET VERIFY OFF
                SET HEADING OFF
                SET MARKUP HTML OFF SPOOL OFF
                SELECT TO_CHAR(BEGINTIME, 'DD/MM/YYYY HH24:MI:SS') AS col1,TO_CHAR(ENDTIME, 'DD/MM/YYYY HH24:MI:SS') AS col2 FROM TRECORDINFO$Mes_grabacion WHERE FILENAME LIKE '%${grabacion}';
                exit
                EOF)

                resultado_fechas=($fechas)
                Hora_Inicio_Timestamp=${resultado_fechas[0]}" "${resultado_fechas[1]}
                Hora_Fin_Timestamp=${resultado_fechas[2]}" "${resultado_fechas[3]}

	
		#Query de la DB para obtener la skill del agente de la grabació el nombre del agente		
		query2=$(sqlplus -S icd/icd@ipcc << EOF
                SET NEWPAGE 0
                SET SPACE 0
                SET LINESIZE 80
                SET PAGESIZE 0
                SET ECHO OFF
                SET FEEDBACK OFF
                SET VERIFY OFF
                SET HEADING OFF
                SET MARKUP HTML OFF SPOOL OFF
		SELECT NAME FROM TAGENTINFO WHERE VDN='$VDN' AND AGENTID='$AgentID';		 
                exit
		EOF)	
		NombreAgente=$query2


		#Exportamos el NLS_LANG en iso para recibir querys con con caracteres espanioles. Se cambia despues de la query al estandar

		export NLS_LANG=SPANISH_SPAIN.WE8ISO8859P1

		 #Query de la DB para obtener campo comentarios de la grabacion
                comentario_codigo=$(sqlplus -S hpsv1/hpsv1@ipcc << EOF
                SET NEWPAGE 0
                SET SPACE 0
                SET LINESIZE 80
                SET PAGESIZE 0
                SET ECHO OFF
                SET FEEDBACK OFF
                SET VERIFY OFF
                SET HEADING OFF
                SET MARKUP HTML OFF SPOOL OFF
                SELECT DISP_NAME FROM T_HPS_AGENT_DISP_DETAIL WHERE CALL_ID='$CallID';
                exit
                EOF)

		export NLS_LANG=AMERICAN_AMERICA.UTF8

		comentario_espacios=`echo $comentario_codigo | cut -d'#' -f2`
         	#Espaciamos los blancos para poder renombar el fichero posteriorment
                comentario=`echo $comentario_espacios |sed -e "s/ /\\_/g"`

		#Determinamos si es OUTBOUND o INBOUND
		if [ $Tipo_llamada == "0" ];
		then
			direccion=INBOUND
		else		
			direccion=OUTBOUND
		fi	

		#Checkear si los permisos son suficientes para que cambie el formato y el codec el root
       		cd $DIR_TMP_CONVERTIDO
		
		#Obtenemos el nombre del fichero ya convertido
		fichero_audio=`echo $(basename $1) | sed 's/\(.*\.\)V3/\1wav/'`
	
		#Conversióa extensióV3 a .wav (1º ponerlo en .vox y despuénvertir)
		formato_vox=`echo $(basename $1) | sed 's/\(.*\.\)V3/\1vox/'`
		mv `echo $(basename $1)` $formato_vox
		sox -r 6k $formato_vox $fichero_audio
		
		#Borramos fichero de la copia
		rm $formato_vox
	
		#Creamos el nombre cumpliendo el formato que se va a cumplir en la exportació¿CAMPO COMENTARIOS?)
		Nombre_Grabacion=$NombreAgente"_"$direccion"_"$Fecha_grabacion"_"$Hora_Inicio"_"$comentario".wav"
	
		#Ponemos el nuevo nombre del fichero
		mv $DIR_TMP_CONVERTIDO/$fichero_audio $DIR_TMP_CONVERTIDO/$Nombre_Grabacion
		
		#Obtenemos el tamañel fichero creado
		Size_Fichero=`wc -c $Nombre_Grabacion| awk '{print $1}'`

if [ $CallID != "" ];
then
 

		ftp -in $HOST<<FINFTP
                user $USER $PASSWD
                binary
		get FIDELIDADE$Fecha_grabacion.csv
                mkdir $Fecha_grabacion
                cd $Fecha_grabacion
                mkdir $NombreAgente
                cd $NombreAgente
                put $Nombre_Grabacion
                bye
FINFTP
		rm -f $Nombre_Grabacion
		
		#Sino existe el fichero CSV, añmos las cabeceras de dicho fichero
		if [ ! -f FIDELIDADE$Fecha_grabacion.csv ]
		then		
		echo -e FIDELIDADE,Agente,Id_Llamada,Hora_Inicio,Hora_Fin,Tipo,ANI,DNIS,,,Tipo Fichero,Tamanio de la imagen exportada,Path >> FIDELIDADE$Fecha_grabacion.csv
		fi
		
		#Una vez obtenido el fichero CSV actual para actualizarlo en la sesiótp anterior, procedemos a actualizar el fichero

		echo -e FIDELIDADE,$NombreAgente,$CallID,$Hora_Inicio_Timestamp,$Hora_Fin_Timestamp,$direccion,$ANI,$DNIS,,,wav,$Size_Fichero,.\\$Fecha_grabacion\\$NombreAgente\\$Nombre_Grabacion >> FIDELIDADE$Fecha_grabacion.csv
		
		#Subimos el fichero actualizado
		ftp -in $HOST<<FINFTP
                user $USER $PASSWD
                binary
		put FIDELIDADE$Fecha_grabacion.csv
                bye
FINFTP

fi

rm -f FIDELIDADE$Fecha_grabacion.csv

