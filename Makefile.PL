use Inline::MakeMaker;
#use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteInlineMakefile(
    'NAME'		=> 'Image::WorldMap',
    'VERSION_FROM'	=> 'WorldMap.pm', # finds $VERSION
    'PREREQ_PM'		=> { Image::Imlib2 => 0.01 },
    'dist' => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
