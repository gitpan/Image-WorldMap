package Image::WorldMap;

use strict;
use Image::Imlib2;
use Image::WorldMap::Label;
use vars qw($VERSION);
$VERSION = '0.10';

use Inline C => 'DATA',
  VERSION => '0.10',
  NAME => 'Image::WorldMap';

=head1 NAME

Image::WorldMap - Create graphical world maps of data

=head1 SYNOPSIS

  my $map = Image::WorldMap->new("earth-small.png", "maian/8");
  $map->add(4.91, 52.35, "Amsterdam.pm");
  $map->add(-2.355399, 51.3828, "Bath.pm");
  $map->add(-0.093999, 51.3627, "Croydon.pm");
  $map->draw("test.png");

=head1 DESCRIPTION

This module helps create graphical world maps of data, such as the
Perl Monger World Map (http://www.astray.com/Bath.pm/). This module
takes in a number of label locations (longitude/latitude) and outputs
an image. It can attach text to the labels, and tries to make sure
that labels do not overlap.

It is intended to be used to create images of information such as
"where are all the Perl Monger groups?", "where in the world are all
the CPAN mirrors?" and so on.

This module comes with a low-resolution image of the world. Additional
larger images have not been bundled with the module due to their size,
but are available at: http://www.astray.com/WorldMap/

=cut

=head1 METHODS

=head2 new

The constructor. It takes two mandatory arguments, the filename of the
image of the earth used for the background, and whether or not to
display labels.

The label option is actually a font size and name. You must have a
local truetype font in your directory. The font name format is
"font_name/size". For example. If there is a font file called
cinema.ttf somewhere in the font path you might use "cinema/20" to
load a 20 pixel sized font of cinema.

  # Without labels
  my $map = Image::WorldMap->new("earth-small.png");

  # With labels
  my $map = Image::WorldMap->new("earth-small.png", "maian/8");

=cut

# Class method, creates a new map
sub new {
  my($class, $filename, $label) = @_;

  my $self = {};

  my $image = Image::Imlib2->load($filename);
  my $w = $image->get_width;
  my $h = $image->get_height;
  $image->add_font_path("../");
  $image->add_font_path("examples/");

  $self->{IMAGE} = $image;
  $self->{LABELS} = [];
  $self->{LABEL} = $label;
  $self->{W} = $w;
  $self->{H} = $h;
  bless $self, $class;

  if (defined $label) {
    # Determine the label offset for the current font
    $image->load_font($label);
    my $testlabel = Image::WorldMap::Label->new(0, 0, "This is a testy little label", $self->{IMAGE});
    my($w, $h) = $testlabel->_boundingbox($image, "This is a testy little label");
    $Image::WorldMap::Label::YOFFSET = -int($h / 2);
    $Image::WorldMap::Label::XOFFSET = 5;
  }

  return $self;
}


=head2 add

This adds a node to the map, with an optional label. Longitude and
latitude are given as a decimal, with (0, 0) representing a point on
the Greenwich meridian and the equator and (-180, -180) top-left and
(180, 180) bottom-right on a projection of the Earth.

  $map->add(-2.355399, 51.3828, "Bath.pm");

=cut

sub add {
  my($self, $longitude, $latitude, $label) = @_;

  my($w, $h) = ($self->{W}, $self->{H});
  $w /= 2;

  my $x = $longitude;
  my $y = $latitude;

  $x = $x * $w / 180;
  $y = $y * $h / 180;
  $y = -$y;
  $x += $w;
  $y += ($h/2);

#  print "Adding: $label at $longitude, $latitude ($x, $y)\n";

  # If we're not showing labels, delete the label
  undef $label unless $self->{LABEL};

  my $newlabel = Image::WorldMap::Label->new(int($x), int($y), $label, $self->{IMAGE});
  push @{$self->{LABELS}}, $newlabel;
}


=head2 draw

This draws the map and writes it out to a file. The file format is
chosen from the filename, but is typically PNG.

  $map->draw("text.png");

=cut

sub draw {
  my($self, $filename) = @_;

  if ($self->{LABEL}) {

# Don't bounce a label if it is fine
    foreach my $label (@{$self->{LABELS}}) {
      if ($self->_overlapping_labels_single($label) == 0) {
	$label->{NOBOUNCE}++;
#	      warn "nobounce: " . $label->text . "\n";
      }
    }

#      foreach my $label (@{$self->{LABELS}}) {
#        $self->_bounce($label);
#      }
    # temperature
    my $t = 200;

    my $i = 1;

#    my @labels = @{$self->{LABELS}};
    my @labels = grep { not exists $_->{NOBOUNCE} } @{$self->{LABELS}};

    while (1) {
      # decrease T
      $t *= 0.9;

      # only do 50 iterations
      last if $i > 50;

#      warn "$i: overlap=" . $self->_overlapping_labels() . ", t=$t\n";
      $i++;

      my $nlabels = @{$self->{LABELS}};
      my $changed = 0;

      foreach (1..20) {
	
	fisher_yates_shuffle(\@labels);

	# only change so many labels an iteration
	last if $changed > 5 * $nlabels;

	foreach my $label (@labels) {
	
#	next if $label->{NOBOUNCE};
#	last if $changed > 5 * $nlabels;
	
	  my($x, $y) = ($label->labelx, $label->labely);
	  my $old_overlap = $self->_overlapping_labels_single($label);
	  $self->_bounce($label);
	  my $new_overlap = $self->_overlapping_labels_single($label);
	  my $delta = $new_overlap - $old_overlap;
	
	  if ($delta > 0 and (rand() < (1.0 - exp(-$delta / $t)))) {
	    $label->move($x, $y); # unbounce
	    #	print "...unbounced";
	  } else {
	    $changed++;
	  }
	}
      }
    }

    # see if the original location was still better
    foreach my $label (@labels) {
      my $old_overlap = $self->_overlapping_labels_single($label);
#      my $old_overlap = $self->_overlapping_labels();
      my($x, $y) = ($label->labelx, $label->labely);
      my($realx, $realy) = ($label->x, $label->y);
      $label->move($realx, $realy);
      my $new_overlap = $self->_overlapping_labels_single($label);
#      my $new_overlap = $self->_overlapping_labels();
      my $delta = $new_overlap - $old_overlap;
      if ($delta > 0) {
	$label->move($x, $y);
      }
    }
  }

  my $image = $self->{IMAGE};
  map { $_->draw_dot($image) } @{$self->{LABELS}};
  map { $_->draw_label($image) } @{$self->{LABELS}};

#  print "Total overlap of " . $self->_overlapping_labels() . "\n";
  $image->save($filename);
}


sub _bounce {
  my($self, $label) = @_;

  bounce_c($label);
}


# fisher_yates_shuffle( \@array ) :
# generate a random permutation of @array in place
sub fisher_yates_shuffle {
  my $array = shift;
  my $i;
  for ($i = @$array; --$i; ) {
    my $j = int rand ($i+1);
    @$array[$i,$j] = @$array[$j,$i];
  }
}


sub _overlapping_labels {
  my($self) = shift;

  return overlap_c($self->{LABELS});
}

sub _overlapping_labels_single {
  my($self, $label) = @_;

  return overlap_single_c($label, $self->{LABELS});
}


=head1 NOTES

This module tries hard to make sure that labels do not overlap. This
is an NP-hard problem. It currently uses a simulated annealing method
with Inline::C to speed it up. It could be faster still.

The label positioning method used is random: if you run the program
again, you will get a different set of label positions, which may or
may not be better.

The images produced by this module are quite large, as they contain
lots of colour information. You should probably reduce the size
somehow (such as using the Gimp to convert it to use indexed colours)
before using the image on the web.

=head1 COPYRIGHT

Copyright (C) 2001, Leon Brocard

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Leon Brocard, acme@astray.com

=cut

1;

__DATA__

__C__

void bounce_c(SV* hash_ref) {
  HV* hash;
  SV* x;
  SV* y;
  int r;

  if (!SvROK(hash_ref))
    croak("hash_ref is not a reference");

  hash = (HV*)SvRV(hash_ref);

  x = *hv_fetch(hash, "X", 1, FALSE);
  y = *hv_fetch(hash, "Y", 1, FALSE);

  r = (int) (40.0*rand()/(RAND_MAX+1.0));
  hv_store(hash, "LABELX", 6, newSViv(SvIV(x) + r), 0);
  r = (int) (80.0*rand()/(RAND_MAX+1.0));
  r -= 40;
  hv_store(hash, "LABELY", 6, newSViv(SvIV(y) + r), 0);

  return;
}



int overlap_c(SV* labels_ref) {
  AV* labels;
  int nlabels;
  SV* l1;
  SV* l2;
  SV* foo;
  SV** svp;
  float p;
  int overlap, i, j;
  int l1x, l1y, l1w, l1h, l1realx, l1realy;
  int l2x, l2y, l2w, l2h;
  int x, y, w, h;
  int xdiff, ydiff;

  if (!SvROK(labels_ref))
    croak("labels_ref is not a reference");

  labels = (AV*)SvRV(labels_ref);
  nlabels = av_len(labels);

/*  printf("nlabels: %i\n", nlabels); */

  overlap = 0;

  for (i = 0; i < nlabels; i++) {
/*    printf("i: %i\n", i); */
    l1 = (HV*)SvRV(*av_fetch(labels, i, 0));
    l1x = SvIV(*hv_fetch(l1, "LABELX", 6, FALSE));
    l1y = SvIV(*hv_fetch(l1, "LABELY", 6, FALSE));
    l1w = SvIV(*hv_fetch(l1, "LABELW", 6, FALSE));
    l1h = SvIV(*hv_fetch(l1, "LABELH", 6, FALSE));
/*    printf("l1 (%i): (%i, %i) x (%i, %i)\n", i, l1x, l1y, l1w, l1h);  */

    l1realx = SvIV(*hv_fetch(l1, "X", 1, FALSE));
    l1realy = SvIV(*hv_fetch(l1, "Y", 1, FALSE));
    xdiff = abs(l1realx - l1x);
    ydiff = abs(l1realy - l1y);
    overlap += (int) (sqrt((xdiff * xdiff) + (ydiff * ydiff)));

    for (j = 0; j < nlabels; j++) {
/*      printf("j: %i\n", j); */
        if (j < i) {

	l2 = (HV*)SvRV(*av_fetch(labels, j, 0));
	l2x = SvIV(*hv_fetch(l2, "LABELX", 6, FALSE));
	l2y = SvIV(*hv_fetch(l2, "LABELY", 6, FALSE));
	l2w = SvIV(*hv_fetch(l2, "LABELW", 6, FALSE));
	l2h = SvIV(*hv_fetch(l2, "LABELH", 6, FALSE));
/*	printf("l2 (%i): (%i, %i) x (%i, %i)\n", j, l2x, l2y, l2w, l2h);  */

	x = l1x > l2x ? l1x : l2x;
	y = l1y > l2y ? l1y : l2y;
	w = (l1x + l1w < l2x + l2w ? l1x + l1w : l2x + l2w) - x;
	h = (l1y + l1h < l2y + l2h ? l1y + l1h : l2y + l2h) - y;
	
	if (w > 0 && h > 0) {
	  overlap += (w * h);
/*	  printf("overlap: %i\n", overlap); */
	}

      }
    }
  }

  return overlap;
}


int overlap_single_c(SV* l1, SV* labels_ref) {
  AV* labels;
  int nlabels;
  SV* l2;
  float p;
  int overlap, i, j;
  int l1x, l1y, l1w, l1h, l1realx, l1realy;
  int l2x, l2y, l2w, l2h;
  int x, y, w, h;
  int xdiff, ydiff;

  if (!SvROK(labels_ref))
    croak("labels_ref is not a reference");

  labels = (AV*)SvRV(labels_ref);
  nlabels = av_len(labels);

/*  printf("nlabels: %i\n", nlabels); */

  overlap = 0;

  l1 = (HV*)SvRV(l1);

  l1x = SvIV(*hv_fetch(l1, "LABELX", 6, FALSE));
  l1y = SvIV(*hv_fetch(l1, "LABELY", 6, FALSE));
  l1w = SvIV(*hv_fetch(l1, "LABELW", 6, FALSE));
  l1h = SvIV(*hv_fetch(l1, "LABELH", 6, FALSE));
/*    printf("l1 (%i): (%i, %i) x (%i, %i)\n", i, l1x, l1y, l1w, l1h);  */

  l1realx = SvIV(*hv_fetch(l1, "X", 1, FALSE));
  l1realy = SvIV(*hv_fetch(l1, "Y", 1, FALSE));
  xdiff = abs(l1realx - l1x);
  ydiff = abs(l1realy - l1y);
  overlap += (int) (sqrt((xdiff * xdiff) + (ydiff * ydiff)));

  for (j = 0; j < nlabels; j++) {
/*      printf("j: %i\n", j); */

    l2 = (HV*)SvRV(*av_fetch(labels, j, 0));

    if (l1 != l2) { 

      l2x = SvIV(*hv_fetch(l2, "LABELX", 6, FALSE));
      l2y = SvIV(*hv_fetch(l2, "LABELY", 6, FALSE));
      l2w = SvIV(*hv_fetch(l2, "LABELW", 6, FALSE));
      l2h = SvIV(*hv_fetch(l2, "LABELH", 6, FALSE));
/*	printf("l2 (%i): (%i, %i) x (%i, %i)\n", j, l2x, l2y, l2w, l2h);  */

      x = l1x > l2x ? l1x : l2x;
      y = l1y > l2y ? l1y : l2y;
      w = (l1x + l1w < l2x + l2w ? l1x + l1w : l2x + l2w) - x;
      h = (l1y + l1h < l2y + l2h ? l1y + l1h : l2y + l2h) - y;
	
      if (w > 0 && h > 0) {
        overlap += (w * h);
/*	  printf("overlap: %i\n", overlap); */
      }
    }
  }

  return overlap;
}
