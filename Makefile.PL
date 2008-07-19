use inc::Module::Install;

name     'Data-Polymorph';
all_from 'lib/Data/Polymorph.pm';
author   'lieutar <lieutar@1dk.jp>';

build_requires 'Test::More';

auto_install;

WriteAll;

