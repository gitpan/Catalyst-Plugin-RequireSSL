package Catalyst::Plugin::RequireSSL;

use strict;
use base qw/Class::Accessor::Fast/;
use NEXT;

our $VERSION = '0.06';

__PACKAGE__->mk_accessors( qw/_require_ssl _ssl_strip_output/ );

sub require_ssl {
    my $c = shift;

    $c->_require_ssl(1);

    if ( !$c->req->secure && $c->req->method ne "POST" ) {
        my $redir = $c->_redirect_uri('https');
        if ( $c->config->{require_ssl}->{disabled} ) {
            $c->log->warn( "RequireSSL: Would have redirected to $redir" );
        }
        else {
            $c->_ssl_strip_output(1);
            $c->res->redirect( $redir );
        }
    }
}

sub finalize {
    my $c = shift;
    
    # Do not redirect static files (only works with Static::Simple)
    if ( $c->isa( "Catalyst::Plugin::Static::Simple" ) ) {
        return $c->NEXT::finalize(@_) if $c->_static_file;
    }
    
    # redirect back to non-SSL mode
    REDIRECT:
    {
        # No redirect if:
        # we're not in SSL mode
        last REDIRECT if !$c->req->secure;
        # it's a POST request
        last REDIRECT if $c->req->method eq "POST";
        # we're already required to be in SSL for this request
        last REDIRECT if $c->_require_ssl;
        # or the user doesn't want us to redirect
        last REDIRECT if $c->config->{require_ssl}->{remain_in_ssl};
        
        $c->res->redirect( $c->_redirect_uri('http') );
    }

    # do not allow any output to be displayed on the insecure page
    if ( $c->_ssl_strip_output ) {
        $c->res->body( '' );
    }

    return $c->NEXT::finalize(@_);
}

sub setup {
    my $c = shift;

    $c->NEXT::setup(@_);

    # disable the plugin when running under certain engines which don't
    # support SSL
    if ( $c->engine =~ /Catalyst::Engine::HTTP/ ) {
        $c->config->{require_ssl}->{disabled} = 1;
        $c->log->warn( "RequireSSL: Disabling SSL redirection while running "
                     . "under " . $c->engine );
    }
}

sub _redirect_uri {
    my ( $c, $type ) = @_;

    # XXX: Cat needs a $c->req->host method...
    # until then, strip off the leading protocol from base
    if ( !$c->config->{require_ssl}->{$type} ) {
        my $host = $c->req->base;
        $host =~ s/^http(s?):\/\///;
        $c->config->{require_ssl}->{$type} = $host;
    }

    if ( $c->config->{require_ssl}->{$type} !~ /\/$/xms ) {
        $c->config->{require_ssl}->{$type} .= '/';
    }

    my $redir
        = $type . '://' . $c->config->{require_ssl}->{$type} . $c->req->path;
        
    if ( scalar $c->req->param ) {
        my @params;
        foreach my $arg ( sort keys %{ $c->req->params } ) {
            if ( ref $c->req->params->{$arg} ) {
                my $list = $c->req->params->{$arg};
                push @params, map { "$arg=" . $_  } sort @{$list};
            }
            else {
                push @params, "$arg=" . $c->req->params->{$arg};
            }
        }
        $redir .= '?' . join( '&', @params );
    }  
          
	if ( $c->config->{require_ssl}->{no_cache} ) {		
	    delete $c->config->{require_ssl}->{$type};
	}
	
    return $redir;
}

1;
__END__

=head1 NAME

Catalyst::Plugin::RequireSSL - Force SSL mode on select pages

=head1 SYNOPSIS

    # in MyApp.pm
    use Catalyst;
    MyApp->setup( qw/RequireSSL/ );
    
    MyApp->config->{require_ssl} = {
        https => 'secure.mydomain.com',
        http => 'www.mydomain.com',
        remain_in_ssl => 0,
		no_cache => 0,
    };

    # in any controller methods that should be secured
    $c->require_ssl;

=head1 DESCRIPTION

Use this plugin if you wish to selectively force SSL mode on some of your web
pages, for example a user login form or shopping cart.

Simply place $c->require_ssl calls in any controller method you wish to be
secured. 

This plugin will automatically disable itself if you are running under the
standalone HTTP::Daemon Catalyst server.  A warning message will be printed to
the log file whenever an SSL redirect would have occurred.

=head1 WARNINGS

If you utilize different servers or hostnames for non-SSL and SSL requests,
and you rely on a session cookie to determine redirection (i.e for a login
page), your cookie must be visible to both servers.  For more information, see
the documentation for the Session plugin you are using.

=head1 CONFIGURATION

Configuration is optional.  You may define the following configuration values:

    https => $ssl_host
    
If your SSL domain name is different from your non-SSL domain, set this value.

    http => $non_ssl_host
    
If you have set the https value above, you must also set the hostname of your
non-SSL server.

    remain_in_ssl
    
If you'd like your users to remain in SSL mode after visiting an SSL-required
page, you can set this option to 1.  By default, this option is disabled and
users will be redirected back to non-SSL mode as soon as possible.

	no_cache 

If you have a wildcard certificate you will need to set this option if you are
using multiple domains on one instance of Catalyst.

=head1 METHODS

=head2 require_ssl

Call require_ssl in any controller method you wish to be secured.

    $c->require_ssl;

The browser will be redirected to the same path on your SSL server.  POST
requests are never redirected.

=head1 KNOWN ISSUES

When viewing an SSL-required page that uses static files served from the
Static plugin, the static files are redirected to the non-SSL path.

In order to get the correct behaviour where static files are not redirected,
you should use the Static::Simple plugin or always serve static files
directly from your web server.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Static::Simple>

=head1 AUTHOR

Andy Grundman, <andy@hybridized.org>

=head1 CONTRIBUTORS

Simon Elliott <simon@browsing.co.uk> (support for wildcards)

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
