#!/usr/bin/perl

use strict;
use warnings;
use feature ':5.10';

use CPAN::ParseDistribution;
use Data::Dumper::Concise;

my @dists = (qw[
    authors/id/M/MI/MIYAGAWA/Plack-0.9945.tar.gz
    authors/id/M/MI/MIYAGAWA/Plack-Request-0.09.tar.gz
    authors/id/L/LD/LDS/CGI.pm-3.49.tar.gz
]);

foreach my $distpath ( @dists ) {
    say $distpath;
    my $fullpath = '/home/mycpan/cpan/'.  $distpath;
    my $dist = CPAN::ParseDistribution->new( $fullpath );
    say Dumper( $dist->modules );
}
