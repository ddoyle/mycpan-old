#!/usr/bin/perl -w

use strict;
use warnings;
use feature ':5.10';

use Parse::CPAN::Distributions;

my $dists = Parse::CPAN::Distributions( file => '/home/mycpan/cpan/indices/find-ls.gz' );




__END__
use Parse::CPAN::Packages;

my $p = Parse::CPAN::Packages->new('/home/mycpan/cpan/modules/02packages.details.txt.gz');

foreach my $dist ( $p->distributions ) {
    next unless defined $dist->dist;
    print $dist->dist, ' -- version ';
    say (defined $dist->version ? $dist->version : 'NO VERSION');
    my @packages = $dist->contains;
    say '    Total packages: ',scalar @packages;
    say '        ', $_->package foreach @packages
}

