package MyCPAN::Loader::Distributions;

use feature ':5.10';

use Moose;
use Perl6::Junction qw(any none);
use MooseX::Params::Validate;

use MyCPAN::Model::PermsFile;

use CPAN::ParseDistribution;

extends 'MyCPAN::Loader';
with qw/
    MyCPAN::Loader::Role::Index
    MyCPAN::Loader::Role::Perms
/;

has 'only_process' => (
    traits  => [qw/Hash/],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
    handles => { has_only_process => 'count' },
);

has 'skip' => (
    traits  => [qw/Hash/],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
    handles => { has_skips => 'count' },
);

has 'current_dist_id'       => ( is => 'rw', isa => 'Int', clearer => '_clear_dist' );
has 'current_release_id'    => ( is => 'rw', isa => 'Int', clearer => '_clear_rel' );
has 'current_release_info'  => ( is => 'rw', isa => 'CPAN::DistnameInfo', clearer => '_clear_rel_info' );

sub _clear_all {
    my $self = shift;
    $self->_clear_dist;
    $self->_clear_rel;
    $self->_clear_rel_info;
}

sub get_release_info {
    my $self = shift;
    my $release_path = shift;
    die unless defined $release_path;
    $self->current_release_info(
        $self->index->get_release_info( $release_path )
    );
    return;
}

sub will_process {
    my ( $self, $distname ) = @_;
    
    return unless defined $distname;
    
    # includes have priority
    return $distname eq any( @{ $self->includes } ) if $self->has_includes;
    return ! exists $self->skips->{$distname}       if $self->has_skips;
    
    # has neither so we're good.
    return 1;
}

override 'run' => sub {
    my $self = shift;

    # go through the dists    
    my @distnames = sort { lc($a) cmp lc($b) } keys %{ $self->index->dists };

    # iterate over dists
    foreach my $distname ( @distnames ) {

        next unless $self->will_process($distname);

        say "Processing $distname";
        
        $self->_clear_all;

        my $dist = $self->schema->resultset('Dist')->find_or_create(
            {
                name                => $distname,
                data_load_id        => $self->data_load_id,
                is_backpan          => $self->is_backpan,
                ignore              => 0,
                processed_archive   => 0,
            },
            { key => 'name'}
        );
        
        # only process this dist if we haven't previous set it to ignore
        next if $dist->ignore;
        
        # set the current dist
        $self->current_dist_id( $dist->id );
        
        # set the backplan flag appropriately
        $dist->is_backpan = $self->is_backpan
            if $dist->is_backpan != $self->is_backpan;
                
        # iterate over releases
        my $processed_release = 0;
        
        foreach ( @{ $self->index->dists->{$distname} } ) {
            $processed_release = 1 if $self->_process_release($_);
        }

        # if we've processed a release, update the "latest" info
        $self->_update_latest_release( $dist ) if $processed_release;

        $dist->update if $dist->is_changed;

    }
};

# return 1 or zero to see if we processed it
# only process the DistnameInfo
# we'll unzip the tarball later as determined by process_archive
# - determine module versions
# - Maybe try and do a diff on Changes
# we'll process the meta as determined by process_meta
sub _process_release {
    my ( $self, $release_path ) = @_;

    say "    $release_path";

    $self->get_release_info( $release_path );

    my $rel_info = $self->current_release_info;

    my $release = $self->schema->resultset('Release')->find_or_new({
        dist_id  => $self->current_dist_id,
        version  => $rel_info->version,
        pathname => $rel_info->pathname,
    });
    
        # skipping this means we only stat the release if we need the mtime
    # will do the mtime if we're forcing it
    return if $release->in_storage && !$self->force;

    # if we've gotten here, then the basic release info has never been saved
    
    my $authorized = $self->perms->authorized(
        $self->distname_to_modulename($rel_info->dist),
        $rel_info->cpanid
    ) ? 1 : 0;
    
    $release->set_columns({
        released_on            => $self->cpan_dir->file($release_path)->stat->mtime,
        is_developer           => $rel_info->maturity eq 'released' ? 0 : 1,
        is_backpan             => $self->is_backpan,
        data_load_id           => $self->data_load_id,
        authorized             => $authorized,
        ignore                 => $authorized ? 0 : 1, # start with authorized as the "ignore"
        # this one should never fail because the author SHOULD be
        # indexed in the authors file already.
        # Lets see if I'm wrong!
        released_by_author_id  => $self->schema->resultset('Author')->find({
                                    cpanid => $rel_info->cpanid
                                  })->id,
    })->insert;

    #$self->current_release_id( $release->id );
    #$self->_process_modules() if $authorized;
    #$self->_process_release_meta( distinfo => $distinfo);

    return 1;

}

#sub _process_modules {
#    my $self = shift;
#    
#    my $parse_dist = CPAN::ParseDistribution->new(
#        $self->cpan_dir->file(
#            $self->current_release_info->pathname
#        )->stringify
#    );
#
#    my $modules = $parse_dist->modules(); # hashref of modname => version
#
#    foreach my $module_name ( sort keys %{$modules} ) {
#        
#        my $module = $self->schema->resultset('Module')->find_or_new({
#            name    => $module_name,
#            dist_id => $self->current_dist_id,
#        });
#        
#        if ( ! $module->in_storage ) {
#            $module->data_load_id( $self->data_load_id );
#            $module->insert;
#        }
#
#        my $module_release = $self->schema->resultset('ModuleRelease')->create({
#            module_id   => $module->id,
#            release_id  => $self->current_release_id,
#            version     => $modules->{$module_name} // undef 
#        });
#        
#        
#    }
#    
#}

#sub _process_release_meta {
#    my ($self, $distinfo) = validated_list(
#        \@_,
#        distinfo => { isa => 'CPAN::DistnameInfo' },
#        dist_id  => { isa => 'Int' },
#    );
#
#    $metafilename = $distinfo->pathname;
#    $metafilename =~ s/\.(?:tar\.(?:bz2|gz|Z)|t[bg]z|zip)$//i;
#    $metafilename .= '.meta';
#
#    $filepath = $self->cpan_dir->file($metafilename)->stringify;
#    
#}

# update the id's of the latest full and dev releases
sub _update_latest_release {
    my $self = shift;
    my $dist = shift;
    return unless defined $dist;
    
    my $rel_rs = $self->schema->resultset('Release');

    my $latest_release = $rel_rs->find(
        { dist_id => $dist->id, is_developer => 0 },
        { order_by => { -desc => 'released_on' }, rows => 1 }
    );
    $dist->set_column( latest_release_id => $latest_release->id )
        if defined $latest_release;
        
    my $latest_dev_release = $rel_rs->find(
        { dist_id => $dist->id, is_developer => 1 },
        { order_by => { -desc => 'released_on' }, rows => 1 }
    );
    $dist->set_column( latest_dev_release_id => $latest_dev_release->id )
        if defined $latest_dev_release;

    return;    
}
__PACKAGE__->meta->make_immutable(); 1;