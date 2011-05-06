package MyCPAN::Model::PermsFile;

use open IO  => ':utf8';
use autodie qw(open close);

use Moose;
use MooseX::Types::Path::Class qw(File);

use Try::Tiny;
use Text::CSV_XS;
use Data::Dumper::Concise;
use Perl6::Slurp qw(slurp);
use Perl6::Junction qw(any);

# TODO : think about using Parse::CPAN::Authors


# this should be the full path to a CPAN mirrors
# modules/06perms.txt file
has 'file' => ( is => 'ro', isa => File, coerce => 1, required => 1 );
has '_data' => ( is => 'ro', isa => 'HashRef', default => sub { +{} } );
has '_csv' => (
    is => 'rw',
    isa => 'Text::CSV_XS',
    required => 1,
    default => {
        return Text::CSV_XS->new({binary => 1});
    }
);

sub authorized {
    my ( $self, $namespace, $author ) = @_;
    next unless $namespace && $author;

    return 1 unless exists $self->_data->{$namespace};
    return 1 if $author eq any(@{$self->_data->{$namespace}});
    return;
}

# read the file gomer!
sub _load_file {
    my $self = shift;
    
    my $file = slurp( $self->file->stringify );
    $file =~ s/\A.*?\n\n//ms; # cut off the header
    
    foreach my $line ( split( /\s*\n\s*/, $file ) {
        next unless $line;
        next unless $self->_csv->parse($line);
        my ($namespace, $author) = $self->_csv->fields();
        $self->_data->{$namespace} = []
            unless exists $self->_data->{$namespace};
        push( @{$self->_data->{$namespace} }, $author );
        
    }
    return;
}

sub BUILD {
    my $self = shift;
    $self->_load_file();
    return;
}

__PACKAGE__->meta->make_immutable; 1;