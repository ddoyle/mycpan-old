package MyCPAN::Model::PackageFile;
# ripped and modded from CPAN::ParseDistribution


use strict;
use warnings;
use feature qw(say);
#use open IO => 'utf8';


use vars qw($VERSION);

$VERSION = '0.1';

use Cwd qw(getcwd abs_path);

use File::Temp qw(tempdir);
use File::Find::Rule;
use File::Path;

use Data::Dumper::Concise;
use Archive::Extract;
use YAML qw(LoadFile);
use Safe;

our %fix_regex = (
    #'Acme-CPANAuthors' => [ qr/# see RT #\d+/ ],
    #'aliased-factory' => [qr/VERSION = v([\.\d]+)/]
);

sub new {
    my ( $class, $file, $ignore_module ) = @_;
    
    $ignore_module = [] unless defined $ignore_module;
    
    die "file parameter is mandatory" unless $file;
    die "$file doesn't exist" if !-e $file;
    die "$file looks like a ppm\n"
      if $file =~ /\.ppm\.(tar(\.gz|\.bz2)?|tbz|tgz|zip)$/i;
    die "$file isn't the right type"
      if $file !~ /\.(tar(\.gz|\.bz2)?|tbz|tgz|zip)$/i;
    $file = abs_path($file);

    # dist name and version
    ( my $dist = $file ) =~ s{(^.*/|\.(tar(\.gz|\.bz2)?|tbz|tgz|zip)$)}{}gi;
    $dist =~ /^(.*)-(\d.*)$/;
    ( $dist, my $distversion ) = ( $1, $2 );
    die "Can't index perl itself ($dist-$distversion)"
      if $dist =~ /^(perl|ponie|kurila|parrot|Perl6-Pugs|v6-pugs)$/;

    bless {
        file        => $file,
        modules     => {},
        dist        => $dist,
        distversion => $distversion,
        ignore_module => $ignore_module,
        tempdir       => undef,
    }, $class;
}

# takes a filename, unarchives it, returns the directory it's been
# unarchived into
sub _unarchive {
    my $self    = shift;
    my $tempdir = tempdir( DIR => '/tmp/rd' );

    my $archive = Archive::Extract->new( archive => $self->{file} );
    die "unable to extract $self->{file}" unless $archive->extract( to => $tempdir );
    $self->{tempdir} = $tempdir;
    return $tempdir;
}

