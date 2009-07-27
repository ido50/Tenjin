use inc::Module::Install 0.77;

if ( -e 'MANIFEST.SKIP' ) {
    system( 'pod2text lib/Tenjin.pm > README' );
}

perl_version '5.008';

name 'Tenjin';
all_from 'lib/Tenjin.pm';

test_requires 'Test::More';

auto_install;
WriteAll;
