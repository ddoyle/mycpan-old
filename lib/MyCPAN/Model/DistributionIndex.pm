package MyCPAN::Model::DistributionIndex;

use feature ':5.10';

use Moose;
use MooseX::Types::Path::Class qw(File Dir);
use namespace::autoclean;

use IO::Zlib;
use IO::File;
use Try::Tiny;
use CPAN::DistnameInfo;
use Data::Dumper::Concise;

# in a cpan mirror, the indicies/find-ls.gz
has 'cpan_dir' => (
    is            => 'rw',
    isa           => Dir,
    coerce        => 1
);

has 'file' => (
    is          => 'rw',
    isa         => File,
    required    => 1,
    coerce      => 1,
    trigger     => sub {
        my ($self, $new) = @_;
        confess "file doesn't exist" if defined $new && ! -f $new->stringify;
        $self->cpan_dir( $new->dir->parent );
        
    },
);

has 'dists' => (
    traits      => [qw/Hash/],
    is          => 'rw',
    isa         => 'HashRef[Str]',
    default     => sub { {} },
    handles     => { 'how_many' => 'count' },
);

has 'release_count' => (
    traits  => [qw/Counter/],
    is      => 'rw',
    isa     => 'Int',
    default => 0,
    handles => { inc_release_count => 'inc' },
    
);

has '_archive_regex' => (
    is          => 'ro',
    isa         => 'RegexpRef',
    required    => 1,
    default     => sub {
        qr{
            (?<!\.ppm) # no ppm's
            \.
            ( tar\.bz2 | tar\.gz | tar\.Z | tgz | tbz | zip )
            $
        }ix
    },
);

#                    Acme-BadExample           # TODO, fix this one
has 'exclude_dist' => (
    is      => 'ro',
    isa     => 'RegexpRef',
    default => sub {
        qr{
            (?:
                ^
                (?:
                    AltaVista-PerlSDK         # cpan doesn't index it and has some weirdness
                  | AltaVista-SDKLinguistics  # cpan doesn't index it and has some weirdness
                  | perl-5\.6-info            # not sure wtf this is
                  | pod2texi-0.1              # not sure of this either
                  | Harvey                    # not indexed and HUGE!
                  | metaconfig-for-Perl       # provides no modules
                  | parrot                    # it's not actually parrot that i can see and seems busted
                )
                $
            )
            |
            (?:
                ^
                (?:
                    perl5\.\d+  # we only want reasonably modern perl versions
                )
            )
        }ix
    },
    
)

sub BUILD {
    my $self = shift;
    $self->_parse;
}


# adapated from Parse::CPAN::Distributions
sub _parse {
    my $self = shift;
    my $temp = 0;

    #print STDERR "#file=$self->{file}\n";

    my $file = $self->file->stringify;
    
    my $fh;
    try {
        $fh = ( $file =~ /\.gz$/i
                ? IO::Zlib->new( $file, 'rb' )
                : IO::File->new( $file, 'r'  )
              );
    }
    catch {
        confess "Failed to open $file: $_";
    };
    confess "Got UNDEF: Failed to open file ($file)" unless defined $fh;
    
    my $archive = $self->_archive_regex;

    while( my $line = $fh->getline ) {
        next unless $line =~ m{\s(authors/id/[A-Z]/../[^/\s]+/[^/\s]+$archive)$};

        my $release_path = $1;
        my $d = $self->get_release_info($release_path);

        next unless $d && $d->dist && $d->version;

        my $release_file = $self->cpan_dir->file($release_path)->stringify;
        confess "can't find release file: " . $release_file
            unless -f $release_file;
        
        # init array
        $self->dists->{$d->dist} = [] unless exists $self->dists->{$d->dist};
        push( @{ $self->dists->{$d->dist} }, $release_path );
        
        $self->inc_release_count;
    }
    $fh->close;
}

sub get_release_info {
    my $self         = shift;
    my $release_path = shift;
    return unless defined $release_path;
    
    return CPAN::DistnameInfo->new($release_path);
}

__PACKAGE__->meta->make_immutable; 1;