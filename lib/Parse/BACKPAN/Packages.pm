package Parse::BACKPAN::Packages;
use strict;
use base qw( Class::Accessor::Fast );
__PACKAGE__->mk_accessors(qw( data files ));
use CPAN::DistnameInfo;
use Compress::Zlib;
use IO::File;
use IO::Zlib;
use LWP::UserAgent;
use Parse::BACKPAN::Packages::File;
use Parse::BACKPAN::Packages::Distribution;
use vars qw($VERSION);
$VERSION = '0.29';

sub new {
  my $class = shift;
  my $filename = shift;

  my $self = {};
  bless $self, $class;

  if ($filename) {
    my $fh = IO::Zlib->new($filename, "rb") || 
      die "Failed to read $filename: $!";
    $self->data(join '', <$fh>);
    $fh->close;
  } else {
    my $url = "http://www.astray.com/tmp/backpan.txt.gz";
    my $ua = LWP::UserAgent->new;
    $ua->timeout(180);
    my $response = $ua->get($url);

    if ($response->is_success) {
      my $gzipped = $response->content;
       my $data = Compress::Zlib::memGunzip($gzipped);
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
    my($prefix, $date, $size) = split ' ', $line;
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
  my($self, $prefix) = @_;
  return $self->files->{$prefix};
}

sub distributions {
  my($self, $name) = @_;
  my @files;

  foreach my $file (values %{$self->files}) {
    my $prefix = $file->prefix;
    next unless $prefix =~ /$name/;
    next if $prefix =~ /\.(readme|meta)$/;
    push @files, $file;
  }

  @files = sort { $a->date <=> $b->date } @files;

  my @dists;
  foreach my $file (@files) {
    my $d = Parse::BACKPAN::Packages::Distribution->new;
    my $i = CPAN::DistnameInfo->new($file->prefix);
    next if $i->dist ne $name;
    $d->prefix($file->prefix);
    $d->date($file->date);
    $d->dist($i->dist);
    $d->version($i->version);
    $d->maturity($i->maturity);
    $d->filename($i->filename);
    $d->cpanid($i->cpanid);
    $d->distvname($i->distvname);
    push @dists, $d;
  }

  return @dists;
}

sub size {
  my $self = shift;
  my $size;

  foreach my $file (values %{$self->files}) {
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

=head2 distributions

The distributions method returns a list of objects representing all
the different versions of a distribution:

  # see Parse::BACKPAN::Packages::Distribution
  my @acme_colours = $p->distributions("Acme-Colour");

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
