#!/bin/bash

while getopts "i:g:t:d:e:l:u:v:o:n:r:" optionName; do
case "$optionName" in

i) INPUT="$OPTARG";;
g) GENOME="$OPTARG";;
t) DATATYPE="$OPTARG";;
d) DATABASE="$OPTARG";;
e) EXT="$OPTARG";;
l) LOG_FILE="$OPTARG";;
u) UCSC="$OPTARG";;
v) UCSC_TRACK="$OPTARG";;
o) OUT="$OPTARG";;
n) NORM="$OPTARG";;
r) ROOT_DIR="$OPTARG";;


esac
done

##### ncPRO-seq annotation - Galaxy #####

GENOME_2=`echo $GENOME | cut -d"_" -f2`

databasePath=$ROOT_DIR/database/files

mkdir -p $databasePath/ncproseqAnnotation
mkdir -p $databasePath/ncproseqAnnotation/annotation
annotationPath=$databasePath/ncproseqAnnotation/annotation
[ ! -d $annotationPath/$GENOME_2 ] && wget http://ncpro.curie.fr/ncproseq/install_dir/annotation/$GENOME.tar.gz -P $annotationPath && cd $annotationPath && tar -zxf $GENOME.tar.gz && rm -rf $GENOME.tar.gz

#########

OUTPUT_PATH_DIR=`dirname $LOG_FILE`
OUTPUT_PATH_NAME=`basename $LOG_FILE .dat`

OUTPUT_PATH="${OUTPUT_PATH_DIR}/${OUTPUT_PATH_NAME}_files"

# this was missing
mkdir -p $OUTPUT_PATH

VERSION=`echo $OUTPUT_PATH | cut -d"/" -f3`
VERSION=`echo $VERSION | cut -d"_" -f2`

#DEBUG_MODE

DEBUG_MODE="on"
DEBUG="/dev/null"

if [[ $DEBUG_MODE == "on" ]];then

	DEBUG="$OUTPUT_PATH/ncPRO-ANNOTATION.debug"

fi

#Deploy ncPRO directories structure

/usr/curie_ngs/ncproseq_v1.6.5/bin/ncPRO-deploy -o $OUTPUT_PATH > $DEBUG
# READ_GROUP = 1 ! (always)


chmod 777 -R $OUTPUT_PATH
#Go to working directory

cd $OUTPUT_PATH

rm annotation

ln -s $annotationPath annotation

#Create symbolic link to input

ln -s $INPUT ${OUTPUT_PATH}/rawdata/input.bam

#Edit config-ncrna.txt

CONFIG_FILE=config-ncrna.txt

sed -i "s:^BOWTIE_GENOME_REFERENCE =.*$:BOWTIE_GENOME_REFERENCE = $GENOME_2:g" $CONFIG_FILE
sed -i "s:^ORGANISM.*$:ORGANISM = $GENOME_2:g" $CONFIG_FILE

sed -i "/N_CPU/c\N_CPU = 6" $CONFIG_FILE  #****** Make sure this value matches universe.ini files
sed -i "s/test_Curie/$PROJECTNAME/g" $CONFIG_FILE
sed -i "s:^FASTQ_FORMAT =.*$:FASTQ_FORMAT = $FASTQ_FORMAT:g" $CONFIG_FILE
#sed -i "s/LOGFILE = pipeline.log/LOGFILE = $LOG_FILE/g" $CONFIG_FILE

if [[ $DATATYPE == "matmir" ]];then

	sed -i "s/MATURE_MIRNA =/MATURE_MIRNA = $EXT/g" $CONFIG_FILE

elif [[ $DATATYPE == "premir" ]];then

	sed -i "s/PRECURSOR_MIRNA =/PRECURSOR_MIRNA = $EXT/g" $CONFIG_FILE

elif [[ $DATATYPE == "trna" ]];then

	sed -i "s/TRNA_UCSC =/TRNA_UCSC = $EXT/g" $CONFIG_FILE

