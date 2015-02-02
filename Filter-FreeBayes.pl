#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

my $usage = "

Synopsis:

	./Filter_FreeBayes.pl --vcf <file.vcf>
	./Filter_FreeBayes.pl --vcf <file.vcf> --snp --output <filtered.vcf>
	./Filter_FreeBayes.pl --vcf <file.vcf> --indel --output <filtered.vcf>

Description:

	Designed to create a filtered VCF file from a FreeBayes call set
	to allow clean comparison between different data sets or downstream analysis.

	How VCF file is filtered.
	1 - A few different programs are required to filter FreeBayes sets.
		1 - vcfallelicprimitives
		2 - vcffilter
	Both available here: https://github.com/ekg/vcflib
	Both programs need to be found by a PATH search.

	2 - All homozygous and no-call genotypes are removed.
		current genotypes kept:
		0/1, 1/0. 1/1, 0|1, 1|0, 1|1.

Required options:

	-v, --vcf	VCF file to filter on.
	-o, --output	File name for new VCF file.
	-tp, --tmp_path	Path to write temp files. [DEFAULT /tmp]

Additional options:

	-s, --snp	This option will only output lines with alt lengths of one. [DEFAULT]
	-i, --indel	This option will only output lines with alt lengths greater then one.

\n";

my ( $vcf, $output, $snp, $indel, $tpath );
GetOptions(
		"vcf|v=s" => \$vcf,
		"output|o=s" => \$output,
		"snp|s"	=> \$snp,
		"indel|i" => \$indel,
		"tp|tmp_path=s" => \$tpath
);
die $usage unless ($vcf and $output);
$tpath //= '/tmp/';

# run vcflib
program_check();
my $f_vcf = run_vcflib_tools();

# set up defaultsi.
my $type = ($indel) ? 'indel' : 'snp';

open(my $VCF, '<', $f_vcf);
open(my $OUT, '>', $output);

foreach my $line (<$VCF>) {
	chomp $line;

	if ( $line =~ /^#/ ) {
		print $OUT $line, "\n";
		next;
	}
	my @parts = split /\t/, $line;
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

print "cleaning up...\n";
`rm $f_vcf`; 
close $VCF;
close $OUT;
print "Done!\n";

###------------------------------------------------------------------------###

sub program_check {
	print "check for required software...\n";
	my $prim  = system("vcfallelicprimitives -h 2> /tmp/check");
	my $vcffilter = system("vcffilter -h 2> /tmp/check");
	
	unless ( $prim == 0 and $vcffilter == 0 ) {
		die "vcfallelicprimitives and/or vcffilter not found\n";
	}
	`rm /tmp/check`;
}

###------------------------------------------------------------------------###

sub run_vcflib_tools {
	my $prim = $tpath . 'primitive.vcf';
	my $filt = $tpath . 'filtered.vcf';

	my $cmd1 = "vcfallelicprimitives $vcf > $prim\n";
	print "Starting vcfallelicprimitives step using the following command:
		$cmd1\n";
	system($cmd1);

	my $cmd2 = "vcffilter -f \"QUAL > 1 & QUAL / AO > 10 & SAF > 0 & SAR > 0 & RPR > 1 & RPL > 1\" $prim > $filt";
	print "Starting vcffilter step useing the following command:
		$cmd2\n";
	system($cmd2);
	`rm $prim`;
	
	return $filt;
}

###------------------------------------------------------------------------###
