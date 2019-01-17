# Script for running containment filtering and wtdbg2 on high-error readset

BINDIR=`dirname $(readlink -f "$0")`

#javac $BINDIR/*.java

WTDIR='/scratch/groups/mschatz1/mkirsche/hashing/wtdbg2'

if [ "$#" -eq 6 ]; then
    READS_FILE=$1
    W1=$2
    K1=$3
    W2=$4
    K2=$5
    CT=$6
else
    echo 'Usage: ./filter_pb_np.sh <reads_file> <w1> <k1> <w2> <k2> <ct>'
    echo 'Example: ./filter_pb_np.sh chr22.fastq 5 12 50 18 25'
    exit
fi

java -Xmx128000M -cp "${BINDIR}" PB_FilterContainedReads $READS_FILE w1=$W1 k1=$K1 w2=$W2 k2=$K2 ct=$CT
ofn=`java -cp "${BINDIR}" PB_FilterContainedReads $READS_FILE w1=$W1 k1=$K1 w2=$W2 k2=$K2 ct=$CT fnonly`
java -cp "${BINDIR}" ExtractReads $ofn $READS_FILE

NEW_READS_FILE=$ofn'.fastq'
STATS_FILE=$WTDIR'/'$NEW_READS_FILE'.stats'

echo 'New reads file: '$NEW_READS_FILE

$WTDIR/wtdbg2 -t 16 -i $NEW_READS_FILE -L 5000 --rescue-low-cov-edges -fo $WTDIR'/'$NEW_READS_FILE
gunzip -f $WTDIR'/'$NEW_READS_FILE'.ctg.lay.gz'; 
$WTDIR/wtpoa-cns -t 16 -i $WTDIR'/'$NEW_READS_FILE'.ctg.lay' -fo $WTDIR'/'$NEW_READS_FILE'.ctg.lay.fa'

java -cp "${BINDIR}" AssemblyStats $WTDIR'/'$NEW_READS_FILE'.ctg.lay.fa' | tee $STATS_FILE

numlines=`wc -l $NEW_READS_FILE`
echo 'Number of lines in new read file: '$numlines | tee -a $STATS_FILE

echo 'Params: w1='$W1', w2='$W2', k1='$K1', k2='$K2', ct='$CT | tee -a $STATS_FILE

