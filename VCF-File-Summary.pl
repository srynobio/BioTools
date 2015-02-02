#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

my $usage = "

Synopsis:

        ./VCF-File-Summary.pl --vcf <file.vcf>

Description:

        Will report the total number of Reference bases, Alt Bases, and Genotypes in a given VCF file.

Required options:

        -v, --vcf       VCF file to summarize on.

\n";

my ($vcf);
GetOptions(
                "vcf|v=s" => \$vcf,
);
die $usage unless ($vcf);

print "Counting number of reference bases...\n";
print system("grep -v '^#' $vcf |perl -lane 'print \$F[3]' |sort |uniq -c|sort -rn");
print "------\n";

print "Counting number of alt  bases...\n";
print system("grep -v '^#' $vcf |perl -lane 'print \$F[4]' |sort |uniq -c|sort -rn");
print "-----\n";

print "Genotype content\n";
print system("grep -v '^#' $vcf |perl -lane 'print \$F[-1]'|perl -F: -lane 'print \$F[0]' |sort|uniq -c|sort -rn");
print "-----\n";

