#!/usr/bin/perl
use strict;
use warnings;
use feature ':5.10';
#use open IO => 'utf8';
$| = 1; # unbuffered output

use FindBin;
use lib "$FindBin::Bin/../lib/";

use Perl6::Junction qw(any);
use Try::Tiny;

use Path::Class::Dir;
use Path::Class::File;
use File::Temp;

use MyCPAN::Model::DistributionIndex;
use MyCPAN::Model::PackageFile;

my @exclude_module_verision_check = qw/
    Acme-BadExample
/;

say STDERR "Loading Index";
my $index = MyCPAN::Model::DistributionIndex->new(
    file => '/home/mycpan/cpan/indices/find-ls.gz'
);
say STDERR "Done Loading";

# so I can specify a start point
my $start_at = lc('NetApp');

my @distnames = grep { lc($_) ge $start_at }
                sort { lc($a) cmp lc($b) }
                keys %{$index->dists};
my $limit = 100;

my $exclude_dist = qr{
    (?:
        ^
        (?:
            Acme-BadExample           # TODO, fix this one
          | AltaVista-PerlSDK         # cpan doesn't index it and has some weirdness
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
            perl5\.\d+
        )
    )
}x;

my $exclude_release = qr{
    (?:
        ^
        (?:
          # unauthorized and weirdness in the tgz file
            authors/id/K/KG/KGJERDE/Audio-Wav-0\.03\.tar\.gz               
          # corrupt tar file and module isn't in proper file hierchy (ProxyAny.pm is in the root)
          | authors/id/Q/QJ/QJZHOU/LWP-UserAgent-ProxyAny-1\.02.tar.gz 
          # corrupt and possibly unauthorized
          | authors/id/P/PT/PTILL/mod_perl-1\.11_1-apache-1\.3b7dev-bin-bindist1-i386-win95-vc5\.zip
          # some old fucky perl dists (we won't go back far)
        )
        $
    )
    |
    (?:
        # ppm files 
        \.ppm
        \.
        (?:tar(?:\.gz|\.bz2?)?|t[gb]z|zip)
        $
    )
    |
    (?:
        /perl5\.\d+
    )
};

my @exclude_dists = (
    'Acme-BadExample', # TODO, fix this one
    'AltaVista-PerlSDK', # cpan doesn't index it and has some weirdness
    'AltaVista-SDKLinguistics', # cpan doesn't index it and has some weirdness
    'perl-5.6-info', # not sure wtf this is
    'pod2texi-0.1', # not sure of this either
    'Harvey', # not indexed and HUGE!
    'metaconfig-for-Perl', # provides no modules
    'parrot', # it's not actually parrot that i can see and seems busted
);

my @exclude_release = (
    'authors/id/K/KG/KGJERDE/Audio-Wav-0.03.tar.gz', # unauthorized and weirdness in the tgz file
    'authors/id/Q/QJ/QJZHOU/LWP-UserAgent-ProxyAny-1.02.tar.gz', # corrupt tar file and module isn't in proper file hierchy (ProxyAny.pm is in the root)
    'authors/id/P/PT/PTILL/mod_perl-1.11_1-apache-1.3b7dev-bin-bindist1-i386-win95-vc5.zip', # corrupt and possibly unauthorized
);

# TO FIX: SKIP VERSION CHECK
# Acme-BadExample
# authors/id/A/AS/ASNMTAP/ASNMTAP-3.000.011.tar.gz - weird chars in version

# DO NOT INDEX AT ALL:
# AltaVista-PerlSDK -- corrup tar
# AltaVista-SDKLinguistics -- ditto

my $progress_filename = Path::Class::Dir->new($FindBin::Bin, 'XXversion.txt' );
my $error_filename    = Path::Class::Dir->new($FindBin::Bin, 'ERROR_version.txt');


open my $out_fh, '>', $progress_filename->stringify or die $!;
open my $err_fh, '>', $error_filename->stringify or die $!;

sub output { say $out_fh @_; }
sub err    { say $err_fh @_; }


sub cleanup {
    File::Temp::cleanup();
    # make double sure
    system('rm -rf /tmp/rd/* > /dev/null 2> /dev/null');
    
}

my $count = 0;

foreach my $distname ( @distnames ) {

    next if $distname =~ $exclude_dist;
    
    #next unless $distname eq 'Jifty';
    
    $count++;
    output($distname);
    
    foreach my $release ( sort @{ $index->dists->{$distname} } ) {
        next if $release =~ $exclude_release;
        output('    ', $release);
        my $file = '/home/mycpan/cpan/' . $release;
        my $pfile = undef;
        
        try   { $pfile = MyCPAN::Model::PackageFile->new($file); }
        catch {
            err( "<<NEW-ERROR>> $distname - $release\n", $_ );
            cleanup();
        };
        next unless defined $pfile;
        
        
        my $modules = undef;
        try { $modules = $pfile->modules; }
        catch {
            err( "<<MODULES-ERROR>> $distname - $release\n", $_ );
            cleanup();
        };
        next unless defined $modules;
        
        foreach my $module ( sort keys %{$modules} ) {
            #say join(',', $distname, $pfile->distversion, $module, $modules->{$module} // 'NO VERSION');
            #say '        ',join("\t",$module, $modules->{$module} );
            if ( !defined $modules->{$module} || !ref $modules->{module}) {
                output('        ',join("\t",$module, $modules->{$module} // 'NO VERSION') );
                next;
            }
            
            err("<<EVAL-ERROR>> $distname - $release - $module\n", Dumper($modules->{$module}) );
            
        }

        cleanup();    
    }
    #last if $count >= $limit;
}

close $out_fh;
close $err_fh;