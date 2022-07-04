# NAME

ega\_csv2json: A script that parses EGA metadata files and serializes it to json/hash data structures.

# SYNOPSIS

ega\_csv2json.pl -i &lt;file.csv> \[-options\]

     Arguments:                       
       -i|input                       Metadata txt, csv or tsv file

     Options:
       -f|format                      Output format [>json|hash]
       -h|help                        Brief help message
       -man                           Full documentation
       -debug                         Print debugging (from 1 to 5, being 5 max)
       -verbose                       Verbosity on

# CITATION

To be defined.

# SUMMARY

ega\_csv2json: A script that parses EGA metadata files and serializes it to json/hash data structures.

# HOW TO RUN EGA\_CSV2JSON

The script runs on Linux (tested on Debian-based distribution). Perl 5 is installed by default on Linux, 
but you might need to install a few CPAN modules.

First we install cpanminus (with sudo privileges):

    $ sudo apt-get install cpanminus

Then the modules:

    $ cpanm --sudo --installdeps .

If you prefer to install the CPAN modules in the directory of the application we recommend using the module `Carton`

    $ cpanm --sudo Carton

And then execute this command:

    $ carton install

For executing ega\_csv2json you will need:

- Input file

    Uncompressed CSV, TSV, or TXT file.

    Please note that this script is a proof-of-concept and we are aware that it does not parse well all files (e.g., multivalue cells).

**Examples:**

    $ ./ega_csv2json.pl -i file.csv > file.json

    $ $path/ega_csv2json.pl -i file.csv -format hash > file.txt

    $ carton exec -- ./ega_csv2json.pl -i file.csv > file.json # If using Carton

# AUTHOR 

Written by Manuel Rueda, PhD. Info about EGA can be found at [https://ega-archive.org/](https://ega-archive.org/).

# REPORTING BUGS

Report bugs or comments to <manuel.rueda@crg.eu>.

# COPYRIGHT

This PERL file is copyrighted. See the LICENSE file included in this distribution.
