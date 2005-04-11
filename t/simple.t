#!perl
use strict;
use warnings;
use Test::More tests => 30;
use lib 'lib';
use_ok("Parse::BACKPAN::Packages");

my $p = Parse::BACKPAN::Packages->new();
ok($p->size >= 5_597_434_696, "backpan is at least 5.6G");

my $files = $p->files;
ok(scalar(keys %$files) >= 105_996);

my $file = $p->file("authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
is($file->prefix, "authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
is($file->date, 1014330111);
is($file->size, 3031);
is($file->url, "http://backpan.cpan.org/authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");

my @acme_colours = $p->distributions("Acme-Colour");
is($acme_colours[0]->cpanid, "LBROCARD");
is($acme_colours[0]->date, "1014330111");
is($acme_colours[0]->dist, "Acme-Colour");
is($acme_colours[0]->distvname, "Acme-Colour-0.16");
is($acme_colours[0]->filename, "Acme-Colour-0.16.tar.gz");
is($acme_colours[0]->maturity, "released");
is($acme_colours[0]->prefix, "authors/id/L/LB/LBROCARD/Acme-Colour-0.16.tar.gz");
is($acme_colours[0]->version, "0.16");

is($acme_colours[1]->version, "0.17");
is($acme_colours[2]->version, "0.18");
is($acme_colours[3]->version, "0.19");
is($acme_colours[4]->version, "0.20");
is($acme_colours[5]->version, "1.00");
is($acme_colours[6]->version, "1.01");
is($acme_colours[7]->version, "1.02");

is($acme_colours[-1]->cpanid, "LBROCARD");
is($acme_colours[-1]->date, "1095772515");
is($acme_colours[-1]->dist, "Acme-Colour");
is($acme_colours[-1]->distvname, "Acme-Colour-1.02");
is($acme_colours[-1]->filename, "Acme-Colour-1.02.tar.gz");
is($acme_colours[-1]->maturity, "released");
is($acme_colours[-1]->prefix, "authors/id/L/LB/LBROCARD/Acme-Colour-1.02.tar.gz");
is($acme_colours[-1]->version, "1.02");

# use YAML; warn Dump \@acme_colours;

