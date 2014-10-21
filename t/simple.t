# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use Test;
BEGIN { plan tests => 8 };
use Image::WorldMap;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $map = Image::WorldMap->new('examples/earth-small.png', "maian/8");
ok(1);

$map->add(4.91, 52.35, "Amsterdam.pm");
ok(1);

$map->add(-2.355399, 51.3828, "Bath.pm", [255,127,0]);
ok(1);

$map->add(-0.093999, 51.3627, "Croydon.pm", [0,255, 255]);
ok(1);

$map->add(0, 0, undef, [0,0,255]);
ok(1);

$map->add(-10, 0);
ok(1);

$map->draw("test.png");
ok(1);
