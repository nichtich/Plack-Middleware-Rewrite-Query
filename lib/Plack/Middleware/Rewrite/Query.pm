use strict;
package Plack::Middleware::Rewrite::Query;
#ABSTRACT: Safely modify the QUERY_STRING of a PSGI request
#VERSION

use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw(rules);
use Plack::Request ();
use URI::Escape ();

sub rewrite {
    my ($env, $rules) = @_;

    my $query = Plack::Request->new($env)->query_parameters;

    # alias to $_
    map { $rules->($_) } $query if $rules;
        
    # rebuild QUERY_STRING
    my @values = map { URI::Escape::uri_escape($_) } $query->values;
    $env->{QUERY_STRING} = join '&', map {
         $_ . '=' . shift @values
    } map { URI::Escape::uri_escape($_) } $query->keys;

    # this has become invalid if it existed
    delete $env->{'plack.request.merged'};

}

sub call {
    my ($self, $env) = @_;

    rewrite($env, $self->rules);

    $self->app->($env);
}

1;

=head1 SYNOPSIS

    builder {
        enable 'Rewrite::Query', rules => sub {
            my $i; 
            $_ = Hash::MultiValue->new(map {
                ($i++ % 2) ? $_ : do { 
                    s/^foo$/bar/; $_  # rename key 'foo' to 'bar'
                } 
            } $_->flatten);
        };
        $app;
    };

=head1 DESCRIPTION

This L<Plack::Middleware> can be used to rewrite the QUERY_STRING of a L<PSGI>
request. Simpliy modifying QUERY_STRING won't alway work because
L<Plack::Request> stores query parameters at multiple places in a PSGI request.
This middleware takes care for cleanup, except the PSGI variable REQUEST_URI,
including the original query string, is not modified because it should not be
used by applications, anyway.

The required configuration value C<rules> takes a reference to a function that
will be called with a L<Hash::MultiValue> containing the query parameters. The
query is also aliased to C<$_> for easy manipulation.

The core function C<rewrite>, defined by this middleware can also be used in
different context, for instance to modify query parameters in another
middleware.

=head1 SEE ALSO

L<Plack::Middleware::Rewrite>

=cut
