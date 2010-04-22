use Test::More tests => 14;
use Data::Dumper;
use File::Spec;
BEGIN {
      use_ok( 'Pipeline' );
}

sub test_input_file {
    return File::Spec->catfile('t', 'data', @_);
}

diag( "Testing Pipeline $Pipeline::VERSION" );

my $p = Pipeline->new;
ok ref($p) eq 'Pipeline', 'new()';

my $s2 = Pipeline->new(id=> 'S2');
ok ref($s2) eq 'Pipeline', 'new()';

# method testing
can_ok $p->add($s2), 'add';
ok $s2->id() eq 'S2', 'id()';
ok $s2->name('test'), 'name()';
ok $s2->name() eq 'test', 'name()';
ok $s2->description('test'), 'description()';
ok $s2->next_id('test'), 'next_id()';
ok $s2->config(test_input_file('string_manipulation.xml')), 'config()';
ok $s2->input_name('test'), 'input_name()';
ok $s2->input_format('test'), 'input_format()';
ok $s2->code('test'), 'code()';
#ok $s2->run('test'), 'run()';

#ok $s2->dir('data'), 'dir()';
#$s2->('test'), '()';

my @methods = qw(id name description input_name   
		 input_format code next_id config add
		 run
	       );
can_ok 'Pipeline', @methods;

# reading in a configuration
my $pl = Pipeline->new(config=>test_input_file('string_manipulation.xml'));
$pl->dir('/tmp/pl');
$pl->stringify;

#print Dumper $pl;




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
  
