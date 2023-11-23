package OpenTelemetry::Integration::HTTP::Tiny;
# ABSTRACT: OpenTelemetry integration for HTTP::Tiny

our $VERSION = '0.019';

use strict;
use warnings;
use experimental 'signatures';

use Class::Inspector;
use Class::Method::Modifiers 'install_modifier';
use Feature::Compat::Defer;
use List::Util 'any';
use OpenTelemetry::Constants qw( SPAN_KIND_CLIENT SPAN_STATUS_ERROR SPAN_STATUS_OK );
use OpenTelemetry::Context;
use OpenTelemetry::Trace;
use OpenTelemetry;
use Ref::Util 'is_arrayref';
use Syntax::Keyword::Dynamically;

use parent 'OpenTelemetry::Integration';

sub dependencies { 'HTTP::Tiny' }

my sub get_headers ( $have, $want, $prefix ) {
    return unless @$want;

    map {
        my ( $k, $v ) = ( $_->[0], $have->{ $_->[1] } );
        "$prefix.$k" => is_arrayref $v ? $v : [ $v ]
    }
    grep { my $k = $_->[0]; any { $k =~ $_ } @$want }
    map { [ lc tr/-/_/r, $_ ] }
    keys %$have;
}

my ( $original, $loaded );

sub uninstall ( $class ) {
    return unless $original;
    no strict 'refs';
    no warnings 'redefine';
    delete $Class::Method::Modifiers::MODIFIER_CACHE{'HTTP::Tiny'}{request};
    *{'HTTP::Tiny::request'} = $original;
    undef $loaded;
    return;
}

sub install ( $class, %config ) {
    return if $loaded;
    return unless Class::Inspector->loaded('HTTP::Tiny');

    require URI;

    my @wanted_request_headers = map qr/^\Q$_\E$/i, map tr/-/_/r,
        @{ delete $config{request_headers}  // [] };

    my @wanted_response_headers = map qr/^\Q$_\E$/i, map tr/-/_/r,
        @{ delete $config{response_headers} // [] };

    $original = \&HTTP::Tiny::request;
    install_modifier 'HTTP::Tiny' => around => request => sub {
        my ( $code, $self, $method, $url, $options ) = @_;

        my $uri = URI->new("$url");

        $uri->userinfo('REDACTED:REDACTED') if $uri->userinfo;

        my $span = OpenTelemetry->tracer_provider->tracer(
            name    => __PACKAGE__,
            version => $VERSION,
        )->create_span(
            name       => $method,
            kind       => SPAN_KIND_CLIENT,
            attributes => {
                # As per https://github.com/open-telemetry/semantic-conventions/blob/main/docs/http/http-spans.md
                'http.request.method'      => $method,
                'network.protocol.name'    => 'http',
                'network.protocol.version' => '1.1',
                'network.transport'        => 'tcp',
                'server.address'           => $uri->host,
                'server.port'              => $uri->port,
                'url.full'                 => "$uri", # redacted
                'user_agent.original'      => $self->agent,

                # This does not include auto-generated headers
                # Capturing those would require to hook into the
                # handle's write_request method
                get_headers(
                    $self->{default_headers}, # Apologies to the encapsulation gods
                    \@wanted_request_headers,
                    'http.request.header'
                ),

                get_headers(
                    $options->{headers},
                    \@wanted_request_headers,
                    'http.request.header'
                ),

                # Request body can be generated with a data_callback
                # parameter, in which case we don't set this attribute
                # Setting it would likely involve us hooking into the
                # handle's write_body method
                $options->{content}
                    ? ( 'http.request.body.size' => length $options->{content} )
                    : (),
            },
        );

        dynamically OpenTelemetry::Context->current
            = OpenTelemetry::Trace->context_with_span($span);

        defer { $span->end }

        my $res = $self->$code( $method, $url, $options );
        $span->set_attribute( 'http.response.status_code' => $res->{status} );

        # TODO: this should include retries
        $span->set_attribute( 'http.resend_count' => scalar @{ $res->{redirects} } )
            if $res->{redirects};

        my $length = $res->{headers}{'content-length'};
        $span->set_attribute( 'http.response.body.size' => $length )
            if defined $length;

        if ( $res->{success} ) {
            $span->set_status( SPAN_STATUS_OK );
        }
        elsif ( $res->{status} == 599 ) {
            my $error = ( $res->{content} // '' ) =~ s/^\s+|\s+$//r;
            my ($description) = split /\n/, $error, 2;
            $description =~ s/ at \S+ line \d+\.$//a;

            $span->set_status( SPAN_STATUS_ERROR, $description );
        }
        else {
            $span->set_status( SPAN_STATUS_ERROR, $res->{status} );
        }

        $span->set_attribute(
            get_headers(
                $res->{headers},
                \@wanted_response_headers,
                'http.response.header'
            )
        );

        return $res;
    };

    return $loaded = 1;
}

1;
