use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Pipeline',
    license             => 'perl',
    dist_author         => 'Heikki Lehvaslaiho <heikki.lehvaslaiho@gmail.com>',
    dist_version_from   => 'lib/Pipeline.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'Pipeline-*' ],
);

$builder->create_build_script();
