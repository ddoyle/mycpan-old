package MyCPAN::Loader::Role::Index;

use Moose::Role;
use MyCPAN::Model::DistributionIndex;
use namespace::autoclean;

requires qw/cpan_dir/;

has 'index' => (
    is          => 'rw',
    isa         => 'MyCPAN::Model::DistributionIndex',
    builder     => '_build_index',
);

# initialize the index
sub _build_index {
    my $self = shift;
    my $index = MyCPAN::Model::DistributionIndex->new(
        file => $self->cpan_dir->file('indices/find-ls.gz')->stringify
    );
    return $index;
}

__PACKAGE__->meta->make_immutable(); 1;


