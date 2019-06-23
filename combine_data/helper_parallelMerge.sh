#!/bin/bash
set -e

usage() {
	echo "Usage: bash `basename $0` files outFile mirror"
	echo ""
	echo "This script merges multiple files using a reduction method and depends on the passed in script."
	echo "The code works in a parallel fashion and will attempt to use all cores of the machine."
	echo "Files should be white-space delimited with the first two columns being coordinates with the third as the value"
	echo "NOTE: This script is used as a helper for the generate matrix & yearSplit scripts"
	echo ""
	echo "  files - A file containing a list of paths to files to merge"
	echo "  outFile - Filename of output matrix file"
	echo "  mergeScript - The script to use for merging the data"
	echo "  mirror - Whether to mirror the data across the matrix (expecting 0 or 1) - for use with coordinate based data (e.g. for a sparse matrix)"
	echo ""
}
expectedArgs=3

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Show help message if desired
if [[ $1 == "-h" || $1 == '--help' ]]; then
	usage
	exit 0
# Check for expected number of arguments
elif [[ $# -ne $expectedArgs ]]; then
	echo "ERROR: Expecting $expectedArgs arguments"
	usage
	exit 255
fi

tmpfiles=$1 # A file containing a list of paths to files to merge
outFile=$2 # The output file
#mergeScript=$3 # Script to use to merge things
mirror=$3 # Whether to mirror the output

# Move the file list to a temporary file (in case it's from a temporary file handle)
files=$(mktemp --tmpdir "files.XXXXXXXXXX")
cat $tmpfiles > $files

# update EM: creating temporary dir in /tmp for all the tmp files (any previous ./.tmp.XXXX will be /tmp/$myTmpDir/tmp.XXXX)
myTmpDir=$(mktemp --tmpdir -d "helper_parallelMerge.XXXXXXXXXX")

# Check that mirror argument is binary
if [[ $mirror -ne 0 && $mirror -ne 1 ]]; then
	echo "ERROR: mirror should be 0 or 1"
	usage
	exit 255
elif [ ! -r $mergeScript ]; then
	echo "ERROR: Unable to read merge script ($mergeScript)"
	exit 255
fi

# Double check that there are actually files to merge
totalFileCount=`cat $files | wc -l`
if [[ $totalFileCount -eq 0 ]]; then
	echo "ERROR: No files found to merge"
	exit 255
elif [[ $totalFileCount -eq 1 ]]; then
	echo "Only 1 file found. No merging required."
	singleFile=`cat $files`
	prevround=0
	cp $singleFile $myTmpDir/tmp.merged.$prevround.1
fi
echo "$totalFileCount files found for merge..."

# Next check that all the files exist
while read filename
do
	if ! [ -r $filename ]; then
		echo "ERROR: File read error. Unable to access $filename"
		exit 255
	fi
done < $files
echo "All files confirmed to exist."

# Parse the file-list into a comma-delimited variable (and remove the temporary file)
fileList=`cat $files | tr '\n' ',' | sed -e 's/,$//'`
rm $files

# Attempt to extract the number of cores on this machine
cpuCount=`grep -c ^processor /proc/cpuinfo`

# How many files should be merged at a time
filesTogether=2

# Calculate the number of rounds we'll need (for reporting use only)
totalRoundCount=`awk -v fileCount=$totalFileCount -v filesTogether=$filesTogether ' BEGIN { a=log(fileCount)/log(filesTogether)+0.5; printf("%.0f\n",a); } '`

# Now let's merge the files in a multi-step reduction approach
round=0
while true
do
	# Increment the round counters
	prevround=$round
	round=$(($round+1))

	# Check how many files we need to merge
	fileCount=`echo $fileList | tr ',' '\n' | wc -l`
	echo "DEBUG: round $round fileCount=$fileCount" 1>&2
	
	# Quit if we only need to merge one file
	if [[ $fileCount -eq 1 ]]; then
		echo "Merge has reduced data to one file: '$fileList'"
		break
	fi

	echo "Starting round $round of $totalRoundCount..."

	# Let's check the size of files so that we can balance file sizes to be merged
	echo $fileList |\
	tr ',' '\n' |\
	xargs -I FILE wc -c FILE > $myTmpDir/tmp.filesizes
	
	# Order the files by filesize forward and reverse
	sort -k1,1n $myTmpDir/tmp.filesizes | cut -f 2 -d ' ' > $myTmpDir/tmp.fileorder1
	sort -k1,1nr $myTmpDir/tmp.filesizes | cut -f 2 -d ' ' > $myTmpDir/tmp.fileorder2

	# Then interleave the file lists and removed duplicates
	paste -d '\n' $myTmpDir/tmp.fileorder1 $myTmpDir/tmp.fileorder2 |\
	awk ' { if (!($0 in a)) print $0; a[$0] = 1;} ' > $myTmpDir/tmp.filesbalanced

	# Take the list of files and group them using the $filesTogether argument
	cat  $myTmpDir/tmp.filesbalanced |\
	awk -v filesTogether=$filesTogether '{ printf("%s ", $0); a=a+1; if (a==filesTogether) { a=0; printf("\n"); } } END { if (a>0) printf("\n"); } ' > $myTmpDir/tmp.joinList

	# Take the grouped files and create a list of commands to merge the files
	a=1
	cat $myTmpDir/tmp.joinList | while read files; do
	    echo "perl $HERE/helper_merge_Nkeys.pl $files >$myTmpDir/tmp.merged.$round.$a"
	    a=$(( $a + 1 ))
	done  > $myTmpDir/tmp.commandList

	# Take the command list and execute them across multiple cores using xargs
	cat $myTmpDir/tmp.commandList |\
	tr '\n' '\0'|\
	xargs -0 -P $cpuCount -I COMMAND sh -c "COMMAND"
	

	# Clean up the files from previous rounds and other extraneous files
	# Note that these won't be deleted when we finally merge down to one file (in which case, the loop is escaped above
	rm -f $myTmpDir/tmp.merged.$prevround.*
	rm $myTmpDir/tmp.joinList
	rm $myTmpDir/tmp.commandList
	rm $myTmpDir/tmp.filesizes
	rm $myTmpDir/tmp.fileorder1
	rm $myTmpDir/tmp.fileorder2
	rm $myTmpDir/tmp.filesbalanced

	# Build a new file=list with the reduced number of output files
	fileList=$(find $myTmpDir -name "tmp.merged.$round.*" |  tr '\n' ',' | sed -e 's/,$//')
	
	echo "Completed round $round of $totalRoundCount."
done

# We have now reduced the multiple set of input files down to a single file
# This file is at $myTmpDir/tmp.merged.$prevround.1

# Let's just do a sanity check that the final file exists
if ! [ -r $myTmpDir/tmp.merged.$prevround.1 ]; then
	echo "ERROR: Cannot find final merged files. Merge has failed unexpectedly."
	exit 255
fi

echo "Processing final file..."
# If we should mirror it, do it and save it to the output path
if [[ $mirror -eq 1 ]]; then
	cat $myTmpDir/tmp.merged.$prevround.1 | awk -F $'\t' ' { print $1"\t"$2"\t"$3; print $2"\t"$1"\t"$3; } ' > $outFile
	rm $myTmpDir/tmp.merged.$prevround.1
# Otherwise just move the final file to the output path
else
	mv $myTmpDir/tmp.merged.$prevround.1 $outFile
fi
echo "Final file complete."