elif [[ $DATATYPE == "rfam" ]];then

#	sed -i "s/NCRNA_RFAM =/NCRNA_RFAM = $RFAM_DATABASE/g" $CONFIG_FILE
	sed -i "s/NCRNA_RFAM_EX =/NCRNA_RFAM_EX = $EXT/g" $CONFIG_FILE

elif [[ $DATATYPE == "rmsk" ]];then

#	sed -i "s/NCRNA_RMSK =/NCRNA_RMSK = $RMSK_DATABASE/g" $CONFIG_FILE
	sed -i "s/NCRNA_RMSK_EX =/NCRNA_RMSK_EX = $EXT/g" $CONFIG_FILE 


elif [[ $DATATYPE == "other" ]];then
	
	# get the gff3 file
	IFS=',' read -ra gff <<< "$EXT"
	echo "${gff[0]}" | sed 's/\//\\\//g' > gff
	gff_file=$(head -n 1 gff)

	sed -i "s/OTHER_NCRNA_GFF =/OTHER_NCRNA_GFF = $gff_file/g" $CONFIG_FILE 
fi


#Build command line

## ********************************** NEW for BAM files: check if reads are grouped (or not) + change command line accordingly***************************###

#check if file is already grouped (grouped => RG = 1; not grouped => 0)
RG=`samtools view $INPUT | awk 'BEGIN {RG=1} { if ($1 !~ /^[0-9]{1,}_[0-9]{1,}$/) {RG=0 ; exit} } END { print RG}'`

if [[ $RG  == 0 ]];then # if not grouped
	# add -s processBam to do the grouping
	echo "Grouping reads..." >> $DEBUG
	COMMAND_LINE="-c $CONFIG_FILE -s processBam -s generateNcgff -s ncrnaProcess"

else
	
	# omit [-s processBam] because reads are already grouped + move ready-to-use input.bam to /bowtie_results
	echo "Reads already grouped..." >> $DEBUG
	ln -s $INPUT ${OUTPUT_PATH}/bowtie_results/input.bam
	COMMAND_LINE="-c $CONFIG_FILE -s generateNcgff -s ncrnaProcess"

fi	

#finally, add track option if demanded
if [[ $UCSC == "True" ]];then
	COMMAND_LINE="$COMMAND_LINE -s ncrnaTracks"
fi

# **************** END NEW ************************************************************************************************************************************************

#Launch ncPRO analysis

/usr/curie_ngs/ncproseq_v1.6.5/bin/ncPRO-seq $COMMAND_LINE >> $DEBUG

##***TEST

RG=`samtools view  ${OUTPUT_PATH}/bowtie_results/input.bam | awk 'BEGIN {RG=1} { if ($1 !~ /^[0-9]{1,}_[0-9]{1,}$/) {RG=0 ; exit} } END { print RG}'`
echo " RG after pre-processing = $RG" >> $DEBUG
#**** TEST


#Galaxy output handling

mv ${OUTPUT_PATH}/pipeline.log $LOG_FILE

if [[ $NORM == "True" ]];then
    if [[ $DATATYPE == "matmir" ]];then
	mv $OUTPUT_PATH/doc/mature_miRNA_${EXT}_all_samples_subfamcov_RPM.data $OUT
    elif [[ $DATATYPE == "premir" ]];then
	mv $OUTPUT_PATH/doc/precursor_miRNA_${EXT}_all_samples_subfamcov_RPM.data $OUT
    elif [[ $DATATYPE == "trna" ]];then
	mv $OUTPUT_PATH/doc/tRNA_${EXT}_all_samples_subfamcov_RPM.data $OUT
    elif [[ $DATATYPE == "rfam" ]];then
	mv $OUTPUT_PATH/doc/rfam_${EXT}_all_samples_subfamcov_RPM.data $OUT
    elif [[ $DATATYPE == "rmsk" ]];then
	mv $OUTPUT_PATH/doc/rmsk_${EXT}_all_samples_subfamcov_RPM.data $OUT
    fi
