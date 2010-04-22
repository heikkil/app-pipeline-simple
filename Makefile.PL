use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Pipeline',
    AUTHOR              => 'Heikki Lehvaslaiho <heikki.lehvaslaiho@gmail.com>',
    VERSION_FROM        => 'lib/Pipeline.pm',
    ABSTRACT_FROM       => 'lib/Pipeline.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Pipeline-*' },
);
