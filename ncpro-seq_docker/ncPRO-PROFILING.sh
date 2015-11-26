#!/bin/bash


# here GROUP_READ = 1 ===> two types of profiling graph (abundant and distinct)

while getopts "i:g:t:d:e:l:o:p:" optionName; do
case "$optionName" in

i) INPUT="$OPTARG";;
g) GENOME="$OPTARG";;
t) DATATYPE="$OPTARG";;
d) DATABASE="$OPTARG";;
e) EXT="$OPTARG";;
l) LOG_FILE="$OPTARG";;
o) OUT_AB="$OPTARG";;
p) OUT_DIS="$OPTARG";;

esac
done


OUTPUT_PATH_DIR=`dirname $OUT_AB`
OUTPUT_PATH_NAME=`basename $OUT_AB .dat`

OUTPUT_PATH="${OUTPUT_PATH_DIR}/${OUTPUT_PATH_NAME}_files"

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

/bioinfo/local/curie/ngs-data-analysis/ncPRO-seq/bin/ncPRO-deploy -o $OUTPUT_PATH > $DEBUG

#me
chmod 777 -R $OUTPUT_PATH
#Go to working directory

cd $OUTPUT_PATH

#Create symbolic link to input and annotations

ln -s $INPUT ${OUTPUT_PATH}/rawdata/input.bam
rm annotation
ln -s /bioinfo/local/curie/ngs-data-analysis/annotation .

#Edit config-ncrna.txt

CONFIG_FILE=config-ncrna.txt

sed -i "s/mm9/$GENOME/g" $CONFIG_FILE
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

echo "building the command line" >> $DEBUG

#Build command line
## ****************************************************************** NEW : check if reads are grouped and change command line accordingly********

RG=`samtools view $INPUT | awk --posix 'BEGIN {RG=1} { if ($1 !~ /^[0-9]{1,}_[0-9]{1,}$/) {RG=0 ; exit} } END { print RG}'`

if [[ $RG  = 0 ]]; then # if not grouped
	
	# add -s processBam to do the grouping
	COMMAND_LINE="-c $CONFIG_FILE -s processBam -s generateNcgff -s ncrnaProcess"

else

	# eliminate [-s processBam] because reads are already grouped + move input.bam
	ln -s $INPUT ${OUTPUT_PATH}/bowtie_results/input.bam 
	COMMAND_LINE="-c $CONFIG_FILE -s generateNcgff -s ncrnaProcess"
fi

echo "cmd : $COMMAND_LINE" >> $DEBUG
# **************** END NEW *******************************************************************************************************************************

#Launch ncPRO analysis
echo "cmd : /bioinfo/projects_prod/ncpro/bin/ncproseq_v1.5.1/bin/ncPRO-seq $COMMAND_LINE" >> $DEBUG
/bioinfo/local/curie/ngs-data-analysis/ncPRO-seq/bin/ncPRO-seq $COMMAND_LINE >> $DEBUG 2>&1

#Galaxy output handling

mv ${OUTPUT_PATH}/pipeline.log $LOG_FILE


# PROFILE

if [ -f ${OUTPUT_PATH}/pic/input_*_${EXT}_abundant.png ] ; then
	convert -resize 60% ${OUTPUT_PATH}/pic/input_*_${EXT}_abundant.png $OUT_AB
	#mv ${OUTPUT_PATH}/pic/input_*_${EXT}_abundant.png $OUT_AB
else
	echo -e "Distribution of positional read coverage and the read length distribution are unavailable in this annotation family. Check the coverage profile table :\n" > $OUT_AB
	cat ${OUTPUT_PATH}/doc/${DATATYPE}_${EXT}_all_samples_scaled_basecov_abundant_all_RPM.data >> $OUT_AB
fi

if [ -f ${OUTPUT_PATH}/pic/input_*_${EXT}_distinct.png ]; then
	convert -resize 60% ${OUTPUT_PATH}/pic/input_*_${EXT}_distinct.png $OUT_DIS
	#mv ${OUTPUT_PATH}/pic/input_*_${EXT}_distinct.png $OUT_DIS

else
	echo "Distribution of positional read coverage and the read length distribution are unavailable in this annotation family. Check the coverage profile table :\n" > $OUT_DIS
	cat ${OUTPUT_PATH}/doc/${DATATYPE}_${EXT}_all_samples_scaled_basecov_distinct_all_RPM.data >> $OUT_DIS

fi 
	












