# -*-Perl-*- mode (for emacs)
use Test::More tests => 4;
use Data::Dumper;
use File::Spec;


sub test_input_file {
    return File::Spec->catfile('t', 'data', @_);
}

diag( "Testing spipe from command line" );
my $conffile = test_input_file('string_manipulation.yml');

ok `bin/spipe 2>&1` =~ /ERROR/, 'die without config' ;
ok `bin/spipe -v` =~ /spipe, version /, '--version' ;
ok `bin/spipe -help` =~ /User Contributed Perl Documentation/, '--help' ;
ok `bin/spipe  -conf $conffile -debug` =~ /s1/, '--debug' ;
unlink 'config.yml', 'pipeline.log';
