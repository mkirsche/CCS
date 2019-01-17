BINDIR=`dirname $(readlink -f "$0")`
WORKINGDIR=`pwd`
javac $BINDIR/*.java
javac $BINDIR/../src/*.java

skipfilter=0
skipassembly=0

usage() 
{ 
    echo "Usage: $0 -r <readfile> -g <refgenome> -t <readtype> -p <paramsfile> -o <outdir> -b <buscolineage> [-c -l <genome length>]" 1>&2;
    echo "  readtype has value pacbio, nanopore, or ccs" 1>&2;
    echo "  -c is an option for using the Canu assembler" 1>&2;
    echo "  If using Canu, the following parameter is also needed: " 1>&2;
    echo "    -l <genome length>" 1>&2
    exit 1; 
}

assembler='wtdbg2'

while getopts r:g:t:p:c:l:o:b:skipfilter:skipassembly: option
do
    case "${option}"
        in
        c) assembler='canu';;
        o) outdir=${OPTARG};;
        r) readfile=${OPTARG};;
        t) readtype=${OPTARG};;
        l) length=${OPTARG};;
        p) paramsfile=${OPTARG};;
        g) ref=${OPTARG};;
        b) buscolineage=${OPTARG};;
        skipfilter) skipfilter=1;;
        skipassembly) skipassembly=1;;
    esac
done

outdir=$WORKINGDIR/$outdir

if [ $skipassembly -eq 1 ]; then
    skipfilter=1
fi

echo 'readfile: '$readfile
echo 'readtype: '$readtype
echo 'reference: '$ref
echo 'assembler: '$assembler
echo 'paramsfile: '$paramsfile
echo 'outdir: '$outdir
echo 'busco lineage: '$buscolineage
echo 'skip filter?: '$skipfilter
echo 'skip assembly?: '$skipassembly

if [ -z "${outdir}" ] || [ -z "${readfile}" ] || [ -z "${readtype}" ] || [ -z "${paramsfile}" ] || [ -z "${ref}" ] || [ -z "${buscolineage}" ]; then
    usage
fi

if [ -d $outdir ]; then
    rm -r $outdir
fi

mkdir $outdir
mkdir $outdir'/assemblies'
mkdir $outdir'/readsets'
mkdir $outdir'/assemblyruns'
mkdir $outdir'/stats'

cp $ref $outdir'/assemblies/ref.fa'

# Iterate over sets of parameters and perform filtering for each
if [ $skipfilter -eq "0" ]; then
    while read p; 
    do 
        echo $p;
        if [ "$readtype" = "ccs" ]; then
            newreadsfile=`../src/filter_ccs.sh $readfile $p`
        else
            newreadsfile=`../src/filter_pb_np.sh $readfile $p`
        fi
        
        echo 'New reads file: '$newreadsfile
        
        if [ -e $newreadsfile ]; then
            mv $newreadsfile $outdir'/readsets'
        fi
    done < $paramsfile
fi

cd $outdir'/assemblyruns'

# Go through readsets and perform an assembly for each
if [ $skipassembly -eq 0 ]; then
    for i in in `ls $outdir'/readsets'`; do
        echo 'Assembling '$i
        if [ "$assembler" = "canu" ]; then
            if [ "$readtype" = "ccs" ]; then
                crt='pacbio-corrected'
            elif [ "$readtype" = "pacbio" ]; then
                crt='pacbio-raw'
            else
                crt='nanopore-raw'
            fi
            $BINDIR/../src/assemble.sh -r $outdir'/readsets/'$i -o $i -c -t $crt -l $length
        else
            $BINDIR/../src/assemble.sh -r $outdir'/readsets/'$i -o $i
        fi
    done
fi

cd $WORKINGDIR

# Move all of the assemblies into the same folder
if [ "$assembler" = "canu" ]; then
    cp $outdir'/assemblyruns/canu*/*.fasta' $outdir'/assemblies'
else
    cp $outdir'/assemblyruns/wtdbg2_assemblies/*.fa' $outdir'/assemblies'
fi

#Evaluate all of the assemblies
cd $outdir'/stats'
$BINDIR'/eval_all.sh' ../assemblies ../assemblies/ref.fa $buscolineage

cd $WORKINGDIR
java -cp $BINDIR TableMaker $outdir'/assemblies' $outdir'/stats' > $outdir/results.out 
