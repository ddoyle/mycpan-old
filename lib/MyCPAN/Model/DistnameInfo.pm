package MyCPAN::Model::DistnameInfo;
# lovingly ripped from CPAN::DistnameInfo version 0.10

use Moose;
use Moose::Util::TypeConstraints qw(subtype coerce);
use feature ':5.12';

# filter the package name to remove
subtype __PACKAGE__ . '::pathname' => as 'Str';
coerce __PACKAGE__ . '::pathname' => from 'Str' => via { s{//+}{/}g; $_ };

has 'dist'      => ( is => 'rw', isa => 'Maybe[Str]' );
has 'version'   => ( is => 'rw', isa => 'Maybe[Str]' );
has 'maturity'  => ( is => 'rw', isa => 'Maybe[Str]' );
has 'filename'  => ( is => 'rw', isa => 'Maybe[Str]' );
has 'cpanid'    => ( is => 'rw', isa => 'Maybe[Str]' );
has 'distvname' => ( is => 'rw', isa => 'Maybe[Str]' );
has 'extension' => ( is => 'rw', isa => 'Maybe[Str]' );
has 'pathname'  => (
    is          => 'ro',
    isa         => __PACKAGE__ . '::pathname',
    required    => 1,
    coerce      => 1,
);

sub BUILD {
    my $self = shift;
    $self->_populate();
}

# support the pathname as a single arg
around BUILDARGS => sub {
    my ( $origin, $class )  = @_;
    
    return $class->$origin( pathname => $_[0] )
        if @_ == 1 && !ref $_[0];
    return $class->$origin(@_);
};

sub _populate {
    my $self = shift;
    
    my $pathname = $self->pathname;
    
    my $distfile = $pathname;
    
    confess "invalid path: $distfile"
        unless $distfile =~ s{^(((.*?/)?authors/)?id/)?([A-Z])/(\4[A-Z])/(\5[-A-Z0-9]*)}{}x;
    
    # set the cpanid and distfile
    $self->distfile( $distfile );
    $self->cpanid( $6 );
    
    confess "invalid filename format: $distfile"
        unless $distfile =~ m{([^/]+)\.(tar\.(?:g?z|bz2)|zip|tgz)$}i
    
    $self->distvname($1);
    $self->extension($2);
    
    my $dist_version_regex = qr/
        ^
        (
            (?:
                [-+.]*
                (?:
                    [A-Za-z0-9]+ |
                    (?<=\D)_ |
                    _(?=\D)
                )*
                (?:
                    [A-Za-z]
                    (?= [^A-Za-z] | $ )
                    |
                    \d(?=-)
                )
                (?<![._-][vV])
            )+
        )
        (.*)
        $
    /xs;

    

    if ( $self->distvname =~ /$dist_version_regex/ ) {
        $self->dist($1);
        $self->version($2);
    }
    else {
        confess "Invalid distvname: " . $self->disvname;
    }
    
}

sub distname_info {
    my $file = $self->distvname;

    
    my ($dist, $version) = ();
    if ( $file =~ /$dist_version_regex/ ) {
        $self->dist($1);
        $self->version($2);
    }
    else {
        return;
    }

  if ($self->dist =~ /-undef\z/ and ! length $self->version) {
    $dist =~ s/-undef\z//;
  }

  if ($version =~ /^(-[Vv].*)-(\d.*)/) {
   
    # Catch names like Unicode-Collate-Standard-V3_1_1-0.1
    # where the V3_1_1 is part of the distname
    $dist .= $1;
    $version = $2;
  }

  # Normalize the Dist.pm-1.23 convention which CGI.pm and
  # a few others use.
  $dist =~ s{\.pm$}{};

  $version = $1
    if !length $version and $dist =~ s/-(\d+\w)$//;

  $version = $1 . $version
    if $version =~ /^\d+$/ and $dist =~ s/-(\w+)$//;

  if ($version =~ /\d\.\d/) {
    $version =~ s/^[-_.]+//;
  }
  else {
    $version =~ s/^[-_]+//;
  }

  my $dev;
  if (length $version) {
    if ($file =~ /^perl-?\d+\.(\d+)(?:\D(\d+))?(-(?:TRIAL|RC)\d+)?$/) {
      $dev = 1 if (($1 > 6 and $1 & 1) or ($2 and $2 >= 50)) or $3;
    }
    elsif ($version =~ /\d\D\d+_\d/ or $version =~ /-TRIAL/) {
      $dev = 1;
    }
  }
  else {
    $version = undef;
  }

  ($dist, $version, $dev);
}

sub new {
  my $class = shift;
  my $distfile = shift;

  $distfile =~ s,//+,/,g;

  my %info = ( pathname => $distfile );

  ($info{filename} = $distfile) =~ s,^(((.*?/)?authors/)?id/)?([A-Z])/(\4[A-Z])/(\5[-A-Z0-9]*)/,,
    and $info{cpanid} = $6;

  if ($distfile =~ m,([^/]+)\.(tar\.(?:g?z|bz2)|zip|tgz)$,i) { # support more ?
    $info{distvname} = $1;
    $info{extension} = $2;
  }

  @info{qw(dist version beta)} = distname_info($info{distvname});
  $info{maturity} = delete $info{beta} ? 'developer' : 'released';

  return bless \%info, $class;
}

sub dist      { shift->{dist} }
sub version   { shift->{version} }
sub maturity  { shift->{maturity} }
sub filename  { shift->{filename} }
sub cpanid    { shift->{cpanid} }
sub distvname { shift->{distvname} }
sub extension { shift->{extension} }
sub pathname  { shift->{pathname} }

sub properties { %{ $_[0] } }

1;

__END__

=head1 NAME

CPAN::DistnameInfo - Extract distribution name and version from a distribution filename

=head1 SYNOPSIS

  my $pathname = "authors/id/G/GB/GBARR/CPAN-DistnameInfo-0.02.tar.gz";

  my $d = CPAN::DistnameInfo->new($pathname);

  my $dist      = $d->dist;      # "CPAN-DistnameInfo"
  my $version   = $d->version;   # "0.02"
  my $maturity  = $d->maturity;  # "released"
  my $filename  = $d->filename;  # "CPAN-DistnameInfo-0.02.tar.gz"
  my $cpanid    = $d->cpanid;    # "GBARR"
  my $distvname = $d->distvname; # "CPAN-DistnameInfo-0.02"
  my $extension = $d->extension; # "tar.gz"
  my $pathname  = $d->pathname;  # "authors/id/G/GB/GBARR/..."

  my %prop = $d->properties;

=head1 DESCRIPTION

Many online services that are centered around CPAN attempt to
associate multiple uploads by extracting a distribution name from
the filename of the upload. For most distributions this is easy as
they have used ExtUtils::MakeMaker or Module::Build to create the
distribution, which results in a uniform name. But sadly not all
uploads are created in this way.

C<CPAN::DistnameInfo> uses heuristics that have been learnt by
L<http://search.cpan.org/> to extract the distribution name and
version from filenames and also report if the version is to be
treated as a developer release

The constructor takes a single pathname, returning an object with the following methods

=over

=item cpanid

If the path given looked like a CPAN authors directory path, then this will be the
the CPAN id of the author.

=item dist

The name of the distribution

=item distvname

The file name with any suffix and leading directory names removed

=item filename

If the path given looked like a CPAN authors directory path, then this will be the
path to the file relative to the detected CPAN author directory. Otherwise it is the path
that was passed in.

=item maturity

The maturity of the distribution. This will be either C<released> or C<developer>

=item extension

The extension of the distribution, often used to denote the archive type (e.g. 'tar.gz')

=item pathname

The pathname that was passed to the constructor when creating the object.

=item properties

This will return a list of key-value pairs, suitable for assigning to a hash,
for the known properties.

=item version

The extracted version

=back

=head1 AUTHOR

Graham Barr <gbarr@pobox.com>

=head1 COPYRIGHT 

Copyright (c) 2003 Graham Barr. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
