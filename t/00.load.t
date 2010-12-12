use Test::More tests => 15;
use Data::Dumper;
use File::Spec;

BEGIN {
      use_ok( 'Pipeline::Simple' );
}

sub test_input_file {
    return File::Spec->catfile('t', 'data', @_);
}

diag( "Testing Pipeline $Pipeline::Simple::VERSION" );

# debug ignores missing config file
my $p = Pipeline::Simple->new(debug => 1);
ok ref($p) eq 'Pipeline::Simple', 'new()';

my $s2 = Pipeline::Simple->new(id=> 'S2', debug => 1);
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
ok $s2->config(test_input_file('string_manipulation.xml')), 'config()';
ok $s2->input('test'), 'input()';
ok $s2->itype('test'), 'itype()';
#ok $s2->run('test'), 'run()';

#ok $s2->dir('data'), 'dir()';
#$s2->('test'), '()';

my @methods = qw(id name description  next_id config add
		 run input itype
	       );
can_ok 'Pipeline::Simple', @methods;

# reading in a configuration
my $pl = Pipeline::Simple->new
   (config=>test_input_file('string_manipulation.xml'));
$pl->dir('/tmp/pl');
$pl->stringify;
#$pl->each_step;
#$pl->run;
#print Dumper $pl;
#print $pl->graphviz;



# # Various ways to say "ok"
#     ok($got eq $expected, $test_name);
#
#     is  ($got, $expected, $test_name);
#     isnt($got, $expected, $test_name);
#
#     # Rather than print STDERR "# here's what went wrong\n"
#     diag("here's what went wrong");
#
#     like  ($got, qr/expected/, $test_name);
#     unlike($got, qr/expected/, $test_name);
#
#     cmp_ok($got, '==', $expected, $test_name);
#
#      can_ok($module, @methods);
#     isa_ok($object, $class);
#
#     pass($test_name);
#     fail($test_name);
  
