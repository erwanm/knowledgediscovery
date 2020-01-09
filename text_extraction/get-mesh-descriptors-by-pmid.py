import sys
import fileinput
import argparse
import time
import itertools

import re
import HTMLParser
import unicodedata
import xml.etree.cElementTree as etree
import os.path
import codecs
import pickle
from collections import defaultdict
from os import listdir
from os.path import isfile, join


	
# Code for extracting text from Medline/PMC XML files

# XML elements to ignore the contents of
ignoreList = ['table', 'table-wrap', 'xref', 'disp-formula', 'inline-formula', 'ref-list', 'bio', 'ack', 'graphic', 'media', 'tex-math', 'mml:math', 'object-id', 'ext-link']

# XML elements to separate text between
separationList = ['title', 'p', 'sec', 'break', 'def-item', 'list-item', 'caption']
	
# Process a MEDLINE abstract file
# Pass in the file object, the mode to parse it with and whether to merge the output
def processAbstractFile(abstractFile, outFile):
	count = 0

	# These XML files are huge, so skip through each MedlineCitation element using etree
	for event, elem in etree.iterparse(abstractFile, events=('start', 'end', 'start-ns', 'end-ns')):
		if (event=='end' and elem.tag=='MedlineCitation'):

			count = count + 1
			
			# Find the elements for the PubMed ID, and publication date information
			pmid = elem.findall('./PMID')
                        meshDescriptors = elem.findall('./MeshHeadingList/MeshHeading/DescriptorName')


                        meshIds = ",".join([ meshDescr.attrib['UI'] for meshDescr in meshDescriptors ])

			# Try to extract the pmidID
			pmidText = ''
			if len(pmid) > 0:
				pmidText = " ".join( [a.text.strip() for a in pmid if a.text ] )

#                        print pmidText
 #                       print meshIds
				
                        outFile.write("%s\t%s\n" % (pmidText, meshIds  ))
			
			# Important: clear the current element from memory to keep memory usage low
			elem.clear()
			
	
	
		
# It's the main bit. Yay!
if __name__ == "__main__":

	# Arguments for the command line
	parser = argparse.ArgumentParser(description='Reads an "abstract dir" (normally the "unfilteredMedline" dir) and prints for each PMID the list of its Mesh descriptors.')
	parser.add_argument('--abstractsDir',  help='MEDLINE dir containing files containing abstracts data')
	parser.add_argument('--outFile', type=argparse.FileType('w'), help='File to output stuff')

	args = parser.parse_args()
	
	# Output execution information
	if args.abstractsDir:
		print "--abstractsDir", args.abstractsDir
        else:
                print "Must provide arg abstractsDir"
                print "COMMAND: " + " ".join(sys.argv)
                raise

	if args.outFile:
		print "--outFile", args.outFile.name
        else:
                print "Must provide arg outFile"
                print "COMMAND: " + " ".join(sys.argv)
                raise


	# If loading terms from a text file, close the handle so that it be re-opened
	# with a Unicode codec later
		
	startTime = time.time()

	# And now we try to process either an abstract file, single article file or multiple
	# article files
	try:
		if args.abstractsDir:
                        myfile = codecs.open(args.outFile.name, "w", "utf-8")
                        for f in listdir(args.abstractsDir):
                                fullFile=join(args.abstractsDir,f)
                                if isfile(fullFile):
                                        print fullFile
                                        processAbstractFile(fullFile, myfile)
                        myfile.close()
	except:
		print "Unexpected error:", sys.exc_info()[0]
		print "COMMAND: " + " ".join(sys.argv)
		raise

	endTime = time.time()
	duration = endTime - startTime
	print "Processing Time: ", duration
	
	# Print completion if we were working on an outFile
	if args.outFile:
		print "Finished output to:", args.outFile.name
	


