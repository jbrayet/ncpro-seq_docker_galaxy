#!/bin/bash

# I added the 'me' lines 
#assumption : a user can't begin with a fastq  file already grouped !

while getopts "i:s:n:g:m:o:f:r:h:p:l:t:a:" optionName; do
case "$optionName" in

i) INPUT+="$OPTARG,";;
s) SAMPLENAME+="$OPTARG,";;
n) PROJECTNAME="$OPTARG";;
g) GENOME="$OPTARG";;
m) RMSK="$OPTARG";;
o) BAM_OUT+="$OPTARG,";;
f) RFAM="$OPTARG";;
r) REPORT="$OPTARG";;
h) HTML_REPORT="$OPTARG";;
p) PDF_REPORT="$OPTARG";;
l) LOG_FILE="$OPTARG";;
t) INPUT_TYPE="$OPTARG";;
a) ALIGNMENT="$OPTARG";;

esac
done

##### ncPRO-seq annotation - Galaxy #####

GENOME_2=`echo $GENOME | cut -d"_" -f2`

databasePath=$(find / -type d -name database)

mkdir -p $databasePath/ncproseqAnnotation
mkdir -p $databasePath/ncproseqAnnotation/annotation
annotationPath=$databasePath/ncproseqAnnotation/annotation
[ ! -d $annotationPath/$GENOME_2 ] && wget http://sourceforge.net/projects/ncproseq/files/annotation/$GENOME.tar.gz -P $annotationPath
cd $annotationPath; tar -zxf $GENOME.tar.gz
cd $annotationPath; rm -rf $GENOME.tar.gz

#########


