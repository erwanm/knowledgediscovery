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



#
# Erwan Moreau Jan 2020, based on 'knowledgediscovery' code by Jack Lever
#
# This script reads a dir of medline xml files as extracted by Jack Lever's system and for each PMID writes the list
# of associated Mesh descriptors, together with the value for 'MajorTopicYN' as follows:
#
# Updated later: added columns <pmid> <year> <pmid version> <journal> <title> <mesh list> 
#
# 10277409        D005845|N,D006268|Y,D006273|Y,D006739|Y,D006786|N,D014481|N
# 10277408        D006749|N,D014481|N
# 10277410        D001154|Y,D001265|N,D003615|Y,D006757|Y,D006801|N,D009146|Y,D014481|N
# 10277411        D006761|Y,D009722|N,D014146|N,D014481|N,D014492|N
# 10277412        D003256|N,D006280|N,D007348|N,D014481|N
# 10277413        D002983|N,D006264|N,D006279|N,D007348|N,D011243|N,D014481|N
# 10277414        D002170|N,D003219|Y,D006748|N,D008500|N,D010344|Y,D010817|Y,D014481|N
# 10277415        D006761|Y,D007258|Y,D009864|N,D010344|Y
# 10277416        D002170|N,D004992|Y,D010344|N,D014481|N
# 10277417        D002170|N,D003284|N,D005376|N,D006739|N,D008505|N,D012237|N

	
# Code for extracting text from Medline/PMC XML files

# XML elements to ignore the contents of
ignoreList = ['table', 'table-wrap', 'xref', 'disp-formula', 'inline-formula', 'ref-list', 'bio', 'ack', 'graphic', 'media', 'tex-math', 'mml:math', 'object-id', 'ext-link']

# XML elements to separate text between
separationList = ['title', 'p', 'sec', 'break', 'def-item', 'list-item', 'caption']


# Some older articles have titles like "[A study of ...]."
# This removes the brackets while retaining the full stop
def removeWeirdBracketsFromOldTitles(titleText):
        titleText = titleText.strip()
        if titleText[0] == '[' and titleText[-2:] == '].':
                titleText = titleText[1:-2] + '.'
        return titleText


# Code for extracting text from Medline/PMC XML files
def extractTextFromElem(elem):
	textList = []
	
	# Extract any raw text directly in XML element or just after
	head = ""
	if elem.text:
		head = elem.text
	tail = ""
	if elem.tail:
		tail = elem.tail
	
	# Then get the text from all child XML nodes recursively
	childText = []
	for child in elem:
		childText = childText + extractTextFromElem(child)
		
	# Check if the tag should be ignore (so don't use main contents)
	if elem.tag in ignoreList:
		return [tail.strip()]
	# Add a zero delimiter if it should be separated
	elif elem.tag in separationList:
		return [0] + [head] + childText + [tail]
	# Or just use the whole text
	else:
		return [head] + childText + [tail]
	

# Merge a list of extracted text blocks and deal with the zero delimiter
def extractTextFromElemList_merge(list):
	textList = []
	current = ""
	# Basically merge a list of text, except separate into a new list
	# whenever a zero appears
	for t in list:
		if t == 0: # Zero delimiter so split
			if len(current) > 0:
				textList.append(current)
				current = ""
		else: # Just keep adding
			current = current + " " + t
			current = current.strip()
	if len(current) > 0:
		textList.append(current)
	return textList
	
# Main function that extracts text from XML element or list of XML elements
def extractTextFromElemList(elemList):
	textList = []
	# Extracts text and adds delimiters (so text is accidentally merged later)
	if isinstance(elemList, list):
		for e in elemList:
			textList = textList + extractTextFromElem(e) + [0]
	else:
		textList = extractTextFromElem(elemList) + [0]

	# Merge text blocks with awareness of zero delimiters
	mergedList = extractTextFromElemList_merge(textList)
	
	# Remove any newlines (as they can be trusted to be syntactically important)
	mergedList = [ text.replace('\n', ' ') for text in mergedList ]
	
	return mergedList
	


	
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
			# Try to extract the pmidID
			pmidText = ''
			if len(pmid) > 0:
				pmidText = " ".join( [a.text.strip() for a in pmid if a.text ] )

                        # added: extract PMID Version field
                        pmidVersion = " ".join( [ e.attrib['Version'] for e in pmid ] )

                        meshDescriptors = elem.findall('./MeshHeadingList/MeshHeading/DescriptorName')
                        meshIds = ",".join([ meshDescr.attrib['UI']+"|"+meshDescr.attrib['MajorTopicYN']  for meshDescr in meshDescriptors ])

                        yearFields = elem.findall('./Article/Journal/JournalIssue/PubDate/Year')
                        medlineDateFields = elem.findall('./Article/Journal/JournalIssue/PubDate/MedlineDate')
                        # Try to extract the publication date
                        pubYear = 0
                        if len(yearFields) > 0:
                                pubYear = yearFields[0].text
                        if len(medlineDateFields) > 0:
                                pubYear = medlineDateFields[0].text[0:4]

                        titleElem = elem.findall('./Article/ArticleTitle')
                        titleText0 = extractTextFromElemList(titleElem)
                        titleText1 = [ removeWeirdBracketsFromOldTitles(t) for t in titleText0 ]
                        titleText = ' '.join(titleText1)

                        # Extract journal title
                        journalElem = elem.findall('./Article/Journal/Title')
                        journalText0 = extractTextFromElemList(journalElem)
                        journalText1 = [ removeWeirdBracketsFromOldTitles(t) for t in journalText0 ]
                        journalText = ' '.join(journalText1)

                        outFile.write("%s\t%s\t%s\t%s\t%s\t%s\n" % (pmidText, pubYear, pmidVersion, journalText, titleText, meshIds  ))
			
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
	


