# -*-Perl-*- mode (for emacs)
use Test::More tests => 13;
use Data::Dumper;
use File::Spec;

BEGIN {
      use_ok( 'Pipeline::Simple' );
}

sub test_input_file {
    return File::Spec->catfile('t', 'data', @_);
}

diag( "Testing Pipeline::Simple methods in memory" );

# debug ignores the missing config file
my $p = Pipeline::Simple->new(debug => 1, verbose => -1);
ok ref($p) eq 'Pipeline::Simple', 'new()';

my $s2 = Pipeline::Simple->new(id=> 'S2', debug => 1, verbose => -1);
ok ref($s2) eq 'Pipeline::Simple', 'new()';

# method testing
can_ok $p->add($s2), 'add';
ok $s2->id() eq 'S2', 'id()';
ok $s2->name('test'), 'name()';
ok $s2->name() eq 'test', 'name()';
ok $s2->path('/opt/scripts'), 'path()';
ok $s2->path() eq '/opt/scripts', 'path()';
ok $s2->description('test'), 'description()';
ok $s2->next_id('test'), 'next_id()';
ok $s2->dir('data'), 'dir()';
#ok $s2->config(test_input_file('string_manipulation.yml')), 'config()';
#ok $s2->input('test'), 'input()';
#ok $s2->itype('test'), 'itype()';

#ok $s2->run('test'), 'run()';
#my $dot = $s2->graphviz;
#ok $dot =~ /^digraph /, 'graphviz()';

#ok $s2->each_step, 'each_step';

my @methods = qw(id name description next_id config add
		 run input itype
	       );
can_ok 'Pipeline::Simple', @methods;

