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
use constant VERSION => '0.1';


our $DEBUG = '';
our $CONFIG = '';
our $DIR = '.';

GetOptions(
           'v|version'     => sub{ print PROGRAMME_NAME, ", version ", VERSION, "\n";
				   exit(1); },
           'g|debug'       => \$DEBUG,
           'c|config:s'    => \$CONFIG,
           'd|directory:s' => \$DIR,
           'h|help|?'      => sub{ exec('perldoc',$0); exit(0) },
           );


croak "Needed argument --config" unless $CONFIG;


my $p = Pipeline->new(config=> $CONFIG, dir => $DIR);
$p->run;
