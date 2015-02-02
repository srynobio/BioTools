#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

my $usage = "

Synopsis:

	./Filter_GATK.pl --vcf <file.vcf>
	./Filter_GATK.pl --vcf <file.vcf> --snp --output <filtered.vcf>
	./Filter_GATK.pl --vcf <file.vcf> --indel --output <filtered.vcf>

Description:

	Designed to create a filtered VCF file from a GATK call set
	to allow clean comparison between different data sets or downstream analysis.
	Especially helpful in filter genotypes of individuals removed from population sets.

	How VCF file is filtered.
	1 - Filtered on PASS.
	2 - All homozygous and no-call genotypes are removed.
		current genotypes kept:
		0/1, 1/0. 1/1, 0|1, 1|0, 1|1.

Required options:

	-v, --vcf	VCF file to filter on.
	-o, --output	File name for new VCF file.

Additional options:

	-s, --snp	This option will only output lines with alt lengths of one. [DEFAULT]
	-i, --indel	This option will only output lines with alt lengths greater then one.
	-d, --depth	Allows filtering above given depth [DEFAULT 0]
	-np, --non-pass	Allow non-PASS record to be included.
\n";

my ( $vcf, $output, $snp, $indel, $depth, $np );
GetOptions(
		"vcf|v=s" => \$vcf,
		"output|o=s" => \$output,
		"snp|s"	=> \$snp,
		"indel|i" => \$indel,
		"depth|d=s" => \$depth,
		"non-pass|np" => \$np
);
die $usage unless ($vcf and $output);

# set up defaultsi.
my $type = ($indel) ? 'indel' : 'snp';

open(my $VCF, '<', $vcf);
open(my $OUT, '>', $output);

foreach my $line (<$VCF>) {
	chomp $line;

	if ( $line =~ /^#/ ) {
		print $OUT $line, "\n";
		next;
	}
	my @parts = split /\t/, $line;

	# remove non-pass lines
	unless ($np) {
		next unless ( $parts[6] eq 'PASS');
	}

	if ( $depth ) {
		next unless ($parts[5] >= $depth);
	}

	my @info = split /:/, $parts[9];

	my $het1   = '0/1';
	my $het2   = '1/0';
	my $homoz  = '1/1';
	my $hetpz  = '0|1';
	my $het1pz = '1|0';
	my $het2pz = '1|1';
	next unless ( $info[0] eq $het1 or $info[0] eq $het2 or $info[0] eq $homoz or 
			$info[0] eq $hetpz or $info[0] eq $het1pz or $info[0] eq $het2pz);

	if ( $type eq 'snp' ) {
		next if ( length $parts[3] > 1 );
		if ( $parts[4] =~ /\,/ ) {
			my @calls = split /\,/, $parts[4];
			foreach my $alt ( @calls ) {
				if ( length $alt eq '1' ) {
					print $OUT $line, "\n";
					next;
				}
				else { next }
			}
		}
		elsif ( length $parts[4] <= 1 ) {
			print $OUT $line, "\n";
		}
	}
	if ( $type eq 'indel' ) {
		next if ( length $parts[4] <= 1 );
		if ( $parts[4] =~ /\,/ ) {
			my @calls = split /\,/, $parts[4];
			foreach my $alt ( @calls ) {
				if ( length $alt > 1) {
					print $OUT $line, "\n";
					next;
				}
				else { next }
			}
		}
		elsif ( length $parts[4] > 1 ) {
			print $OUT $line, "\n";
		}
	}
}

close $VCF;
close $OUT;

