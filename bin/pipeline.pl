#!/usr/bin/env perl

=head1 NAME

pipeline.pl - pipeline running interface

=head1 SYNOPSIS

B<obogrep> [B<--version> | [B<-?|-h|--help>] | [B<-g|--debug>] |
   [B<[-d|--directory> value] | B<[-c|--config> |


=head1 DESCRIPTION

For more, check the documetation in the perl module 'Pipeline'



Extract matching entries form obo format files.

  -v, --invert-match

    Invert the sense of matching, to select non-matching lines.  (-v
    is specified by POSIX.)

=cut

use Pipeline;
use Getopt::Long;
use Carp;

use constant PROGRAMME_NAME => 'pipeline.pl';
use constant VERSION => '0.3';

# catch interuptions cleanly
$SIG{'INT'} = 'CLEANUP';
sub CLEANUP { exit(1) }


our $DEBUG = '';
our $CONFIG = '';
our $DIR = '.';
our $GRAPHVIZ;
our $INPUT = '';
our $ITYPE  =  '';
#our $CONTINUE;
our $START  =  '';
our $STOP  =  '';

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
           'h|help|?'      => sub{ exec('perldoc',$0); exit(0) },
           );


#croak "Needed arguments --input and --itype" unless $INPUT and $ITYPE;

my %args;
$args{config} = $CONFIG if $CONFIG;
$args{dir} = $DIR;
$args{input} = $INPUT if $INPUT;
$args{itype} = $ITYPE if $ITYPE;
$args{start} = $START if $START;
$args{stop}  = $STOP  if $STOP;
#use Data::Dumper; print Dumper \%args; exit;

my $p = Pipeline->new(%args);

print $p->graphviz and exit if $GRAPHVIZ;
$p->stringify and exit if $DEBUG;

$p->run() unless $DEBUG;

#use Data::Dumper;
#print Dumper $p;

END {

    exit if $GRAPHVIZ or $DEBUG;
    $p->log;

}
