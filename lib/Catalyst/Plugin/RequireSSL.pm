package Catalyst::Plugin::RequireSSL;

use strict;
use base qw/Class::Accessor::Fast/;
use NEXT;

our $VERSION = '0.01';

__PACKAGE__->mk_accessors( '_require_ssl' );

=head1 NAME

Catalyst::Plugin::RequireSSL - Force SSL mode on select pages

=head1 SYNOPSIS

    use Catalyst 'RequireSSL';
    
    MyApp->config->{require_ssl} = {
        https => 'secure.mydomain.com',
        http => 'www.mydomain.com',
        remain_in_ssl => 0,
    };

    $c->require_ssl;

=head1 DESCRIPTION

Use this plugin if you wish to selectively force SSL mode on some of your web pages, 
for example a user login form or shopping cart.

Simply place $c->require_ssl calls in any controller method you wish to be secured. 

This plugin will automatically disable itself if you are running under the standalone
HTTP::Daemon Catalyst server.  A warning message will be printed to the log file whenever
an SSL redirect would have occurred.

=head1 WARNINGS

If you utilize different servers or hostnames for non-SSL and SSL requests, and you rely
on a session cookie to determine redirection (i.e for a login page), your cookie must
be visible to both servers.  For more information, see the documentation for the Session plugin
you are using.

=head1 CONFIGURATION

Configuration is optional.  You may define the following configuration values:

    https => $ssl_host
    
If your SSL domain name is different from your non-SSL domain, set this value.

    http => $non_ssl_host
    
If you have set the https value above, you must also set the hostname of your non-SSL
server.

    remain_in_ssl
    
If you'd like your users to remain in SSL mode after visiting an SSL-required page, you can
set this option to 1.  By default, users will be redirected back to non-SSL mode as soon as
possible.

=head2 METHODS

=over 4

=item require_ssl

Call require_ssl in any controller method you wish to be secured.

    $c->require_ssl;

The browser will be redirected to the same path on your SSL server.  POST requests
are never redirected.

=cut

sub require_ssl {
    my $c = shift;
    
    $c->_require_ssl( 1 );
      
    unless ( $c->req->secure || $c->req->method eq "POST" ) {
        if ( $c->config->{require_ssl}->{disabled} ) {
            $c->log->warn( "RequireSSL: Would have redirected to " . $c->_redirect_uri( 'https' ) );
        } else {
            $c->res->redirect( $c->_redirect_uri( 'https' ) );
        }
    }
}

=item finalize (extended)

Redirect back to non-SSL mode if necessary.

=cut

sub finalize {
    my $c = shift;
    
    # redirect unless:
    # we're not in SSL mode,
    # it's a POST request,
    # we're already required to be in SSL for this request,
    # or the user doesn't want us to redirect
    unless ( !$c->req->secure
      || $c->req->method eq "POST"
      || $c->_require_ssl
      || $c->config->{require_ssl}->{remain_in_ssl} ) {
          $c->res->redirect( $c->_redirect_uri( 'http' ) );
    }
    
    return $c->NEXT::finalize(@_);    
}

=item setup

Setup default values.

=cut

sub setup {
    my $c = shift;
    
    $c->NEXT::setup(@_);
    
    # disable the plugin when running under certain engines which don't support SSL
    # XXX: I didn't include Catalyst::Engine::Server here as it may be used as a backend
    # in a proxy setup.
    if ( $c->engine eq "Catalyst::Engine::HTTP" ) {
        $c->config->{require_ssl}->{disabled} = 1;
        $c->log->warn( "RequireSSL: Disabling SSL redirection while running under " . $c->engine );
    }
}

=item _redirect_uri

Generate the redirection URI.

=cut

sub _redirect_uri {
    my ( $c, $type ) = @_;
    
    # XXX: Cat needs a $c->req->host method...
    # until then, strip off the leading protocol from base
    unless ( $c->config->{require_ssl}->{$type} ) {
        my $host = $c->req->base;
        $host =~ s/^http(s?):\/\///;
        $c->config->{require_ssl}->{$type} = $host;
    }
    
    $c->config->{require_ssl}->{$type} .= '/'
        unless ( $c->config->{require_ssl}->{$type} =~ /\/$/ );
    
    my $redir = $type . '://' . $c->config->{require_ssl}->{$type} . $c->req->path;
    if ( scalar keys %{ $c->req->params } ) {
        my @params = ();
        foreach my $k ( sort keys %{ $c->req->params } ) {
            push @params, $k . "=" . $c->req->params->{$k};
        }
        $redir .= "?" . join "&", @params;
    }
    
    return $redir;
}

=back

=head1 KNOWN ISSUES

When viewing an SSL-required page that uses static files served from the Static plugin, the static
files are redirected to the non-SSL path.  It may be possible to work around this by checking the
referer protocol, but currently there is no way to determine if a file being served is static content.

For best results, always serve static files directly from your web server without using the Static
plugin.

=head1 SEE ALSO

L<Catalyst>

=head1 AUTHOR

Andy Grundman, C<andy@hybridized.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
