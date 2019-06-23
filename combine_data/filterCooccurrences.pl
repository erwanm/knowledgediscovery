#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Getopt::Std;


my $progNamePrefix = "filterCooccurrences"; 
my $progname = "$progNamePrefix.pl";



sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <inMatrix> <occurrences> <prevMatrix> <outMatrix>\n";
	print $fh "\n";
	print $fh "\n";
	print $fh "  Main options:\n";
	print $fh "     -h print this help message\n";
	print $fh "\n";
}


# PARSING OPTIONS
my %opt;
getopts('h', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
print STDERR "4 arguments expected, but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 4);

my $inMatrix = $ARGV[0];
my $occurrences = $ARGV[1];
my $prevMatrix = $ARGV[2]; 
my $outMatrix =  $ARGV[3]; 


# load the full list from 'occurrences'
open(my $occurrencesFH,  "<", $occurrences) or die "cannot open < $occurrences: $!";
my %entities;
print STDERR "Reading entities from $occurrences... ";
my $nb=0;
while (<$occurrencesFH>) {
    chomp;
    $entities{$_} = 1;
    $nb++;
}
close($occurrencesFH);
print STDERR "$nb entities read.\n";

# load the full previous matrix
open(my $prevMatrixFH, "<", $prevMatrix) or die "cannot open < $prevMatrix: $!";
my %prevMatrix;
print STDERR "Reading prevMatrix from $prevMatrix... ";
$nb=0;
while (<$prevMatrixFH>) {
    chomp;
    my @cols = split;
    if ($cols[0] < $cols[1]) { # storing only once, relying on symetry to store only half the original number of relations
	$prevMatrix{$cols[0].":".$cols[1]} = 1;
    } else {
	$prevMatrix{$cols[1].":".$cols[0]} = 1;
    }
    $nb++;
}
close($prevMatrixFH);
print STDERR "$nb relations read from prevMatrix.\n";


open(my $inMatrixFH, "<", $inMatrix) or die "cannot open < $inMatrix: $!";
print STDERR "Reading inMatrix from $inMatrix and storing filtered relations... ";
$nb = 0;
my $nbFilterEntities=0;
my $nbFilterPrev=0;
my %res;
while (<$inMatrixFH>) {
    chomp;
    my @cols = split;
    my $key;
    if ($cols[0] < $cols[1]) {
	$key=$cols[0].":".$cols[1];
    } else {
	$key=$cols[1].":".$cols[0];
    }
    $nb++;
    if (defined($entities{$cols[0]}) && defined($entities{$cols[1]})) {
	$nbFilterEntities++;
	if (!defined($prevMatrix{$key})) {
	    $nbFilterPrev++;
	    $res{$cols[0]}->{$cols[1]} = $_;
	}
    }
}
close($inMatrixFH);
print STDERR "$nb relations read from inMatrix, $nbFilterEntities relations filtered in by entities, $nbFilterPrev final relations filtered in by removing those from prevMatrix.\n";

print STDERR "Sorting and writing results to $outMatrix... ";
open(my $outMatrixFH, ">", $outMatrix)  or die "cannot open > $outMatrix: $!";
foreach my $col1 (sort { $a <=> $b } keys %res) {
    my $subHash = $res{$col1};
    foreach my $col2 (sort { $a <=> $b } keys %$subHash) {
	print $outMatrixFH $subHash->{$col2}."\n";
    }
}
print STDERR "Done.\n";
close($outMatrixFH);
