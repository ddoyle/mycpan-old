#!/usr/bin/perl -w
use strict;
use warnings;
use feature ':5.10';

use FindBin;
use lib "$FindBin::Bin/../lib/";
use MyCPAN::Model::DistributionIndex;

my $index = MyCPAN::Model::DistributionIndex->new(
    file => '/home/mycpan/cpan/indices/find-ls.gz'
);

say 'Dists found: ', $index->how_many;
say 'Release: ', $index->release_count;