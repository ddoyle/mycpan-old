package MyCPAN::Model::AuthorFile;

use open IO  => ':utf8';
use autodie qw(open close);

use Moose;
use MooseX::Types::Path::Class qw(File);

use Try::Tiny;
use XML::Simple;
use Data::Dumper::Concise;

# TODO : think about using Parse::CPAN::Authors


# this should be the full path to a CPAN mirrors
# authors/00whois.xml file
has 'file' => ( is => 'ro', isa => File, coerce => 1, required => 1 );

has '_xs' => (
    is       => 'ro',
    isa      => 'XML::Simple',
    required => 1,
    default  => sub { return XML::Simple->new() },
);

has '_data' => (
    traits  => [qw/Hash/],
    is      => 'rw',
    isa     => 'HashRef',
    handles => { how_many    => 'count' },
);

has '_keys' => ( is => 'rw', isa => 'ArrayRef' );

has '_current_index' => ( is=> 'rw', isa => 'Int', default => 0 );

# simple accessor based on cpanid
sub get {
    my $self   = shift;
    my $cpanid = shift;
    
    # must be scalar and defined
    return if !defined $cpanid
           || ref $cpanid
           || !exists $self->_data->{$cpanid};

    # cheap copy.  no refs so no worries.    
    return { cpanid => $cpanid, %{ $self->_data->{$cpanid} } };
}
    
    
# iterator functions
sub next {
    my $self = shift;
    
    # too far!
    return unless $self->_current_index < $self->how_many;
    
    my $key = $self->_keys->[ $self->_current_index ];
    $self->_current_index( $self->_current_index + 1 );
    return { cpanid => $key, %{ $self->_data->{$key} }  };
    
}

sub has_next {
    my $self = shift;
    return $self->_current_index < $self->how_many;
}

sub reset {
    my $self = shift;
    $self->_current_index( 0 );
    return;
}

# validate the structure of the data
# - check for needed keys
# - fix some empty refs being turned into hashrefs
# - toss non author types

sub _validate_and_clean {
    my $self = shift;
    
    
    my $data = $self->_data;
    my @keys = keys %{ $data };
    
    foreach my $cpanid ( @keys ) {
        my $record = $data->{$cpanid};
        
        confess "record has no type param: " . Dumper( $record )
            unless exists $record->{type};
        
        # remove lists
        if ( !exists $record->{type} || $record->{type} eq 'list' ) {
            delete $data->{$cpanid};
            next;
        }

        # gotta be an author
        confess "Unknown type: " . Dumper( $record )
            unless $record->{type} eq 'author';

        # delete uneeded fields
        delete $record->{$_} foreach qw/type info/;

        # unknown field check
        my @valid   = qw/fullname has_cpandir asciiname homepage email/; 
        my @invalid = grep { !($_ ~~ @valid) } keys %{$record};
        
        confess sprintf(
            "Unknown keys: %s -- %s",
            join(', ', @invalid),
            Dumper( $record )
        ) if @invalid;
        
        # some records seem to be empty hashrefs, delete them
        foreach my $field ( keys %{$record} ) {
            $record->{$field} = undef if ref $record->{$field};
        }

        # force setting of has_cpandir        
        $record->{has_cpandir} = $record->{has_cpandir} ? 1 : 0;
        
        # 
        foreach my $field ( qw/fullname asciiname homepage email/ ) {
            $record->{$field} = undef unless exists $record->{$field};
        }
        
        if ( $record->{email} && $record->{email} eq 'CENSORED' ) {
            $record->{email} = undef ;
        }
        
        
    }
    return;
}

# read the file gomer!
sub _load_file {
    my $self = shift;
    
    open my $fh, '<', $self->file->stringify;
    $self->_data( $self->_xs->XMLin( $fh )->{cpanid} );
    close $fh;
    
    return;
}

sub BUILD {
    my $self = shift;
    $self->_load_file();
    $self->_validate_and_clean();
    $self->_keys( [ keys %{$self->_data} ] ); # for the iterator 
}

__PACKAGE__->meta->make_immutable; 1;