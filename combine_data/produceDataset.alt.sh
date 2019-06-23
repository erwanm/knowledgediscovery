#!/bin/bash
set -euxo pipefail

cooccurrenceDir=$1
occurrenceDir=$2
sentenceCountDir=$3

splitYear=$4
outDir=$5

mkdir -p $outDir

cooccurrenceDir=`readlink -f $cooccurrenceDir`
occurrenceDir=`readlink -f $occurrenceDir`
sentenceCountDir=`readlink -f $sentenceCountDir`
outDir=`readlink -f $outDir`

#tmpDir=tmp.$HOSTNAME.$$.$RANDOM
tmpDir=$(mktemp -d --tmpdir produceDataset.XXXXXXXXXX) 
rm -fr $tmpDir

trainingAndValidationSplit=$splitYear
trainingSplit=$(($splitYear-1))

testSize=1000000
validationSize=$testSize

# Get directory of this script
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

###########################
# Training and Validation #
###########################

mkdir -p $tmpDir/trainingAndValidation/cooccurrences
mkdir -p $tmpDir/trainingAndValidation/occurrences
mkdir -p $tmpDir/trainingAndValidation/sentenceCounts

# generate two list of years: pre- and post- split year
find $cooccurrenceDir -type f | xargs -I FILE basename FILE | cut -f 1 -d '.' | sort -n -u | awk -v splitYear=$trainingAndValidationSplit ' { if ( $1<=splitYear) print; } ' > $tmpDir/trainingAndValidation.years
find $cooccurrenceDir -type f | xargs -I FILE basename FILE | cut -f 1 -d '.' | sort -n -u | awk -v splitYear=$trainingAndValidationSplit ' { if ( $1>splitYear) print; } ' > $tmpDir/test.years

# collect all the data files corresponding to the years before split year for the training/validation data 
cat $tmpDir/trainingAndValidation.years | xargs -I YEAR echo "find $cooccurrenceDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingAndValidationFiles.cooccurrences
cat $tmpDir/trainingAndValidation.years | xargs -I YEAR echo "find $occurrenceDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingAndValidationFiles.occurrences
cat $tmpDir/trainingAndValidation.years | xargs -I YEAR echo "find $sentenceCountDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingAndValidationFiles.sentenceCounts

# create symlinks to all the files previously collected
cat $tmpDir/trainingAndValidationFiles.cooccurrences | xargs -I FILE ln -s FILE $tmpDir/trainingAndValidation/cooccurrences/
cat $tmpDir/trainingAndValidationFiles.occurrences | xargs -I FILE ln -s FILE $tmpDir/trainingAndValidation/occurrences
cat $tmpDir/trainingAndValidationFiles.sentenceCounts | xargs -I FILE ln -s FILE $tmpDir/trainingAndValidation/sentenceCounts


# 
# find -L  -type f | perl $HERE/helper_merge_Nkeys.pl -i
find -L $tmpDir/trainingAndValidation/cooccurrences/ -type f | perl $HERE/helper_merge_Nkeys.pl -i   >$outDir/trainingAndValidation.cooccurrences
find -L $tmpDir/trainingAndValidation/occurrences -type f | perl $HERE/helper_merge_Nkeys.pl -i >$outDir/trainingAndValidation.occurrences.unfiltered
find -L $tmpDir/trainingAndValidation/sentenceCounts -type f | perl $HERE/helper_merge_Nkeys.pl -i > $outDir/trainingAndValidation.sentenceCounts

# Get the list of term IDs that actually occur in cooccurrences
cat $outDir/trainingAndValidation.cooccurrences | cut -f 1,2 -d $'\t' | tr '\t' '\n' | sort -un > $outDir/trainingAndValidation.ids

bash $HERE/filterOccurrences.sh $outDir/trainingAndValidation.occurrences.unfiltered $outDir/trainingAndValidation.ids $outDir/trainingAndValidation.occurrences
rm $outDir/trainingAndValidation.occurrences.unfiltered

python $HERE/checkFilteredOccurrences.py --occurrenceFile $outDir/trainingAndValidation.occurrences --acceptedIDs $outDir/trainingAndValidation.ids

#############
# Training  #
#############

mkdir -p $tmpDir/training/cooccurrences
mkdir -p $tmpDir/training/occurrences
mkdir -p $tmpDir/training/sentenceCounts

find $cooccurrenceDir -type f | xargs -I FILE basename FILE | cut -f 1 -d '.' | sort -n -u | awk -v splitYear=$trainingSplit ' { if ( $1<=splitYear) print; } ' > $tmpDir/training.years

cat $tmpDir/training.years | xargs -I YEAR echo "find $cooccurrenceDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingFiles.cooccurrences
cat $tmpDir/training.years | xargs -I YEAR echo "find $occurrenceDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingFiles.occurrences
cat $tmpDir/training.years | xargs -I YEAR echo "find $sentenceCountDir -type f -name 'YEAR*'" | sh > $tmpDir/trainingFiles.sentenceCounts

cat $tmpDir/trainingFiles.cooccurrences | xargs -I FILE ln -s FILE $tmpDir/training/cooccurrences/
cat $tmpDir/trainingFiles.occurrences | xargs -I FILE ln -s FILE $tmpDir/training/occurrences
cat $tmpDir/trainingFiles.sentenceCounts | xargs -I FILE ln -s FILE $tmpDir/training/sentenceCounts

find -L $tmpDir/training/cooccurrences/ -type f | perl $HERE/helper_merge_Nkeys.pl -i > $outDir/training.cooccurrences
find -L $tmpDir/training/occurrences -type f | perl $HERE/helper_merge_Nkeys.pl -i > $outDir/training.occurrences.unfiltered
find -L $tmpDir/training/sentenceCounts -type f | perl $HERE/helper_merge_Nkeys.pl -i > $outDir/training.sentenceCounts

