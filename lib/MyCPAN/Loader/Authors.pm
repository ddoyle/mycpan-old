package MyCPAN::Loader::Authors;

use Moose;

use MyCPAN::Model::AuthorFile;

extends 'MyCPAN::Loader';

# results set for author table
override 'run' => sub {
    my $self = shift;

    my $rs = $self->schema->resultset('Author');
    
    my $author_file = MyCPAN::Model::AuthorFile->new(
        file => $self->cpan_dir->file('authors/00whois.xml')->stringify
    );
    
    while ( my $record = $author_file->next ) {
        
        my $author = $rs->find_or_new({ cpanid => $record->{cpanid} });
        
        next if !$self->force && $author->in_storage;
        
        $author->set_columns({
            %$record,
            data_load_id => $self->data_load_id,
        });
        $author->insert_or_update;
    }

    return;    
};

__PACKAGE__->meta->make_immutable(); 1;