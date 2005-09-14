package TestApp;

use strict;
use Catalyst;
use Data::Dumper;

our $VERSION = '0.01';

TestApp->config(
    name => 'TestApp',
);

TestApp->setup( qw/RequireSSL/ );

sub default : Private {
    my ( $self, $c ) = @_;
    
}

1;
