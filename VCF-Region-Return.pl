#!/usr/bin/env perl
use strict;
use warnings;
use Tabix;
use autodie;
use Getopt::Long;

my $usage = "

        Synopsis:
		./VCF-Region-Return.pl --vcf <vcf file> --region <output from Venn-CF.pl txt file> --output <output file>

        Description:

                Script will take .txt outputs from Venn-CF.pl script and create a GFF file of regions in file.

        Required options

                -v, --vcf	Input VCF file.
		-r, --region	.txt region list file from Venn-CF.pl 
		-o, --output	Name/path of region VCF file.

	Additional options
		-f, --found	Will print to STDOUT a list of what was found.
\n";

my ($vcf, $region, $output, $found);
GetOptions(
    "vcf|v=s"    => \$vcf,
    "region|r=s" => \$region,
    "output|o=s" => \$output,
    "found|f"    => \$found,
);
die $usage unless ( $vcf and $region and $output );

open( my $FILE, '<',  $region );
open( my $OUT,  '+>', $output );

my $tabx = "$vcf.gz";
if ( $vcf !~ /gz$/ and ! -e $tabx ) {
    print "creating tabix index file\n";
    print "running bgzip on $vcf...\n";
    `bgzip -c $vcf > $tabx`;
    print "running tabix on file $tabx\n";
    `tabix -p vcf $tabx`;
}
print "collecting vcf records\n";

my $tab = Tabix->new( -data => $tabx );

foreach my $inter (<$FILE>) {
    chomp $inter;
    my @intervals = split /:/, $inter;
    my ( $chr, $start, $end ) = @intervals[ 0, 1, 1 ];

    my $iter = $tab->query( $chr, $start - 1, $end + 1 );

    while ( my $read = $tab->read($iter) ) {

        # just report
        print $OUT $read, "\n";

        my @found      = split /\t/, $read;
        my $ref_length = length $found[3];
        my $alt_length = length $found[4];

        # what was found
        printf( "%s:%s -> %s:%s\t%s\t%s\n",
            $intervals[0], $intervals[1], $found[0], $found[1], $found[3],
            $found[4] 
	) if $found;
    }
}

