package MyCPAN::Loader::Role::Perms;

use Moose::Role;
use MyCPAN::Model::PermsFile;
use namespace::autoclean;

requires qw/cpan_dir/;

has 'perms' => (
    is      => 'rw',
    isa     => 'MyCPAN::Model::PermsFile',
    builder => '_build_perms',
);

sub _build_perms {
    my $self = shift;
    my $perms = MyCPAN::Model::PermsFile->new(
        file    => $self->cpandir->file('modules/06perms.txt')->stringify
    );
    return $perms;
    
}
__PACKAGE__->meta->make_immutable(); 1;


