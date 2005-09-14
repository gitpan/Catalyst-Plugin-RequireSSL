package TestApp::C::SSL;

use strict;
use base 'Catalyst::Base';

sub secured : Local {
    my ( $self, $c ) = @_;
    
    $c->require_ssl;
    
    $c->res->output( 'Secured' );
}

sub unsecured : Local {
    my ( $self, $c ) = @_;
    
    $c->res->output( 'Unsecured' );
}

1;
