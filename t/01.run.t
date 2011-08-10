# -*-Perl-*- mode (for emacs)
use Test::More tests => 7;
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
   (config=>test_input_file('string_manipulation.xml'),
    dir=>$dir, verbose=> -1);
#    verbose=> 1);
#ok $pl->dir('/tmp/pl'), 'dir()';
my $string = $pl->stringify;
#print $string;
ok $string =~ /# ->/, 'stringify())';
ok $pl->each_step, 'each_step';
ok $pl->run, 'run())';
#print Dumper $pl;
my $dot = $pl->graphviz;
ok $dot =~ /^digraph /, 'graphviz()';

ok $pl->start('s3'), 'start()';
ok$pl->stop('s4'), 'stop()';

END {
    `rm -rf $dir` if $pl->verbose <0;
}
