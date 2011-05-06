package MyCPAN::Loader::Releases;

# this will process releases as specified where `release`.`processed_archive` = 0
# AND `release`.`ignore` = 0 AND `dist`.ignore = 0

use feature ':5.10';

use Moose;
#use Perl6::Junction qw(any none);
use MooseX::Params::Validate;

use MyCPAN::Model::DistributionIndex;
use MyCPAN::Model::PackageFile;

extends 'MyCPAN::Loader';

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

sub _build_perms {
    my $self = shift;
    my $perms = MyCPAN::Model::PermsFile->new(
        file    => $self->cpandir->file('modules/06perms.txt')->stringify
    );
    return $perms;
    
}



override 'run' => sub {
    my $self = shift;
    
    # switch some releases to 'skip' if ignore is set
    $self->schema->resultset('Release')->search_rs->({
        ignore  => 1,
        processed_archive => 'no'
    })->update({
        prosessed_archive => 'skip', processed_meta => 'skip'
    });
    
    # now let's get the releases that need to be processed
    my $releases = $self->schema->resultset('Release')->search({
        processed_archive => 'no',
        ignore            => 0,
    });
    
    while ( my $release = $releases->next ) {
        my $processed_status = 'yes';
        
        # process the release tarball
        my $release_file = $self->cpan_dir->file($release->pathname)->stringify;
        
        # process the meta
        my $meta_file = $release_file;
        if (   $meta_file =~ s/\.(?:tar(?:\.gz|\.bz2)?|t[bg]z|zip)$/\.meta/i
            && -f $meta_file
        ) {
            # process meta file
            # prereqs/dependencies
            # licence
            # website
            # bugtracker
        }
        
        
        $release->set_column('processed_archive', )
    }
    
    
};

1;