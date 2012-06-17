# -*-Perl-*- mode (for emacs)
use Test::More tests => 4;
use Data::Dumper;
use File::Spec;


sub test_input_file {
    return File::Spec->catfile('t', 'data', @_);
}

diag( "Testing pipeline.pl from command line" );
my $conffile = test_input_file('string_manipulation.yml');

ok `bin/pipeline.pl 2>&1` =~ /ERROR/, 'die without config' ;
ok `bin/pipeline.pl -v` =~ /pipeline.pl, version /, '--version' ;
ok `bin/pipeline.pl -help` =~ /User Contributed Perl Documentation/, '--help' ;
ok `bin/pipeline.pl  -conf $conffile -debug` =~ /s1/, '--debug' ;
unlink 'config.yml', 'pipeline.log';