sampleArray=(${INPUT//,/ })
nameArray=(${SAMPLENAME//,/ })
bamArray=(${BAM_OUT//,/ })

if [[ $REPORT == "pdf" ]];then
    OUTPUT_PATH_DIR=`dirname $LOG_FILE`
    OUTPUT_PATH_NAME=`basename $LOG_FILE .dat`
else
    OUTPUT_PATH_DIR=`dirname $HTML_REPORT`
    OUTPUT_PATH_NAME=`basename $HTML_REPORT .dat`
fi

OUTPUT_PATH="${OUTPUT_PATH_DIR}/${OUTPUT_PATH_NAME}_files"



#ME
mkdir -p $OUTPUT_PATH

chmod 777 -R $OUTPUT_PATH

#VERSION=`echo $OUTPUT_PATH | cut -d"/" -f3`
#VERSION=`echo $VERSION | cut -d"_" -f2`

#DEBUG_MODE

DEBUG_MODE="on"
DEBUG="/dev/null"

if [[ $DEBUG_MODE == "on" ]];then

	DEBUG="$OUTPUT_PATH/ncPRO-QC.debug"

fi

#Deploy ncPRO directories structure

/usr/curie_ngs/ncproseq_v1.6.3/bin/ncPRO-deploy -o $OUTPUT_PATH > $DEBUG

echo "$INPUT" >> $DEBUG
echo "$SAMPLENAME" >> $DEBUG
echo "$PROJECTNAME" >> $DEBUG
echo "$GENOME_2" >> $DEBUG
echo "$RMSK" >> $DEBUG
echo "$BAM_OUT" >> $DEBUG
echo "$RFAM" >> $DEBUG
echo "$REPORT" >> $DEBUG
echo "$HTML_REPORT" >> $DEBUG
echo "$PDF_REPORT" >> $DEBUG
echo "$LOG_FILE" >> $DEBUG
echo "$INPUT_TYPE" >> $DEBUG
echo "$ALIGNMENT" >> $DEBUG
        
echo "$sampleArray" >> $DEBUG
echo "$nameArray" >> $DEBUG
echo "$bamArray" >> $DEBUG

#Go to working directory

cd $OUTPUT_PATH

rm annotation

cp -rf /usr/curie_ngs/ncproseq_v1.6.3/annotation/*.item $annotationPath
cp -rf /usr/curie_ngs/ncproseq_v1.6.3/annotation/*_items.txt $annotationPath

ln -s $annotationPath .

rm manuals

#Create symbolic link to input 
#********************************************************************************* NEW: for BAM files, check if reads in input are grouped or not and change cmd accordignly ***********
if [[ $INPUT_TYPE == "fastq" ]];then

    count=0
    for i in ${sampleArray[*]}
    do
            ln -s $i ${OUTPUT_PATH}/rawdata/${nameArray[count]}.fastq
            count=$(( $count + 1 ))
        done
fi

if [[ $INPUT_TYPE == "bam" ]];then

    count=0
    for i in ${sampleArray[*]}
        do
            ln -s $i ${OUTPUT_PATH}/rawdata/${nameArray[count]}.bam
            count=$(( $count + 1 ))
            
            #check if grouped
            RG=`samtools view $i | awk --posix 'BEGIN {RG=1} { if ($1 !~ /^[0-9]{1,}_[0-9]{1,}$/) {RG=0 ; exit} } END { print RG}'`
        done	
fi

#Edit config-ncrna.txt ##### A REFAIRE ####
CONFIG_FILE=config-ncrna.txt

sed -i "s/mm9/$GENOME/g" $CONFIG_FILE
sed -i "s/hg19/$GENOME/g" $CONFIG_FILE
sed -i "/N_CPU/c\N_CPU = 6" $CONFIG_FILE  #****** Make sure this value matches universe.ini files
sed -i "s/test_Curie/$PROJECTNAME/g" $CONFIG_FILE


for file in $annotationPath/$GENOME_2/*.gff
do
    if [[ $file == "cluster_pirna.gff"]]; then
        ANNO_CATALOG= $annotationPath/$GENOME_2/precursor_miRNA.gff $annotationPath/$GENOME_2/rfam.gff $annotationPath/$GENOME_2/cluster_pirna.gff $annotationPath/$GENOME_2/rmsk.gff $annotationPath/$GENOME_2/coding_gene.gff 
    else 
        if [[ $file == "pirna.gff"]]; then
            ANNO_CATALOG= $annotationPath/$GENOME_2/precursor_miRNA.gff $annotationPath/$GENOME_2/rfam.gff $annotationPath/$GENOME_2/pirna.gff $annotationPath/$GENOME_2/rmsk.gff $annotationPath/$GENOME_2/coding_gene.gff 
        else
            ANNO_CATALOG= $annotationPath/$GENOME_2/precursor_miRNA.gff $annotationPath/$GENOME_2/rfam.gff $annotationPath/$GENOME_2/rmsk.gff $annotationPath/$GENOME_2/coding_gene.gff 
        fi
    fi
done

sed -i "s:^ANNO_CATALOG.*$:ANNO_CATALOG = $ANNO_CATALOG:g" $CONFIG_FILE

#Build command line 

if [[ $INPUT_TYPE == "fastq" ]];then

	if [[ $ALIGNMENT == "True" ]]; then

		
		COMMAND_LINE="-c $CONFIG_FILE -s processRead -s mapGenome -s mapGenomeStat -s mapAnnOverview"

		if [[ $RFAM == "True" ]];then

			COMMAND_LINE="$COMMAND_LINE -s overviewRfam -s overviewRmsk"

		fi

	else

		COMMAND_LINE="-c $CONFIG_FILE -s processRead"

	fi

fi



#### NEW if BAM already grouped, omit [ -s processBam ] + put input.bam in /bowtie_results
if [[ $INPUT_TYPE == "bam" ]];then

	if [[ $RG = 0 ]]; then #if bam file is NOT grouped
	
		COMMAND_LINE="-c $CONFIG_FILE -s processBam -s mapGenomeStat -s mapAnnOverview"

	else 
	
            count=0
            for i in ${sampleArray[*]}
            do
                ln -s $i ${OUTPUT_PATH}/rawdata/${nameArray[count]}.bam
                count=$(( $count + 1 ))
            done	
	    COMMAND_LINE="-c $CONFIG_FILE -s mapGenomeStat -s mapAnnOverview"
	fi
	
		
	if [[ $RFAM == "True" ]];then

		COMMAND_LINE="$COMMAND_LINE -s overviewRfam -s overviewRmsk"

	fi

fi

#************************* new

##### Function to create HTML report in Galaxy ######

function createHtmlReport
{
    
    # galaxy part :

    #Reformat html output

    tr '>' '\n' < ${OUTPUT_PATH}/report.html | sed -ne "s@.*<img src='\([^']*\)'.*@\1@p" -e 's@.*<img src="\([^"]*\)".*@\1@p' > ${OUTPUT_PATH}/img_list.txt

    NC_LOGO=`head -1 ${OUTPUT_PATH}/img_list.txt`

    #HTTP_PATH=`echo $OUTPUT_PATH | sed "s/\/data\/kdi_${VERSION}/http:\/\/data-kdi-${VERSION}.curie.fr\/file/g"`

    i=1

    if [[ $INPUT_TYPE == "fastq" ]];then

    	echo "<p align=center><img src=$NC_LOGO></p><p align=center><b><u>QUALITY CONTROL</u></b></p>" > ${HTML_REPORT}
    fi

    if [[ $INPUT_TYPE == "bam" ]];then

	echo "<p align=center><img src=$NC_LOGO></p><p align=center><b><u>DATA MAPPING</u></b></p>" > $HTML_REPORT
    fi

    while read line 
    do 

	if [[ $line != "" ]];then

		if [[ $i == "3" ]];then

			ahref=`sed "s/html\/thumb/pic/" <<< $line`

			if [[ $INPUT_TYPE == "fastq" ]];then
				echo "<p align=center><b>Base Composition Information</b></p><table align=center><tr><td align=center><a href=$ahref><img src=$line></a></td>" >> $HTML_REPORT
			fi

			if [[ $INPUT_TYPE == "bam" ]];then
				echo "<p align=center><b>Mapping proportions</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi

		fi

		if [[ $i == "4" ]];then
			
			ahref=`sed "s/html\/thumb/pic/" <<< $line`

			if [[ $INPUT_TYPE == "fastq" ]];then
				echo "<td align=center><a href=$ahref><img src=$line></td></a></td><table>" >> $HTML_REPORT
			fi

			if [[ $INPUT_TYPE == "bam" ]];then
				echo "<hr width=500><p align=center><b>Distinct Reads Length Distribution</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi

		fi

		if [[ $i == "5" ]];then

			ahref=`sed "s/html\/thumb/pic/" <<< $line`

			if [[ $INPUT_TYPE == "fastq" ]];then
				echo "<hr width=500><p align=center><b>Distinct Reads Length Distribution</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi

			if [[ $INPUT_TYPE == "bam" ]];then
				echo "<hr width=500><p align=center><b>Abundant Reads Length Distribution</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi

		fi

		if [[ $i == "6" ]];then

			ahref=`sed "s/html\/thumb/pic/" <<< $line`

			if [[ $INPUT_TYPE == "fastq" ]];then
				echo "<hr width=500><p align=center><b>Quality Score</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi

			if [[ $INPUT_TYPE == "bam" ]];then
				echo "<hr size=20><p align=center style=font-size:25px;><b><u>ncRNAs OVERVIEW</u></b><p align=center><b>Reads Annotation Overview</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi

		fi

		if [[ $i == "7" ]];then

			ahref=`sed "s/html\/thumb/pic/" <<< $line`
			if [[ $INPUT_TYPE == "fastq" ]];then
				echo "<hr width=500><p align=center><b>Abundant Reads Length Distribution</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi
			if [[ $INPUT_TYPE == "bam" ]];then

				if [[ $RFAM == "True" ]];then
					echo "<p align=center><b>Precursor miRNAs Annotation</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
				else
					break
				fi
			fi
		fi

		if [[ $i == "8" ]];then

			ahref=`sed "s/html\/thumb/pic/" <<< $line`
			if [[ $INPUT_TYPE == "fastq" ]];then

				if [[ $ALIGNMENT == "True" ]]; then

					echo "<hr size=20><p align=center style=font-size:25px;><b><u>DATA MAPPING</u></b></p><p align=center><b>Mapping proportions</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
				else
					break
				fi
			fi
			if [[ $INPUT_TYPE == "bam" ]];then
			
				echo "<p align=center><b>Annotation of ncRNAs from RFAM</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi
		fi

		if [[ $i == "9" ]];then
		
			ahref=`sed "s/html\/thumb/pic/" <<< $line`
			if [[ $INPUT_TYPE == "fastq" ]];then
				echo "<hr width=500><p align=center><b>Distinct Reads Length Distribution</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
			fi

			if [[ $INPUT_TYPE == "bam" ]];then

				echo "<p align=center><b>Annotation of Repetitive Regions</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT
				break
			fi

		fi

		if [[ $i == "10" ]];then

			ahref=`sed "s/html\/thumb/pic/" <<< $line`

			echo "<hr width=500><p align=center><b>Abundant Reads Length Distribution</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT

		fi

		if [[ $i == "11" ]];then

			ahref=`sed "s/html\/thumb/pic/" <<< $line`

			echo "<hr size=20><p align=center style=font-size:25px;><b><u>ncRNAs OVERVIEW</u></b><p align=center><b>Reads Annotation Overview</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT

		fi

		if [[ $RFAM == "True" ]];then

			if [[ $i == "12" ]];then

				ahref=`sed "s/html\/thumb/pic/" <<< $line`

				echo "<p align=center><b>Precursor miRNAs Annotation</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT

			fi

			if [[ $i == "13" ]];then

				ahref=`sed "s/html\/thumb/pic/" <<< $line`

				echo "<p align=center><b>Annotation of ncRNAs from RFAM</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT

			fi

			if [[ $i == "14" ]];then

				ahref=`sed "s/html\/thumb/pic/" <<< $line`

				echo "<p align=center><b>Annotation of Repetitive Regions</b></p><p align=center><a href=$ahref><img src=$line></a></p>" >> $HTML_REPORT

			fi

		fi

		i=$(( $i + 1 ))
	
	fi


    done < ${OUTPUT_PATH}/img_list.txt

    rm ${OUTPUT_PATH}/img_list.txt
    
    
    
}


#Launch ncPRO analysis

#FAIRE une boucle pour -s hrml_builder ou -s pdf_builder

if [[ $REPORT == "all" ]];then

    
    /usr/curie_ngs/ncproseq_v1.6.3/bin/ncPRO-seq $COMMAND_LINE -s html_builder -s pdf_builder>> $DEBUG

    createHtmlReport

    cp ${OUTPUT_PATH}/Analysis_report_ncPRO-seq.pdf $PDF_REPORT

fi

if [[ $REPORT == "pdf" ]];then


    /usr/curie_ngs/ncproseq_v1.6.3/bin/ncPRO-seq $COMMAND_LINE  -s pdf_builder>> $DEBUG

    cp ${OUTPUT_PATH}/Analysis_report_ncPRO-seq.pdf $PDF_REPORT


fi

if [[ $REPORT == "html" ]];then


    /usr/curie_ngs/ncproseq_v1.6.3/bin/ncPRO-seq $COMMAND_LINE -s html_builder>> $DEBUG

    createHtmlReport

fi

#Galaxy output handling

cp ${OUTPUT_PATH}/pipeline.log $LOG_FILE

if [[ $ALIGNMENT == "True" ]];then
    
    count=0
    for i in ${bamArray[*]}
    do
        cp ${OUTPUT_PATH}/bowtie_results/${nameArray[count]/_/.}_$GENOME_2.bam $i 
        count=$(( $count + 1 ))
    done
fi
