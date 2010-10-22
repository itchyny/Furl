use strict;
use warnings;
use Furl;
use Test::TCP;
use Plack::Loader;
use Test::More;
use Plack::Util;
use Plack::Request;

test_tcp(
    client => sub {
        my $port = shift;
        my $furl = Furl->new();
        my $req_content = "WOWOW!";
        open my $req_content_fh, '<', \$req_content or die "oops";
        my ( $code, $msg, $headers, $content ) =
            $furl->request(
                port       => $port,
                path_query => '/foo',
                host       => '127.0.0.1',
                headers    => [ "X-Foo" => "ppp", 'Content-Length' => length($req_content) ],
                content => $req_content_fh,
            );
        is $code, 200, "request()";
        is $msg, "OK";
        is Plack::Util::header_get($headers, 'Content-Length'), 6;
        is $content, $req_content
            or do{ require Devel::Peek; Devel::Peek::Dump($content) };
        done_testing;
    },
    server => sub {
        my $port = shift;
        Plack::Loader->auto(port => $port)->run(sub {
            my $env = shift;
            #note explain $env;
            my $req = Plack::Request->new($env);
            is $req->header('X-Foo'), "ppp" if $env->{REQUEST_URI} eq '/foo';
            like $req->header('User-Agent'), qr/\A Furl /xms;
            return [ 200,
                [ 'Content-Length' => length($req->content) ],
                [$req->content]
            ];
        });
    }
);
