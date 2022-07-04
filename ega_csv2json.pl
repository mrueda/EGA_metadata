#!/usr/bin/env perl
#
#   Script to parse EGA metadata text files
#   The output can be hash|json
#
#   Last Modified: March/22/2021
#
#   Version 0.0.1
#
#   Copyright (C) 2021 Manuel Rueda (manuel.rueda@crg.eu)
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, see <https://www.gnu.org/licenses/>.
#
#   If this program helps you in your research, please cite.

use strict;
use warnings;
use autodie;
use feature qw(say);
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use Data::Dumper;
use Statistics::Descriptive;
use Text::CSV_XS;
use Scalar::Util qw(looks_like_number);
use JSON::XS;

#### Main ####
ega_csv2json();
##############
exit;

sub ega_csv2json {

    # Defining a few variables
    my $version = '0.0.1';
    my $DEFAULT = '.';
    my $format  = 'json';    # Default value

    # Reading arguments
    GetOptions(
        'input|i=s'  => \my $filein,                               # string
        'format|f=s' => \$format,                                  # string
        'help|?'     => \my $help,                                 # flag
        'man'        => \my $man,                                  # flag
        'debug=i'    => \my $debug,                                # integer
        'verbose'    => \my $verbose,                              # flag
        'version|v'  => sub { say "$0 Version $version"; exit; }
    ) or pod2usage(2);
    pod2usage(1)                              if $help;
    pod2usage( -verbose => 2, -exitval => 0 ) if $man;
    pod2usage(
        -message => "Please specify a valid input file -i <in>\n",
        -exitval => 1
    ) if ( !-f $filein );
    pod2usage(
        -message => "Please specify a valid format -f hash|json\n",
        -exitval => 1
    ) unless ( $format eq 'json' || $format eq 'hash' );

    # Define split record separator
    my @exts = qw(.csv .tsv .txt);
    my ( undef, undef, $ext ) = fileparse( $filein, @exts );

    #########################################
    #     START READING CSV|TSV|TXT FILE    #
    #########################################
    open my $fh_in, '<:encoding(utf8)', $filein;

    # We'll read the header to assess separators in <txt> files
    chomp( my $tmp_header = <$fh_in> );

    # Defining separator
    my $separator =
        $ext eq '.csv'       ? ','
      : $ext eq '.tsv'       ? "\t"
      : $tmp_header =~ m/\t/ ? "\t"    # .txt can have either
      :                        ' ';    # .txt can have either

    # Defining variables
    my $datain = {};
    my $csv    = Text::CSV_XS->new(
        {
            binary    => 1,
            auto_diag => 1,
            sep_char  => $separator
        }
    );

    # Loading header fields into $header
    $csv->parse($tmp_header);
    my $header = [ $csv->fields() ];

    # Now proceed with the rest of the file
    while ( my $row = $csv->getline($fh_in) ) {

        # We store the data as an HoA $datain
        for my $i ( 0 .. $#{$header} ) {
            push @{ $datain->{ $header->[$i] } }, $row->[$i];
        }
    }

    close $fh_in;
    #########################################
    #     END READING CSV|TSV|TXT FILE      #
    #########################################

    # Transform the data => $datain to $dataout
    my $dataout = {};

    # For all header fields we process its contents and filter out suspicious data
    for ( my $i = 0 ; $i <= $#{$header} ; $i++ ) {

        # Get rid of NA values
        @{ $datain->{ $header->[$i] } } =
          grep { $_ ne 'NA' } @{ $datain->{ $header->[$i] } };

        # Check if array is numeric or string by looking at element[0]
        my $value = @{ $datain->{ $header->[$i] } }[0];
        if ( looks_like_number($value) ) {

            # We keep NUMBERS ONLY
            @{ $datain->{ $header->[$i] } } =
              grep { looks_like_number($_) } @{ $datain->{ $header->[$i] } };

            # We send data to Statistics::Descriptive as a ref and load $dataout
            my $stat = Statistics::Descriptive::Full->new();
            $stat->add_data( @{ $datain->{ $header->[$i] } } );
            $dataout->{ $header->[$i] }{mean}   = $stat->mean();
            $dataout->{ $header->[$i] }{sd}     = $stat->standard_deviation();
            $dataout->{ $header->[$i] }{count}  = $stat->count();
            $dataout->{ $header->[$i] }{per25}  = $stat->percentile(25);
            $dataout->{ $header->[$i] }{per75}  = $stat->percentile(75);
            $dataout->{ $header->[$i] }{min}    = $stat->min();
            $dataout->{ $header->[$i] }{max}    = $stat->max();
            $dataout->{ $header->[$i] }{median} = $stat->median();
            $dataout->{ $header->[$i] }{sum}    = $stat->sum();
        }

        # If array is not numeric
        else {

            # We store occurences in a hash
            my %h;
            for my $key ( @{ $datain->{ $header->[$i] } } ) {
                $h{$key}++;
            }

            # Now we delete keys w/ values < $threshold
            my $total = scalar @{ $datain->{ $header->[$i] } };
            @{ $dataout->{ $header->[$i] } }{count} = $total;
            my $threshold = int( $total / 10 );
            for my $key ( keys %h ) {
                delete $h{$key} if $h{$key} < $threshold;
            }

            # And we finally add the values to $dataout
            @{ $dataout->{ $header->[$i] } }{count} =
              scalar @{ $datain->{ $header->[$i] } };
            @{ $dataout->{ $header->[$i] } }{'ocurrences_gt_10%'} = \%h;
        }
    }

    #############################################
    #  PRINTING ACCORDING TO USER PARAMETERS    #
    #############################################

    # Serialize the data structure to the desired format
    if ( $format eq 'hash' ) {
        $Data::Dumper::Sortkeys = 1;    # In alphabetic order
        print Dumper $dataout;
    }
    elsif ( $format eq 'json' ) {
        my $coder = JSON::XS->new->utf8->canonical->pretty;
        my $json  = $coder->encode($dataout);
        print $json;
    }

    #########
    #  END  #
    #########
    say "Finished OK" if ( $debug || $verbose );
}

