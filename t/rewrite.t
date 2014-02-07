use strict;
use Test::More;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;

my $app = sub { [200, ['Content-Type' => 'text/plain'], [$_[0]->{'QUERY_STRING'}]] };

sub test_app(@) { ##no critique
    my ($app, $query, $expect, $msg) = @_;

    test_psgi app => $app, client => sub {
        my $cb = shift;
        my $res = $cb->(GET "/$query");
        is $res->content, $expect, $msg;
    };
}

my $rebuild = builder {
    enable 'RewriteQuery', rules => sub { };
    $app;
};

test_app $rebuild, '?a=x&a= &b', 'a=x&a=%20&b=';
test_app $rebuild, '?foo+bar', 'foo=&bar=';

my $modify1 = builder {
    enable 'RewriteQuery', rules => sub {
        # rename all 'foo' paramaters to 'bar'
        if (my @values = $_->get_all('foo')) {
            $_->set('foo');
            $_->set('bar', @values);
        }
    };
    $app;
};

test_app $modify1, '?foo=baz&foo=doz&x=1', 'x=1&bar=baz&bar=doz';

my $modify2 = builder {
    enable 'RewriteQuery', rules => sub {
        my $i; # rename all 'foo' paramaters to 'bar', keeping order
        $_ = Hash::MultiValue->new(map {
            ($i++ % 2) ? $_ : do { s/^foo$/bar/; $_ } 
        } $_->flatten);
    };
    $app;
};

test_app $modify2, '?foo=baz&foo=doz&x=1', 'bar=baz&bar=doz&x=1';

done_testing;
