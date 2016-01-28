#!/bin/bash

# Copyleft ↄ⃝ 2012 Institut Curie
# Author(s): Jocelyn Brayet, Laurene Syx, Chongjian Chen, Nicolas Servant(Institut Curie) 2012 - 2015
# Contact: bioinfo.ncproseq@curie.fr
# This software is distributed without any guarantee under the terms of the GNU General
# Public License, either Version 2, June 1991 or Version 3, June 2007.

while getopts "i:g:t:e:l:o:p:r:n:" optionName; do
case "$optionName" in

i) INPUT="$OPTARG";;
g) GENOME="$OPTARG";;
t) DATATYPE="$OPTARG";;
e) EXT="$OPTARG";;
l) LOG_FILE="$OPTARG";;
o) OUT_AB="$OPTARG";;
p) OUT_DIS="$OPTARG";;
r) ROOT_DIR="$OPTARG";;
n) PROJECTNAME="$OPTARG";;

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

/usr/curie_ngs/ncproseq_v1.6.5/bin/ncPRO-deploy -o $OUTPUT_PATH > $DEBUG

#me
chmod 777 -R $OUTPUT_PATH
#Go to working directory

cd $OUTPUT_PATH

#Create symbolic link to input and annotations

ln -s $INPUT ${OUTPUT_PATH}/rawdata/input.bam

rm annotation

ln -s $annotationPath annotation

#Edit config-ncrna.txt

CONFIG_FILE=config-ncrna.txt

sed -i "s:^BOWTIE_GENOME_REFERENCE =.*$:BOWTIE_GENOME_REFERENCE = $GENOME_2:g" $CONFIG_FILE
sed -i "s:^ORGANISM.*$:ORGANISM = $GENOME_2:g" $CONFIG_FILE

sed -i "s:^N_CPU.*$:N_CPU = 4:g" $CONFIG_FILE  #****** Make sure this value matches universe.ini files
sed -i "s:^PROJECT_NAME =.*$:PROJECT_NAME = $PROJECTNAME:g" $CONFIG_FILE


#sed -i "s/LOGFILE = pipeline.log/LOGFILE = $LOG_FILE/g" $CONFIG_FILE

if [[ -f "$annotationPath/$GENOME_2/cluster_pirna.gff" ]]
then
    ANNO_CATALOG="$annotationPath/$GENOME_2/precursor_miRNA.gff $annotationPath/$GENOME_2/rfam.gff $annotationPath/$GENOME_2/cluster_pirna.gff $annotationPath/$GENOME_2/rmsk.gff $annotationPath/$GENOME_2/coding_gene.gff"
else
    if [[ -f "$annotationPath/$GENOME_2/pirna.gff" ]]
    then
        ANNO_CATALOG="$annotationPath/$GENOME_2/precursor_miRNA.gff $annotationPath/$GENOME_2/rfam.gff $annotationPath/$GENOME_2/pirna.gff $annotationPath/$GENOME_2/rmsk.gff $annotationPath/$GENOME_2/coding_gene.gff"
    else
    ANNO_CATALOG="$annotationPath/$GENOME_2/precursor_miRNA.gff $annotationPath/$GENOME_2/rfam.gff $annotationPath/$GENOME_2/rmsk.gff $annotationPath/$GENOME_2/coding_gene.gff"
    fi
fi

sed -i "s:^ANNO_CATALOG.*$:ANNO_CATALOG = $ANNO_CATALOG:g" $CONFIG_FILE

####### Remove information in config-ncrna.txt file ###############

sed -i "s:^MATURE_MIRNA =.*$:MATURE_MIRNA =:g" $CONFIG_FILE
sed -i "s:^PRECURSOR_MIRNA =.*$:PRECURSOR_MIRNA =:g" $CONFIG_FILE
sed -i "s:^TRNA_UCSC =.*$:TRNA_UCSC =:g" $CONFIG_FILE
sed -i "s:^NCRNA_RFAM =.*$:NCRNA_RFAM =:g" $CONFIG_FILE
sed -i "s:^NCRNA_RFAM_EX =.*$:NCRNA_RFAM_EX =:g" $CONFIG_FILE
sed -i "s:^NCRNA_RMSK =.*$:NCRNA_RMSK =:g" $CONFIG_FILE 
sed -i "s:^NCRNA_RMSK_EX =.*$:NCRNA_RMSK_EX =:g" $CONFIG_FILE 
sed -i "s:^OTHER_NCRNA_GFF =.*$:OTHER_NCRNA_GFF =:g" $CONFIG_FILE 

#######################################

if [[ $DATATYPE == "matmir" ]];then

	sed -i "s/MATURE_MIRNA =/MATURE_MIRNA = $EXT/g" $CONFIG_FILE

elif [[ $DATATYPE == "premir" ]];then

	sed -i "s/PRECURSOR_MIRNA =/PRECURSOR_MIRNA = $EXT/g" $CONFIG_FILE

elif [[ $DATATYPE == "trna" ]];then

	sed -i "s/TRNA_UCSC =/TRNA_UCSC = $EXT/g" $CONFIG_FILE

elif [[ $DATATYPE == "rfam" ]];then

	sed -i "s/NCRNA_RFAM_EX =/NCRNA_RFAM_EX = $EXT/g" $CONFIG_FILE

elif [[ $DATATYPE == "rmsk" ]];then

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
echo $COMMAND_LINE >> $DEBUG
/usr/curie_ngs/ncproseq_v1.6.5/bin/ncPRO-seq $COMMAND_LINE >> $DEBUG 2>&1

#Galaxy output handling

mv ${OUTPUT_PATH}/pipeline.log $LOG_FILE


# PROFILE

if [ -f ${OUTPUT_PATH}/pic/input_*_${EXT}_abundant.png ] ; then
	convert -resize 60% ${OUTPUT_PATH}/pic/input_*_${EXT}_abundant.png $OUT_AB
else
	echo -e "Distribution of positional read coverage and the read length distribution are unavailable in this annotation family. Check the coverage profile table :\n" > $OUT_AB
	cat ${OUTPUT_PATH}/doc/${DATATYPE}_${EXT}_all_samples_scaled_basecov_abundant_all_RPM.data >> $OUT_AB
fi

if [ -f ${OUTPUT_PATH}/pic/input_*_${EXT}_distinct.png ]; then
	convert -resize 60% ${OUTPUT_PATH}/pic/input_*_${EXT}_distinct.png $OUT_DIS

else
	echo "Distribution of positional read coverage and the read length distribution are unavailable in this annotation family. Check the coverage profile table :\n" > $OUT_DIS
	cat ${OUTPUT_PATH}/doc/${DATATYPE}_${EXT}_all_samples_scaled_basecov_distinct_all_RPM.data >> $OUT_DIS

fi 
	