=head1 NAME

ega_csv2json: A script that parses EGA metadata files and serializes it to json/hash data structures.


=head1 SYNOPSIS


ega_csv2json.pl -i <file.csv> [-options]

     Arguments:                       
       -i|input                       Metadata txt, csv or tsv file

     Options:
       -f|format                      Output format [>json|hash]
       -h|help                        Brief help message
       -man                           Full documentation
       -debug                         Print debugging (from 1 to 5, being 5 max)
       -verbose                       Verbosity on


=head1 CITATION

To be defined.

=head1 SUMMARY

ega_csv2json: A script that parses EGA metadata files and serializes it to json/hash data structures.

=head1 HOW TO RUN EGA_CSV2JSON

The script runs on Linux (tested on Debian-based distribution). Perl 5 is installed by default on Linux, 
but you might need to install a few CPAN modules.

First we install cpanminus (with sudo privileges):

   $ sudo apt-get install cpanminus

Then the modules:

   $ cpanm --sudo --installdeps .

If you prefer to install the CPAN modules in the directory of the application we recommend using the module C<Carton>

   $ cpanm --sudo Carton

And then execute this command:

   $ carton install

For executing ega_csv2json you will need:

=over

=item Input file

Uncompressed CSV, TSV, or TXT file.

Please note that this script is a proof-of-concept and we are aware that it does not parse well all files (e.g., multivalue cells).

=back

B<Examples:>

   $ ./ega_csv2json.pl -i file.csv > file.json

   $ $path/ega_csv2json.pl -i file.csv -format hash > file.txt

   $ carton exec -- ./ega_csv2json.pl -i file.csv > file.json # If using Carton


=head1 AUTHOR 

Written by Manuel Rueda, PhD. Info about EGA can be found at L<https://ega-archive.org/>.


=head1 REPORTING BUGS

Report bugs or comments to <manuel.rueda@crg.eu>.


=head1 COPYRIGHT

This PERL file is copyrighted. See the LICENSE file included in this distribution.

=cut
