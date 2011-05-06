#!/usr/bin/perl -w

use strict;
use warnings;
use feature ':5.10';
use open IO => ':utf8';

use Data::Dumper::Concise;
#use DateTime;
use File::Find::Rule;
use Try::Tiny;

use FindBin;
use lib "$FindBin::Bin/../lib/";
use MyCPAN::Schema::Dev;
use MyCPAN::Loader::Authors;
use MyCPAN::Loader::Distributions;

$| = 1; # autoflush

my $schema = MyCPAN::Schema::Dev->connect(
    'DBI:mysql:database=mycpan;host=localhost', 'mycpan', 'XXXXXXX',
    { mysql_enable_utf8 => 1},
    {quote_char => '`', name_sep => '.'}
);

my $cpan_dir = '/home/mycpan/cpan';

# creates in the db
my $data_load = $schema->resultset('DataLoad')->create({
    notifications_run => 'no',
    status => 'running',
});
my $data_load_id = $data_load->id;


my @basic_args = (
    schema       => $schema,
    cpan_dir     => $cpan_dir,
    data_load_id => $data_load_id
);


# run tasks sequentially with graceful failure
my @tasks = (
    {
        task => sub { MyCPAN::Loader::Authors->new( @basic_args )->run; },
        fail => sub {
            $schema->resultset('Author')
                   ->search({ data_load_id => $data_load_id })
                   ->delete;
        },
    },
    {
        task => sub {
            MyCPAN::Loader::Distributions->new(
                @basic_args,
                #includes => [qw/Plack Plack-Request Dancer CGI.pm Moose/],
            )->run;
        },
        fail => sub {
            $schema->resultset('Dist')
                   ->search({ data_load_id => $data_load_id })
                   ->delete_all;
            $schema->resultset('Release')
                   ->search({ data_load_id => $data_load_id })
                   ->delete_all;
        }
    },
    #{
    #    task => sub {
    #        MyCPAN::Loader::Releases->new(
    #            @basic_args
    #        )->run;
    #    },
    #    fail => sub {
    #        return;
    #    }
    #}
    #{
    #    task => sub {
    #        MyCPAN::Loader::ReleaseMeta->new(
    #            @basic_args
    #        )->run;
    #    },
    #    fail => sub {
    #        return;
    #    }
    #}
);

my $next_status = 'complete';
my $fail_reason = undef;
foreach my $task ( @tasks ) {
    try { $task->{task}->(); }
    catch {
        $next_status = 'failed';
        $fail_reason = $_;
        say $fail_reason;
        $task->{fail}->();
        return;
    };

    last if $next_status eq 'failed';
}

$data_load->set_columns({
    authors     => $schema->resultset('Author')->search({ data_load_id => $data_load_id})->count,
    dists       => $schema->resultset('Dist')->search({ data_load_id => $data_load_id})->count,
    releases    => $schema->resultset('Release')->search({ data_load_id => $data_load_id})->count,
    status      => $next_status,
    fail_reason => $fail_reason,
});


$data_load->update;

__END__
###
# find dists
my @files = File::Find::Rule


