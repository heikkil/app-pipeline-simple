use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Pipeline::Simple',
    AUTHOR              => 'Heikki Lehvaslaiho <heikki.lehvaslaiho@gmail.com>',
    VERSION_FROM        => 'lib/Pipeline/Simple.pm',
    ABSTRACT_FROM       => 'lib/Pipeline/Simple.pm',
    EXE_FILES           => ['bin/pipeline.pl'],
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'    => 0,
        'version'       => 0,
	'XML::Simple'   => 0,
	'Log::Log4perl' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Pipeline-Simple-*' },
);