# Get the list of term IDs that actually occur in cooccurrences
cat $outDir/training.cooccurrences | cut -f 1,2 -d $'\t' | tr '\t' '\n' | sort -un > $outDir/training.ids

bash $HERE/filterOccurrences.sh $outDir/training.occurrences.unfiltered $outDir/training.ids $outDir/training.occurrences
rm $outDir/training.occurrences.unfiltered

python $HERE/checkFilteredOccurrences.py --occurrenceFile $outDir/training.occurrences --acceptedIDs $outDir/training.ids

##############
# Validation #
##############

mkdir -p $tmpDir/validation/$splitYear/cooccurrences

ln -s $cooccurrenceDir/$splitYear* $tmpDir/validation/$splitYear/cooccurrences

find -L $tmpDir/validation/$splitYear/cooccurrences -type f | perl $HERE/helper_merge_Nkeys.pl -i >$outDir/validation.cooccurrences

perl $HERE/filterCooccurrences.pl $outDir/validation.cooccurrences $outDir/training.ids $outDir/training.cooccurrences $outDir/validation.cooccurrences.tmp
mv $outDir/validation.cooccurrences.tmp $outDir/validation.cooccurrences

python $HERE/checkFilteredCooccurrences.py --cooccurrenceFile $outDir/validation.cooccurrences --acceptedIDs $outDir/training.ids --previousCooccurrences $outDir/training.cooccurrences

########
# Test #
########

cp $outDir/trainingAndValidation.cooccurrences $outDir/tracking.cooccurrences
for testYear in `cat $tmpDir/test.years`
do
	mkdir -p $tmpDir/testing/$testYear/cooccurrences
	#mkdir -p $tmpDir/testing/$testYear/occurrences
	#mkdir -p $tmpDir/testing/$testYear/sentenceCounts

	ln -s $cooccurrenceDir/$testYear* $tmpDir/testing/$testYear/cooccurrences
	#ln -s $occurrenceDir/$testYear* $tmpDir/testing/$testYear/occurrences
	#ln -s $sentenceCountDir/$testYear* $tmpDir/testing/$testYear/sentenceCounts
	
	find -L $tmpDir/testing/$testYear/cooccurrences -type f | perl $HERE/helper_merge_Nkeys.pl -i >$outDir/testing.$testYear.cooccurrences.unfiltered

        perl $HERE/filterCooccurrences.pl $outDir/testing.$testYear.cooccurrences.unfiltered $outDir/trainingAndValidation.ids $outDir/tracking.cooccurrences $outDir/testing.$testYear.cooccurrences

	python $HERE/checkFilteredCooccurrences.py --cooccurrenceFile $outDir/testing.$testYear.cooccurrences --acceptedIDs $outDir/trainingAndValidation.ids --previousCooccurrences $outDir/tracking.cooccurrences

	sort -R $outDir/testing.$testYear.cooccurrences > $outDir/testing.$testYear.cooccurrences.randomOrder
	head -n $testSize $outDir/testing.$testYear.cooccurrences.randomOrder | sort -k1,1n -k2,2n > $outDir/testing.$testYear.subset.$testSize.cooccurrences
	rm $outDir/testing.$testYear.cooccurrences.randomOrder

	mkdir $tmpDir/tmpMerge
	ln -s $outDir/tracking.cooccurrences $tmpDir/tmpMerge/
	ln -s $outDir/testing.$testYear.cooccurrences $tmpDir/tmpMerge/

	find -L $tmpDir/tmpMerge/ -type f | perl $HERE/helper_merge_Nkeys.pl -i >$outDir/tracking.cooccurrences.tmp
	
	mv $outDir/tracking.cooccurrences.tmp $outDir/tracking.cooccurrences
	rm -fr $tmpDir/tmpMerge
done

# Now we make the combined version of all the test cooccurrences
find -L "$outDir/testing.*.cooccurrences" -type f | perl $HERE/helper_merge_Nkeys.pl -i >$outDir/testing.all.cooccurrences

# Now we subset the combined test cooccurrences
sort -R $outDir/testing.all.cooccurrences > $outDir/testing.all.cooccurrences.randomOrder
head -n $testSize $outDir/testing.all.cooccurrences.randomOrder | sort -k1,1n -k2,2n > $outDir/testing.all.subset.$testSize.cooccurrences
rm $outDir/testing.all.cooccurrences.randomOrder

# We also subset the validation cooccurrences
sort -R $outDir/validation.cooccurrences > $outDir/validation.cooccurrences.randomOrder
head -n $validationSize $outDir/validation.cooccurrences.randomOrder | sort -k1,1n -k2,2n > $outDir/validation.subset.$validationSize.cooccurrences
rm $outDir/validation.cooccurrences.randomOrder

# Lastly we're going to make one epic cooccurrences for everything
mkdir $tmpDir/all.cooccurrences
find $outDir -type f -name 'testing.*.unfiltered' | xargs -I FILE ln -s FILE $tmpDir/all.cooccurrences/
ln -s $outDir/trainingAndValidation.cooccurrences $tmpDir/all.cooccurrences/
find -L $tmpDir/all.cooccurrences -type f | perl $HERE/helper_merge_Nkeys.pl -i >$outDir/all.cooccurrences

# And calculate the appropriate IDs for that set
cat $outDir/all.cooccurrences | cut -f 1,2 -d $'\t' | tr '\t' '\n' | sort -un > $outDir/all.ids

rm -fr $tmpDir

