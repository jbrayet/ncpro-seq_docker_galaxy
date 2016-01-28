#!/bin/bash

# Copyleft ↄ⃝ 2012 Institut Curie
# Author(s): Jocelyn Brayet, Laurene Syx, Chongjian Chen, Nicolas Servant(Institut Curie) 2012 - 2015
# Contact: bioinfo.ncproseq@curie.fr
# This software is distributed without any guarantee under the terms of the GNU General
# Public License, either Version 2, June 1991 or Version 3, June 2007.

while getopts "i:g:t:e:l:u:v:o:a::n:r:p:" optionName; do
case "$optionName" in

i) INPUT="$OPTARG";;
g) GENOME="$OPTARG";;
t) DATATYPE="$OPTARG";;
e) EXT="$OPTARG";;
l) LOG_FILE="$OPTARG";;
u) UCSC="$OPTARG";;
v) UCSC_TRACK="$OPTARG";;
o) OUT="$OPTARG";;
a) OUT_ALL="$OPTARG";;
n) NORM="$OPTARG";;
r) ROOT_DIR="$OPTARG";;
p) PROJECTNAME="$OPTARG";;


esac
done

##### ncPRO-seq annotation - Galaxy #####

GENOME_2=`echo $GENOME | cut -d"_" -f2`

databasePath=$ROOT_DIR/database/files

mkdir -p $databasePath/ncproseqAnnotation
mkdir -p $databasePath/ncproseqAnnotation/annotation
annotationPath=$databasePath/ncproseqAnnotation/annotation
echo $annotationPath
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

echo "ln -s $annotationPath annotation"

ln -s $annotationPath annotation

#Create symbolic link to input

ln -s $INPUT ${OUTPUT_PATH}/rawdata/input.bam

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

	sed -i "s:^MATURE_MIRNA =.*$:MATURE_MIRNA = $EXT:g" $CONFIG_FILE

elif [[ $DATATYPE == "premir" ]];then

	sed -i "s:^PRECURSOR_MIRNA =.*$:PRECURSOR_MIRNA = $EXT:g" $CONFIG_FILE

elif [[ $DATATYPE == "trna" ]];then

	sed -i "s:^TRNA_UCSC =.*$:TRNA_UCSC = $EXT:g" $CONFIG_FILE

elif [[ $DATATYPE == "rfam" ]];then

	sed -i "s:^NCRNA_RFAM_EX =.*$:NCRNA_RFAM_EX = $EXT:g" $CONFIG_FILE

elif [[ $DATATYPE == "rmsk" ]];then

	sed -i "s:^NCRNA_RMSK_EX =.*$:NCRNA_RMSK_EX = $EXT:g" $CONFIG_FILE 


elif [[ $DATATYPE == "other" ]];then
	
	# get the gff3 file
	IFS=',' read -ra gff <<< "$EXT"
	echo "${gff[0]}" | sed 's/\//\\\//g' > gff
	gff_file=$(head -n 1 gff)

	sed -i "s:^OTHER_NCRNA_GFF =.*$:OTHER_NCRNA_GFF = $gff_file:g" $CONFIG_FILE 
fi


#Build command line

## ********************************** NEW for BAM files: check if reads are grouped (or not) + change command line accordingly***************************###

#check if file is already grouped (grouped => RG = 1; not grouped => 0)
RG=`samtools view $INPUT | awk --posix 'BEGIN {RG=1} { if ($1 !~ /^[0-9]{1,}_[0-9]{1,}$/) {RG=0 ; exit} } END { print RG}'`

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
echo $COMMAND_LINE >> $DEBUG

/usr/curie_ngs/ncproseq_v1.6.5/bin/ncPRO-seq $COMMAND_LINE >> $DEBUG

##***TEST

RG=`samtools view  ${OUTPUT_PATH}/bowtie_results/input.bam | awk --posix 'BEGIN {RG=1} { if ($1 !~ /^[0-9]{1,}_[0-9]{1,}$/) {RG=0 ; exit} } END { print RG}'`
echo " RG after pre-processing = $RG" >> $DEBUG
#**** TEST


#Galaxy output handling

mv ${OUTPUT_PATH}/pipeline.log $LOG_FILE

if [[ $NORM == "True" ]];then
    if [[ $DATATYPE == "matmir" ]];then
        if [[ ! -z "$OUT_ALL" ]];then
            mv $OUTPUT_PATH/doc/mature_miRNA_${EXT}_all_samples_subfamcov_RPM_all_miRNA.data $OUT_ALL
            mv $OUTPUT_PATH/doc/mature_miRNA_${EXT}_all_samples_subfamcov_RPM.data $OUT
	else
            mv $OUTPUT_PATH/doc/mature_miRNA_${EXT}_all_samples_subfamcov_RPM.data $OUT
        fi
    elif [[ $DATATYPE == "premir" ]];then
        if [[ ! -z "$OUT_ALL" ]];then
            mv $OUTPUT_PATH/doc/precursor_miRNA_${EXT}_all_samples_subfamcov_RPM_all_miRNA.data $OUT_ALL
            mv $OUTPUT_PATH/doc/precursor_miRNA_${EXT}_all_samples_subfamcov_RPM.data $OUT
        else
            mv $OUTPUT_PATH/doc/precursor_miRNA_${EXT}_all_samples_subfamcov_RPM.data $OUT
        fi
    elif [[ $DATATYPE == "trna" ]];then
	mv $OUTPUT_PATH/doc/tRNA_${EXT}_all_samples_subfamcov_RPM.data $OUT
    elif [[ $DATATYPE == "rfam" ]];then
	mv $OUTPUT_PATH/doc/rfam_${EXT}_all_samples_subfamcov_RPM.data $OUT
    elif [[ $DATATYPE == "rmsk" ]];then
	mv $OUTPUT_PATH/doc/rmsk_${EXT}_all_samples_subfamcov_RPM.data $OUT
    fi
else
    if [[ $DATATYPE == "matmir" ]];then
        if [[ ! -z "$OUT_ALL" ]];then
            mv $OUTPUT_PATH/doc/mature_miRNA_${EXT}_all_samples_subfamcov_all_miRNA.data $OUT_ALL
	    mv $OUTPUT_PATH/doc/mature_miRNA_${EXT}_all_samples_subfamcov.data $OUT
        else
            mv $OUTPUT_PATH/doc/mature_miRNA_${EXT}_all_samples_subfamcov.data $OUT
        fi
    elif [[ $DATATYPE == "premir" ]];then
        if [[ ! -z "$OUT_ALL" ]];then
            mv $OUTPUT_PATH/doc/precursor_miRNA_${EXT}_all_samples_subfamcov_all_miRNA.data $OUT_ALL
            mv $OUTPUT_PATH/doc/precursor_miRNA_${EXT}_all_samples_subfamcov.data $OUT
        else
            mv $OUTPUT_PATH/doc/precursor_miRNA_${EXT}_all_samples_subfamcov.data $OUT
        fi
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

rm -rf $OUTPUT_PATH

