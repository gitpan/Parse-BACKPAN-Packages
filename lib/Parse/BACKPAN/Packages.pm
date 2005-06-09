package Parse::BACKPAN::Packages;
use strict;
use base qw( Class::Accessor::Fast );
__PACKAGE__->mk_accessors(qw( data files dist_by_data ));
use CPAN::DistnameInfo;
use Compress::Zlib;
use IO::File;
use IO::Zlib;
use LWP::UserAgent;
use Parse::BACKPAN::Packages::File;
use Parse::BACKPAN::Packages::Distribution;
use vars qw($VERSION);
$VERSION = '0.30';

sub new {
  my $class    = shift;
  my $filename = shift;

  my $self = {};
  bless $self, $class;

  if ($filename) {
    my $fh = IO::Zlib->new($filename, "rb")
      || die "Failed to read $filename: $!";
    $self->data(join '', <$fh>);
    $fh->close;
  } else {
    my $url = "http://www.astray.com/tmp/backpan.txt.gz";
    my $ua  = LWP::UserAgent->new;
    $ua->timeout(180);
    my $response = $ua->get($url);

    if ($response->is_success) {
      my $gzipped = $response->content;
      my $data    = Compress::Zlib::memGunzip($gzipped);
      die "Error uncompressing data from $url" unless $data;
      $self->data($data);
    } else {
      die "Error fetching $url";
    }
  }
  $self->_parse;

  return $self;
}

sub _parse {
  my $self = shift;
  my %files;

  foreach my $line (split "\n", $self->data) {
    my ($prefix, $date, $size) = split ' ', $line;
    next unless $size;
    my $file = Parse::BACKPAN::Packages::File->new;
    $file->prefix($prefix);
    $file->date($date);
    $file->size($size);
    $files{$prefix} = $file;
  }
  $self->files(\%files);
}

sub file {
  my ($self, $prefix) = @_;
  return $self->files->{$prefix};
}

sub distributions {
  my ($self, $name) = @_;
  my @files;

  while (my ($prefix, $file) = each %{ $self->files }) {
    my $prefix = $file->prefix;
    next unless $prefix =~ m{\/$name-};
    next if $prefix =~ /\.(readme|meta)$/;
    push @files, $file;
  }

  @files = sort { $a->date <=> $b->date } @files;

  my @dists;
  foreach my $file (@files) {
    my $i = CPAN::DistnameInfo->new($file->prefix);
    my $dist = $i->dist;
    next unless $dist eq $name;
    my $d = Parse::BACKPAN::Packages::Distribution->new;
    $d->prefix($file->prefix);
    $d->date($file->date);
    $d->dist($dist);
    $d->version($i->version);
    $d->maturity($i->maturity);
    $d->filename($i->filename);
    $d->cpanid($i->cpanid);
    $d->distvname($i->distvname);
    push @dists, $d;
  }

  return @dists;
}

sub distributions_by {
  my ($self, $author) = @_;

  my $dist_by = $self->_dist_by;

  my @dists = @{ $dist_by->{$author} };
  return sort @dists;
}

sub authors {
  my $self    = shift;
  my $dist_by = $self->_dist_by;
  return sort keys %$dist_by;
}

sub _dist_by {
  my ($self) = shift;
  return $self->dist_by_data if $self->dist_by_data;

  my @files;

  while (my ($prefix, $file) = each %{ $self->files }) {
    my $prefix = $file->prefix;
    next if $prefix =~ /\.(readme|meta)$/;
    push @files, $file;
  }

  @files = sort { $a->date <=> $b->date } @files;

  my $dist_by;
  foreach my $file (@files) {
    my $i = CPAN::DistnameInfo->new($file->prefix);
    my ($dist, $cpanid) = ($i->dist, $i->cpanid);
    next unless $dist && $cpanid;
    $dist_by->{$dist} = $cpanid;
  }

  my $dists_by;
  while (my ($dist, $by) = each %$dist_by) {
    push @{ $dists_by->{$by} }, $dist;
  }

  $self->dist_by_data($dists_by);
  return $dists_by;
}

sub size {
  my $self = shift;
  my $size;

  foreach my $file (values %{ $self->files }) {
    $size += $file->size;
  }
  return $size;
}

1;

__END__

=head1 NAME

Parse::BACKPAN::Packages - Provide an index of BACKPAN

=head1 SYNOPSIS

  use Parse::BACKPAN::Packages;
  my $p = Parse::BACKPAN::Packages->new();
  print "BACKPAN is " . $p->size . " bytes\n";

  my @filenames = keys %$p->files;

  # see Parse::BACKPAN::Packages::File
  my $file = $p->file("authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
  print "That's " . $file->size . " bytes\n";

  # see Parse::BACKPAN::Packages::Distribution
  my @acme_colours = $p->distributions("Acme-Colour");
  
  my @authors = $p->authors;
  my @acmes = $p->distributions_by('LBROCARD');

=head1 DESCRIPTION

The Comprehensive Perl Archive Network (CPAN) is a very useful
collection of Perl code. However, in order to keep CPAN relatively
small, authors of modules can delete older versions of modules to only
let CPAN have the latest version of a module. BACKPAN is where these
deleted modules are backed up. It's more like a full CPAN mirror, only
without the deletions. This module provides an index of BACKPAN and
some handy functions.

=head1 METHODS

=head2 new

The constructor downloads a ~1M index file from the web and parses it,
so it might take a while to run:

  my $p = Parse::BACKPAN::Packages->new();

=head2 authors

The authors method returns a list of all the authors. This is meant so
that you can pass them into the distributions_by method:

  my @authors = $p->authors;

=head2 distributions

The distributions method returns a list of objects representing all
the different versions of a distribution:

  # see Parse::BACKPAN::Packages::Distribution
  my @acme_colours = $p->distributions("Acme-Colour");

=head2 distributions_by

The distributions_by method returns a list of distribution names
representing all the distributions that an author has uploaded:

  my @acmes = $p->distributions_by('LBROCARD');

=head2 file

The file method finds metadata relating to a file:

  # see Parse::BACKPAN::Packages::File
  my $file = $p->file("authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
  print "That's " . $file->size . " bytes\n";

=head2 files

The files method returns a hash reference where the keys are the
filenames of the files on CPAN and the values are
Parse::BACKPAN::Packages::File objects:

  my @filenames = keys %$p->files;

=head2 size

The size method returns the sum of all the file sizes in BACKPAN:

  print "BACKPAN is " . $p->size . " bytes\n";

=head1 AUTHOR

Leon Brocard <acme@astray.com>

=head1 COPYRIGHT

Copyright (C) 2005, Leon Brocard

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<CPAN::DistInfoname>, L<Parse::BACKPAN::Packages::File>,
L<Parse::BACKPAN::Packages::Distribution>, L<Parse::CPAN::Packages>.
