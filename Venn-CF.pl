#!/usr/bin/perl
use warnings;
use strict;
use Carp;
use FileHandle;
use Venn::Chart;
use Getopt::Long;

my $usage = "

	Synopsis:
		./Venn-CF.pl -v sub_1k_genomes.vcf -v sub_population_run.vcf -l 1k -l population
		./Venn-CF --clean 

	Description:
		
		Venn-CF.pl

		Script will take two to three VCF files and create a venn diagram of intersections and unique positions. 
		Script will also output a histogram of the same results.

		Currently their is two levels of position detail avaliable to the user.

		1 - Comparison based on chr and position:
			i.e. 1:760811

		2 - Finer comparison based on chr, positon, variant sequence and reference sequence.
			i.e. 1:565827:T:C

		** Script assumes files are sorted on position **

	Required options 
		
		--vcfs|v    <path to VCF file>			: Up to three allowed.
		--legends|l <legends used to label data sets>	: Up to three allowed, must match file count.
		
	Additional options:
		--output|o	  : Requested output name, default to Venn.png.
		--width|w  <int>  : Width of venn diagram, default 1000.
		--height|h <int>  : Weight of venn diagram, default 1000.
		--title|t 	  : Title name of venn diagram.
		--add_seq|as	  : Flag to use comparison two (above), default is comparison one.
		--clean|c   	  : Flag to clean all *txt and *.png files.

\n";

my ( $vcfs, $legends, $add_seq, $output, $width, $height, $title, $clean );
GetOptions(
    "vcfs|v=s@"    => \$vcfs,
    "legends|l=s@" => \$legends,
    "add_seq|as"   => \$add_seq,
    "output|o=s"   => \$output,
    "width|w=i"    => \$width,
    "height|h=i"   => \$height,
    "title|t=s"    => \$title,
    "clean|c"      => \$clean,
);

## clean and DIE
if ($clean) {
    `rm -f *png *txt`;
    croak "Cleaned up!\n";
}

## A little QA.
unless ( $vcfs and $legends ) { croak "Two files and legends required! $usage\n" }
if ( scalar @$vcfs < 2 )    { croak "Venn requires two or more files $usage\n" }
if ( scalar @$legends < 2 ) { croak "Venn requires two or more legends $usage\n" }
if ( scalar @$vcfs != scalar @$legends ) {
    croak "Each files does not have a matching legend. $usage\n";
}
$height //= '1000';
$width  //= '1000';
$title  //= 'Your Venn run';
$output //= 'Venn.png';

my $intervals;
foreach my $file ( @{$vcfs} ) {
    chomp $file;

    my $parts = vcf_split($file);
    push @{$intervals}, $parts;
}

## start the venn object work
my $venn_chart = Venn::Chart->new( $height, $width )
  or croak "Problem creating Venn object $@\n";
$venn_chart->set_options( -title => $title );

## seed the venn
if ( scalar @$intervals == '2' ) {
    $venn_chart->set_legends( shift @$legends, shift @$legends );
    my $gd_venn = $venn_chart->plot( shift @$intervals, shift @$intervals );

    open my $fh_venn, '>', $output or die("Unable to create png file\n");
    binmode $fh_venn;
    print {$fh_venn} $gd_venn->png;
    close $fh_venn or die('Unable to close file');

    # get uniqs and report
    my @ref_lists = $venn_chart->get_list_regions();

    my $report = {
        unique_1         => $ref_lists[0],
        unique_2         => $ref_lists[1],
        intersection_1_2 => $ref_lists[2],
    };
    report_regions($report);

    ## and histogram
    my $gd_histogram = $venn_chart->plot_histogram;

    open my $fh_histo, '>', "Venn_histogram_$output"
      or croak('Unable to create histogram file');
    binmode $fh_histo;
    print {$fh_histo} $gd_histogram->png;
    close $fh_histo or die('Unable to close histogram file');
}
elsif ( scalar @$intervals == '3' ) {
    $venn_chart->set_legends(
        shift @$legends,
        shift @$legends,
        shift @$legends
    );
    my $gd_venn = $venn_chart->plot(
        shift @$intervals,
        shift @$intervals,
        shift @$intervals
    );

    open my $fh_venn, '>', $output or die("Unable to create png file\n");
    binmode $fh_venn;
    print {$fh_venn} $gd_venn->png;
    close $fh_venn or die('Unable to close file');

    # get uniqs and report
    my @ref_lists = $venn_chart->get_list_regions();

    my $report = {
        unique_1         => $ref_lists[0],
        unique_2         => $ref_lists[1],
        intersection_1_2 => $ref_lists[2],
        unique_3         => $ref_lists[3],
        intersection_3_1 => $ref_lists[4],
        intersection_3_2 => $ref_lists[5],
        intersection_all => $ref_lists[6],
    };
    report_regions($report);

    ## and histogram
    my $gd_histogram = $venn_chart->plot_histogram;

    open my $fh_histo, '>', "Venn_$output"
      or croak('Unable to create histogram file');
    binmode $fh_histo;
    print {$fh_histo} $gd_histogram->png;
    close $fh_histo or die('Unable to close histogram file');

}
else { croak "Maximum number of data sets to use in three\n" }

#---------------------------------------------------
#---------------------------------------------------

sub vcf_split {
    my $file = shift;

    my $FH = FileHandle->new( $file, 'r' ) or croak "Can't open file $file\n";

    my @position;
    foreach my $line (<$FH>) {
        chomp $line;
        next if ( $line =~ /^#/ );
        my @parts = split( "\t", $line );

        my $pos     = "$parts[0]:$parts[1]";
        my $pos_seq = "$parts[0]:$parts[1]:$parts[3]:$parts[4]";

        ($add_seq)
          ? push @position, $pos_seq,
          : push @position, $pos;
    }
    $FH->close;
    return \@position;
}

#---------------------------------------------------

sub report_regions {
    my $report = shift;

    my $FH = FileHandle->new;
    foreach my $list ( keys %{$report} ) {
        $FH->open("> $list.txt");
        map { print $FH $_, "\n" } @{ $report->{$list} };
        $FH->close;
    }
    return;
}

#---------------------------------------------------

