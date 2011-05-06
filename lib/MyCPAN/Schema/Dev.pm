package MyCPAN::Schema::Dev;

use base qw/DBIx::Class::Schema::Loader/;

__PACKAGE__->loader_options( naming => 'current', use_namespaces =>  1 );

1;