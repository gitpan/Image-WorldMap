use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Image::WorldMap',
    'VERSION_FROM'	=> 'WorldMap.pm', # finds $VERSION
    'PREREQ_PM'		=> { Image::Imlib2 => 0, Test::More => 0, },
    'dist' => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);

sub MY::libscan {
  my $path = $_[1];
  return '' if $path =~ /\B\.svn\b/;
  return $path;
}
