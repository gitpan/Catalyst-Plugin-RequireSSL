#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 6;
use Catalyst::Test 'TestApp';

TestApp->config->{require_ssl} = {
    remain_in_ssl => 1,
};

# test an SSL redirect
ok( my $res = request('http://localhost/ssl/secured'), 'request ok' );
is( $res->code, 302, 'redirect code ok' );
is( $res->header('location'), 'https://localhost/ssl/secured', 'redirect uri ok' );
isnt( $res->content, 'Secured', 'no content displayed on secure page, ok' );

# test redirect back to HTTP, should not redirect
SKIP:
{
    skip "These tests require a patch to Catalyst", 2;
    # patch is to Catalyst::Engine::HTTP::Base in 5.3x
    #             Catalyst::Engine::Test in 5.5
    ok( $res = request('https://localhost/ssl/unsecured'), 'request ok' );
    is( $res->code, 200, 'remain in SSL ok' );
}

