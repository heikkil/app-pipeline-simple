use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Pipeline::Simple',
    license             => 'perl',
    dist_author         => 'Heikki Lehvaslaiho <heikki.lehvaslaiho@gmail.com>',
    dist_version_from   => 'lib/Pipeline::Simple.pm',
    requires => {
        'Test::More'    => 0,
        'version'       => 0,
	'XML::Simple'   => 0,
	'GraphViz'      => 0,
	'Log::Log4perl' => 0,

    },
    add_to_cleanup      => [ 'Pipeline-*' ],
);

$builder->create_build_script();
