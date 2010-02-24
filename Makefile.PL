use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tenjin',
    AUTHOR              => q{Ido Perlmuter <ido@ido50.net>},
    VERSION_FROM        => 'lib/Tenjin.pm',
    ABSTRACT_FROM       => 'lib/Tenjin.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM		=> {
        'Test::More'		=> 0,
        'Encode'		=> 0,
        'HTML::Entities'	=> 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tenjin-*' },
);
