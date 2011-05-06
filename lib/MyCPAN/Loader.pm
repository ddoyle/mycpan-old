package MyCPAN::Loader;

use Moose;
use MooseX::Types::Path::Class qw(Dir File);
use Data::Dumper::Concise;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);

has 'cpan_dir' => (
    is          => 'rw',
    isa         => Dir,
    required    => 1,
    coerce      => 1,
);

# the id of this data load run in data_load
has 'data_load_id' => (
    is          => 'rw',
    isa         => 'Int',
    required    => 1,
);

has 'is_backpan' => (
    is          => 'rw',
    isa         => 'Int',
    required    => 1,
    default     => 0,
);

has 'force' => ( is => 'rw', isa => 'Bool', default => 0 );

sub run {
    confess "must override run";
}

sub modulename_to_distname {
    my ( $self, $name ) = @_;
    return unless $name;
    $name =~ s/::/-/g;
    return $name;
}

sub distname_to_modulename {
    my ($self, $name) = @_;
    return unless $name;
    $name =~ s/-/::/g;
    return $name;
}

sub dump {
    my ($self, @args) = @_;
    return Dumper(@args);
}

__PACKAGE__->meta->make_immutable; 1;