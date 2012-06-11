# -*-Perl-*- mode (for emacs)
use Test::More tests => 8;
use Data::Dumper;
use File::Spec;

BEGIN {
      use_ok( 'Pipeline::Simple' );
}

sub test_input_file {
    return File::Spec->catfile('t', 'data', @_);
}

diag( "Testing Pipeline::Simple run from file" );


# reading in a configuration
my $dir = "/tmp/pl$$";

my $pl = Pipeline::Simple->new
   (config=>test_input_file('string_manipulation.yml'),
    dir=>$dir, verbose=> -1);
#    verbose=> 1);
#print Dumper $pl;
#print Dumper $pl->next;
ok $pl->dir() eq $dir, 'dir()';
my $string = $pl->stringify;
#print $string;
ok $string =~ /# ->/, 'stringify()';
ok $pl->each_step, 'each_step';
ok $pl->run, 'run()';
#print Dumper $pl;
my $dot = $pl->graphviz;
ok $dot =~ /^digraph /, 'graphviz()';

ok $pl->start('s3'), 'start()';
ok $pl->stop('s4'), 'stop()';

END {
    #print "workdir = $dir\n";
    `rm -rf $dir` if $pl->verbose <0;
}
