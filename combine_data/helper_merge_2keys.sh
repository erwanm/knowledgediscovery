#!/bin/bash
set -e

usage() {
	echo "Usage: cat FILES | bash `basename $0`"
	echo ""
	echo "This script merges data from STD IN containing triples for use as a sparse matrix"
	echo "Files should be white-space delimited with the first two columns being coordinates with the third as the value"
	echo "The output (to STD OUT) will not be binarized."
	echo "NOTE: This script is used as a helper for the generate matrix & yearSplit scripts"
	echo ""
	echo "  cat FILES - Example command to pipe multiple files into script"
	echo ""
}
expectedArgs=0

# Show help message if desired
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
	usage
	exit 0
# Check for expected number of arguments
elif [ $# -ne $expectedArgs ]; then
	echo "ERROR: Expecting $expectedArgs arguments"
	usage
	exit 255
fi

# Awk command that builds a dictionary using the input (to identify overlapping coordinates) and outputs the merged data with counts
# for example:
#
# input data:
# 1 4 8
# 2 7 4
# 1 4 9
# 3 6 1
#
# expected output (may be in different order)
# 1 4 17
# 2 7 4
# 3 6 1
awk '{ key=$1"\t"$2; dict[key]=dict[key]+$3; } END { for (d in dict) print d"\t"dict[d] } '

