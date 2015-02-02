#!/usr/bin/env perl
use strict;
use warnings;
use Tabix;
use IO::File;
use Getopt::Long;

my $usage = "

	Synopsis:
		./VCF-GFFregion-Return.pl --venn_results uniq_1.txt --gff_gz ref_GRCh37.gff3.gz --out results.gff

	Description:
	
		Script will take .txt outputs from Venn-CF.pl script and create a GFF file of regions in file.

	Required options 

		-vn, --venn_results	: output from Venn-CF.pl 
		-gz, --gff_gz		: tabix indexed GFF file (tabix required).
		-o,  --output		: output file name for new GFF file of positons found.

\n";

my ( $venn, $gff, $output );
GetOptions(
    "venn_result|vn=s" => \$venn,
    "gff_gz|gz=s"      => \$gff,
    "output|o=s"       => \$output,
);
die $usage unless ( $venn and $gff and $output );

my $FH  = IO::File->new( $venn,   'r' ) or die;
my $OUT = IO::File->new( $output, 'w' ) or die;
my $tab = Tabix->new( -data => $gff ) or die;

foreach my $pos (<$FH>) {
    chomp $pos;

    my ( $chr, $loc ) = split ":", $pos;
    my $iter = $tab->query( $chr, $loc - 1, $loc + 1 );

    while ( my $read = $tab->read($iter) ) {
        print $OUT $read, "\n";
    }
}

$FH->close;
$OUT->close;