else
    if [[ $DATATYPE == "matmir" ]];then
	mv $OUTPUT_PATH/doc/mature_miRNA_${EXT}_all_samples_subfamcov.data $OUT
    elif [[ $DATATYPE == "premir" ]];then
	mv $OUTPUT_PATH/doc/precursor_miRNA_${EXT}_all_samples_subfamcov.data $OUT
    elif [[ $DATATYPE == "trna" ]];then
	mv $OUTPUT_PATH/doc/tRNA_${EXT}_all_samples_subfamcov.data $OUT
    elif [[ $DATATYPE == "rfam" ]];then
	mv $OUTPUT_PATH/doc/rfam_${EXT}_all_samples_subfamcov.data $OUT
    elif [[ $DATATYPE == "rmsk" ]];then
	mv $OUTPUT_PATH/doc/rmsk_${EXT}_all_samples_subfamcov.data $OUT
    fi
fi

if [[ $UCSC == "True" ]];then

#**** FOR NEBULA ONLY ******

gunzip $OUTPUT_PATH/ucsc/input_*_sens.bedGraph.gz 
mv $OUTPUT_PATH/ucsc/input_*_sens.bedGraph $UCSC_TRACK

fi
# ***** END FOR NEBULA ONLY *****

:<<'galaxy'

#    if [[ $NORM == "True" ]];then
#	ls -l $OUTPUT_PATH/ucsc/ | grep RPM | awk '{print $9}' > $OUTPUT_PATH/ucsc/bedGraph.gz.list
#    else
	ls -l $OUTPUT_PATH/ucsc/ | grep .bedGraph.gz | awk '{print $9}' > $OUTPUT_PATH/ucsc/bedGraph.gz.list
#    fi
	while read line
	do
	    if [[ $line != "" ]];then
		EXT=`echo ${line#*.}`
		if [[ $EXT == "bedGraph.gz" ]];then
		    OUT_NAME=`basename $line .gz | sed -e 's/\+/p/g' | sed -e 's/\-/m/g'`
		    zcat $OUTPUT_PATH/ucsc/$line > $OUTPUT_PATH/ucsc/$OUT_NAME
		fi
	    fi
	done < $OUTPUT_PATH/ucsc/bedGraph.gz.list

	#rm $OUTPUT_PATH/ucsc/bedGraph.gz.list

#	if [[ $NORM == "True" ]];then
#	    ls -l $OUTPUT_PATH/ucsc/ | grep RPM | awk '{print $9}' > $OUTPUT_PATH/ucsc/bedGraph.list
#	else
	    ls -l $OUTPUT_PATH/ucsc/ | grep .bedGraph | awk '{print $9}' > $OUTPUT_PATH/ucsc/bedGraph.list
#	fi
	echo "<p align=center><img src=html/images/ncPRO_logo.png /></p>" > $UCSC_TRACK
	echo "<p align=center>To visualize IGV tracks, first start IGV on your computer, then clic on links below:</p>" >> $UCSC_TRACK

	while read line
	do
	    if [[ $line != "" ]];then
		EXT=`echo ${line#*.}`
		if [[ $EXT == "bedGraph" || $EXT == "bed" ]];then
		    line_url=$line #`echo $line | sed 's/+/%2b/g'`
		    HTTP_PATH=`echo $OUTPUT_PATH | sed "s/\/data\/kdi_${VERSION}/http:\/\/data-kdi-${VERSION}.curie.fr\/file/g"` #this crazy thing means: replace "/data/kdi_VERSION/http" BY "/data-kdi-VERSION.curie.fr/file"
		    echo "<p align=center><a href='http://localhost:60151/load?file=$HTTP_PATH/ucsc/$line_url&genome=$GENOME&merge=true' target='_blank'>$line</a></p>" >> $UCSC_TRACK
		fi
	    fi
	done < $OUTPUT_PATH/ucsc/bedGraph.list

	#rm $OUTPUT_PATH/ucsc/bedGraph.list
fi


galaxy











