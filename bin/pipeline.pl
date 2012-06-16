#!/usr/bin/env perl

=head1 NAME

pipeline.pl - pipeline running interface

=head1 SYNOPSIS

B<pipeline.pl> [B<--version> | [B<-?|-h|--help>] | [B<-g|--debug>] |
   B<[--graphviz> | B<[-c|--config> file | [B<[-d|--directory> value] |
   B<[-i|--input> string| B<[-it|--itype> string |
   [B<[--start> value] | [B<[--stop> value]

  pipeline.pl -config t/data/string_manipulation.yml -d /tmp/test

=head1 DESCRIPTION

For internal details of the pipeline, check the documentation for the
perl module L<Pipeline::Simple>.

=head1 OPTIONS

=over 7

=item B<-v | --version>

Print out a line with the program name and version number.

=item B<-? | -h | --help>

Show this help.

=item B<-g | --debug>

Print out the unix command line equivalent of the pipeline and exit.

Reports parsing and logical errors.

=item B<--graphviz>

Print out a graphviz dot file.

Example one liner to display a graph of the pipeline: 

  pipeline.pl -config t/data/string_manipulation.yml -graph > \ 
  /tmp/p.dot; dot -Tpng /tmp/p.dot| display

=item B<-c | --config> string

Path to the config file. Required.

=item B<-d | --directory> string

Directory to keep all files. Required.?

If the directory does not exist, it will be created and a copy of the
config file will be copied in it under name C<config.yml>. For
subsequent runs, the config file can be omitted from the command
line. This makes it easy to adjust the parameters.

=item B<-i | --input> string

Optional input to pipeline.

=item B<-it | --itype> string

Type of the optional input. Values?

=item B<--start> string

Name of the step to start or restart the pipeline.

Fails if the prerequisites of the step are not met, i.e. the input
file(s) does not exist.

=item B<--stop> string

Name of the step to stop the pipeline. Defaults to the last step.

=item B<--verbose> int

Verbosity level. Defaults to zero. This will get translated to
Log::Log4perl levels: 

  verbose   =  -1    0     1     2
  log level =  DEBUG INFO  WARN  ERROR


=cut

use Pipeline::Simple;
use Getopt::Long;
use Carp;

use strict;
use warnings;

use constant PROGRAMME_NAME => 'pipeline.pl';
use constant VERSION => '0.4';

# raising $OUTPUT_AUTOFLUSH flag to get immediate reporting
$| = 1;

# catch interuptions cleanly
$SIG{'INT'} = 'CLEANUP';
sub CLEANUP { exit(1) }


our $DEBUG = '';
our $CONFIG = '';
our $DIR = '.';
our $GRAPHVIZ;
our $INPUT = '';
our $ITYPE  =  '';
#our $CONTINUE; # not implemented yet
our $START  =  '';
our $STOP  =  '';
our $VERBOSE;

GetOptions(
           'v|version'     => sub{ print PROGRAMME_NAME, ", version ", VERSION, "\n";
				   exit(1); },
           'g|debug'       => \$DEBUG,
           'c|config:s'    => \$CONFIG,
           'd|directory:s' => \$DIR,
           'i|input:s'     => \$INPUT,
           'it|itype:s'    => \$ITYPE,
	   'graphviz'      => \$GRAPHVIZ,
#	   'continue'      => \$CONTINUE,
	   'start:s'       => \$START,
	   'stop:s'        => \$STOP,
	   'verbose:i'     => \$VERBOSE,
           'h|help|?'      => sub{ exec('perldoc',$0); exit(0) },
           );


my %args;
$args{config} = $CONFIG if $CONFIG;
$args{dir}   = $DIR;
$args{input} = $INPUT if $INPUT;
$args{itype} = $ITYPE if $ITYPE;
$args{start} = $START if $START;
$args{stop}  = $STOP  if $STOP;
$args{verbose} = $VERBOSE  if $VERBOSE;

unless (-e "$DIR/config.yml" or $CONFIG ) {
    croak "ERROR: Need either explicit config file or ".
	"it has to be found the working directory\n"
}

my $p = Pipeline::Simple->new(%args);

print $p->graphviz and exit if $GRAPHVIZ;
$p->stringify and exit if $DEBUG;

$p->run();
