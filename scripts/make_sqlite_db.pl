#!/usr/bin/perl -w
use strict;
use warnings;

use CPAN::SQLite;

my $db = CPAN::SQLite->new(
    CPAN    => '/home/mycpan/cpan',
    db_dir  => '/home/mycpan/cpan_db',
);

$db->index( setup => 1 );
