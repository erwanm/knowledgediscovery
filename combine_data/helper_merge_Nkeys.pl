#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Getopt::Std;


my $progNamePrefix = "helper_merge_Nkeys"; 
my $progname = "$progNamePrefix.pl";

my $stdin=0;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <input file 1> <input file 2> ...\n";
	print $fh "\n";
	print $fh "  Reads lines <key1> ... <keyN> <value> from all the input files, sums the values\n";
	print $fh "  by group of keys <key1> ... <keyN> and prints this to STDOUT.\n";
	print $fh "  Note: can take as input any number of keys including zero keys (simple sum).\n";
	print $fh "\n";
	print $fh "  Main options:\n";
	print $fh "     -h print this help message\n";
	print $fh "     -i reads the list of files from STDIN instead of giving them as arguments.\n";
	print $fh "\n";
}


# PARSING OPTIONS
my %opt;
getopts('hi', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
$stdin = defined($opt{i});
usage(*STDOUT) && exit 0 if $opt{h};

my @files;
if (!$stdin) {
    print STDERR "at least 1 argument expected, but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) < 1);
    @files = @ARGV;
} else {
    @files = <STDIN>;
    chomp(@files);
}

my %h;
my $nbKeys;
for my $in (@files) {
    open(my $inFH,  "<", $in) or die "cannot open < $in: $!";
    while (<$inFH>) {
	chomp;
	my @cols = split;
	if (defined($nbKeys)) {
	    die "Error: different number of columns in file '$in', expected ".($nbKeys+1)." but found ".scalar(@cols).": $!" if ($nbKeys + 1 != scalar(@cols));
	} else {
	    $nbKeys = scalar(@cols) - 1;
	}
	my $val = pop(@cols);
	die "Error: undefined last column in $in: $!" if (!defined($val));
	$h{join("\t", @cols)} += $val;
    }
    close($inFH);
}



#open(my $outFH, ">", $out)  or die "cannot open > $out: $!";

foreach my $key (sort keys %h) {
    print "$key\t$h{$key}\n";
}
#close($outFH);