sub _clean_line {
    my $line = shift;
    return '' unless defined $line;

    $line =~ s/\buse\s+version\b.*?;//gs;

    # qv broke some time between version.pm 0.74 and 0.82
    # so just extract it and hope for the best
    $line =~ s/
        (
            version->new\(
        )
        qw\$
        Revision:\s*
        (
            [\d\.]+
            (?:_\d+)?
        )
        \s*
        \$
        (\))
    /$1'$2'$3/x; # App-ClusterSSH 4.004_04 App::ClusterSSH::Host
    $line =~ s/
        \b
        (?:(?:version::)?qv|version->new)
        \s*
        \(
            \s*
            (["']?)
            (?:v)?
            ([\d\.]+(?:_\d+)?)
            # matches quote char:
            \1 
            \s*
        \)
        (?:->numify(?:\(\s*\))?)?
        \s*
    /"$2"/x;
    $line =~ s/
        \b
        qv
        \s+
        (["']?)
        (?:v)?
        ([\d\.]+(?:_\d+)?)
        \1
        (?:->numify(?:\(\s*\))?)?
        \s*
    /"$2"/x; # no brackets
    $line =~ s/\buse\s+vars\b//g;
    $line =~ s/(?<!\$)(?<!Revision: )\#.*$//; # get rid of some comments (Acme::Debug)

    return $line;
    
}

# adapted from PAUSE::pmfile::parse_version_safely in mldistwatch.pm
sub _parse_version_safely {
    my ($parsefile) = @_;
    my $result;
    my $eval;
    
    local $/ = "\n";
    
    open my $fh, '<', $parsefile or die "Could not open '$parsefile': $!";
    my $inpod = 0;
    while (my $line  = <$fh>) {
        chomp($line);

        $inpod = ( $line =~ /^=(?!cut)/ ? 1 : ( $line =~ /^=cut/ ? 0 : $inpod ) );

        next if $inpod || $line =~ /^\s*#/;
        # Authen::Simple::Apache 0.03
        # there's some fuckery going on here where it's trying to detect
        # what version of mod_perl it's running under. I'm just gonna kill
        # any "version" line that begins with a conditional
        next if $line =~ /^\s*\b(?:if|elsif|else)\s*\(/; 
        next unless $line =~ /
            ([\$*])
            (
                (?:[\w\:\']*)
                \bVERSION
            )
            \b.*\=\s*.+
        /x;
        
        my ( $sigil, $var ) = ( $1, $2 );
        my $current_parsed_line = $line;

        $line = _clean_line($line);

        # no requires allowed
        # modules like AnyEvent::RPC::Enc in AnyEvent-RPC use the
        # main modules version and get it by requiring it
        # CPAN doesn't see it so therefore I choose not. :)
        #last if $line =~ /(?:\b\b(?:;use|require)\b/;

        {
            local $^W = 0;
            no strict;
            my $c = Safe->new();
            $c->deny(
                qw(
                  tie untie tied chdir flock ioctl socket getpeername
                  ssockopt bind connect listen accept shutdown gsockopt
                  getsockname sleep alarm entereval reset dbstate
                  readline rcatline getc read formline enterwrite
                  leavewrite print sysread syswrite send recv eof
                  tell seek sysseek readdir telldir seekdir rewinddir
                  lock stat lstat readlink ftatime ftblk ftchr ftctime
                  ftdir fteexec fteowned fteread ftewrite ftfile ftis
                  ftlink ftmtime ftpipe ftrexec ftrowned ftrread ftsgid
                  ftsize ftsock ftsuid fttty ftzero ftrwrite ftsvtx
                  fttext ftbinary fileno ghbyname ghbyaddr ghostent
                  shostent ehostent gnbyname gnbyaddr gnetent snetent
                  enetent gpbyname gpbynumber gprotoent sprotoent
                  eprotoent gsbyname gsbyport gservent sservent
                  eservent  gpwnam gpwuid gpwent spwent epwent
                  getlogin ggrnam ggrgid ggrent sgrent egrent msgctl
                  msgget msgrcv msgsnd semctl semget semop shmctl
                  shmget shmread shmwrite require dofile caller
                  syscall dump chroot link unlink rename symlink
                  truncate backtick system fork wait waitpid glob
                  exec exit kill time tms mkdir rmdir utime chmod
                  chown fcntl sysopen open close umask binmode
                  open_dir closedir
                  ), ( $] >= 5.010 ? qw(say) : () )
            );
            $c->share_from( __PACKAGE__, [qw(qv)] );

            $eval = qq{local ${sigil}${var}; \$$var = undef; do { $line }; \$$var};
            $eval =~ s/[\r\n]//g;
            $eval =~ s/\s\s+/ /g;
            $eval =~ s/\`//g; # no bacticks
            
            # fixes for specific dists
            #if ( exists $fix_regex{ $self->{dist} } ) {
            #    foreach my $regex ( @{ $fix_regex{ $self->{dist} } } ) {
            #        $eval =~ s/$regex//;
            #    }
            #}
            eval {
                local $SIG{ALRM} = sub { die("Safe compartment timed out\n"); };
                alarm(5);    # Safe compartment can't turn this off
                $result = $c->reval($eval);
                alarm(0);
                die($@) if ($@);
            };
            #$result = $eval;
        };

        # stuff that's my fault because of the Safe compartment
        # warn($eval) if($@);
        if ( $@ =~ /'(?:use|require)' trapped by operation mask/) {
            $result = undef;
        }
        elsif ( $@ =~ /trapped by operation mask|safe compartment timed out/i ) {
            #warn("Unsafe code in \$VERSION\n$@\n$parsefile\n$eval");
            
            #die("Unsafe code in \$VERSION\n$@\n$parsefile\n$eval");
            #$result = undef;
            
            $result = [
                "<<UNSAFE>>",
                $eval,
                {
                    line => $current_parsed_line,
                    file => $parsefile,
                    err  => $@,
                    sigil => $sigil,
                    var   => $var,
                },
            ];
        }
        elsif ($@) {
            #warn "_parse_version_safely: "
            #die "_parse_version_safely: "
            #  . Dumper(
            #    {
            #        eval => $eval,
            #        line => $current_parsed_line,
            #        file => $parsefile,
            #        err  => $@,
            #        sigil => $sigil,
            #        var   => $var,
            #    }
            #  )
            #  . "\n" . $eval;
        }
        last;
    }
    close $fh;

    # # version.pm objects come out as Safe::...::version objects,
    # # which breaks weirdly
    # bless($result, 'version') if(ref($result) =~ /::version$/);
    return $result;
}

=head2 isdevversion

Returns true or false depending on whether this is a developer-only
or trial release of a distribution.  This is determined by looking for
an underscore in the distribution version.

=cut

sub isdevversion {
    my $self = shift;
    return 1 if ( $self->distversion() =~ /_/ );
    return 0;
}

=head2 modules

Returns a hashref whose keys are module names, and their values are
the versions of the modules.  The version number is retrieved by
eval()ing what looks like a $VERSION line in the code.  This is done
in a C<Safe> compartment, but may be a security risk if you do this
with untrusted code.  Caveat user!

=cut

sub modules {
    my $self = shift;
    if ( !( keys %{ $self->{modules} } ) ) {
        $self->{_modules_runs}++;
        my $tempdir = $self->_unarchive( );

        my $meta =
          ( File::Find::Rule->name('META.yml')->file()->in($tempdir) )[0];
        my @ignore = qw(t inc xt examples?);
        my %ignorefiles;
        my %ignorepackages;
        my %ignorenamespaces;
        if ( $meta && -e $meta ) {
            my $yaml = eval { LoadFile($meta); };
            if (   !$@
                && UNIVERSAL::isa( $yaml, 'HASH' )
                && exists( $yaml->{no_index} )
                && UNIVERSAL::isa( $yaml->{no_index}, 'HASH' ) )
            {
                if ( exists( $yaml->{no_index}->{directory} ) ) {
                    if ( eval { @{ $yaml->{no_index}->{directory} } } ) {
                        push(@ignore, map { s{/+$}{}; $_ } @{ $yaml->{no_index}->{directory} } );
                    }
                    elsif ( !ref( $yaml->{no_index}->{directory} ) ) {
                        push(@ignore, map { s{/+$}{}; $_ } $yaml->{no_index}->{directory} );
                    }
                }
                if ( exists( $yaml->{no_index}->{file} ) ) {
                    if ( eval { @{ $yaml->{no_index}->{file} } } ) {
                        %ignorefiles = map { $_, 1 } @{ $yaml->{no_index}->{file} };
                    }
                    elsif ( !ref( $yaml->{no_index}->{file} ) ) {
                        $ignorefiles{ $yaml->{no_index}->{file} } = 1;
                    }
                }
                if ( exists( $yaml->{no_index}->{package} ) ) {
                    if ( eval { @{ $yaml->{no_index}->{package} } } ) {
                        %ignorepackages = map { $_, 1 } @{ $yaml->{no_index}->{package} };
                    }
                    elsif ( !ref( $yaml->{no_index}->{package} ) ) {
                        $ignorepackages{ $yaml->{no_index}->{package} } = 1;
                    }
                }
                if ( exists( $yaml->{no_index}->{namespace} ) ) {
                    if ( eval { @{ $yaml->{no_index}->{namespace} } } ) {
                        %ignorenamespaces = map { $_, 1 } @{ $yaml->{no_index}->{namespace} };
                    }
                    elsif ( !ref( $yaml->{no_index}->{namespace} ) ) {
                        $ignorenamespaces{ $yaml->{no_index}->{namespace} } = 1;
                    }
                }
            }
        }

        # find modules
        my $ignore = join('|',@ignore);
        
        my @PMs = grep {
            my $pm = $_;
            #say '        ',$pm;
            $pm !~ m{^\Q$tempdir\E(?:/[^/]+)+/($ignore)/}
              && !grep { $pm =~ m{^\Q$tempdir\E/[^/]+/$_$} }
              ( keys %ignorefiles )
        } File::Find::Rule->file()->name('*.pm')->in($tempdir);
        foreach my $PM (@PMs) {
            local $/ = undef;
            my $version = _parse_version_safely($PM);
            open( my $fh, $PM ) || die("Can't read $PM\n");
            $PM = <$fh>;
            close($fh);

            # from PAUSE::pmfile::packages_per_pmfile in mldistwatch.pm
            if ( $PM =~ /\bpackage[ \t]+([\w\:\']+)\s*($|[};])/ ) {
                my $module = $1;
                $self->{modules}->{$module} = $version
                  unless ( exists( $ignorepackages{$module} )
                    || ( grep { $module =~ /${_}::/ } keys %ignorenamespaces )
                  );
            }
        }
        rmtree($tempdir);
    }
    return $self->{modules};
}

=head2 dist

Return the name of the distribution. eg, in the synopsis above, it would
return 'Some-Distribution'.

=cut

sub dist {
    my $self = shift;
    return $self->{dist};
}

=head2 distversion

Return the version of the distribution. eg, in the synopsis above, it would
return 1.23.

Strictly speaking, the CPAN doesn't have distribution versions -
Foo-Bar-1.23.tar.gz is not considered to have any relationship to
Foo-Bar-1.24.tar.gz, they just happen to coincidentally have rather
similar contents.  But other tools, such as those used by the CPAN testers,
do treat distributions as being versioned.

=cut

sub distversion {
    my $self = shift;
    return $self->{distversion};
}

=head1 SECURITY

This module executes a very small amount of code from each module that
it finds in a distribution.  While every effort has been made to do
this safely, there are no guarantees that it won't let the distributions
you're examining do horrible things to your machine, such as email your
password file to strangers.  You are strongly advised to read the source
code and to run it in a very heavily restricted user account.

=head1 LIMITATIONS, BUGS and FEEDBACK

I welcome feedback about my code, including constructive criticism.
Bug reports should be made using L<http://rt.cpan.org/> or by email,
and should include the smallest possible chunk of code, along with
any necessary XML data, which demonstrates the bug.  Ideally, this
will be in the form of a file which I can drop in to the module's
test suite.

=cut

=head1 SEE ALSO

L<http://pause.perl.org/>

L<dumpcpandist>

=head1 AUTHOR, COPYRIGHT and LICENCE

Copyright 2009-2010 David Cantrell E<lt>david@cantrell.org.ukE<gt>

Contains code originally from the PAUSE by Andreas Koenig.

This software is free-as-in-speech software, and may be used,
distributed, and modified under the terms of either the GNU
General Public Licence version 2 or the Artistic Licence.  It's
up to you which one you use.  The full text of the licences can
be found in the files GPL2.txt and ARTISTIC.txt, respectively.

=head1 CONSPIRACY

This module is also free-as-in-mason software.

=cut

1;
