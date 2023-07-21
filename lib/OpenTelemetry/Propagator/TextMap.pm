use Object::Pad;
# ABSTRACT: A context propagator for OpenTelemetry using string key / value pairs

use experimental 'signatures';

package OpenTelemetry::Propagator::TextMap;

our $VERSION = '0.001';

sub SETTER {
    sub ( $carrier, $key, $value ) { $carrier->{$key} = $value; return }
}

sub GETTER {
    sub ( $carrier, $key ) { $carrier->{$key} }
}

class OpenTelemetry::Propagator::TextMap :does(OpenTelemetry::Propagator) {
    use OpenTelemetry::Context;

    method inject (
        $carrier,
        $context = OpenTelemetry::Context->current,
        $setter  = SETTER
    ) {
        return $self;
    }

    method extract (
        $carrier,
        $context = OpenTelemetry::Context->current,
        $getter  = GETTER
    ) {
        return $context;
    }

    method keys () { }
}

__END__

=encoding UTF-8

=head1 NAME

OpenTelemetry::Propagator::TextMap - A context propagator for OpenTelemetry using string key / value pairs

=head1 SYNOPSIS

    use OpenTelemetry::Propagator::TextMap;

    my $propagator = OpenTelemetry::Propagator::TextMap->new;

    # Does nothing :(
    my $carrier = {};
    $propagator->inject( $carrier, $context );

    # Does nothing :(
    my $new_context = $propagator->extract( $carrier, $context );

=head1 DESCRIPTION

This package defines a no-op propagator class that implements the
L<OpenTelemetry::Propagator> interface, with the assumption that the carrier
can store key / value pairs as strings (in Perl parlance, that the carrier
can be used as a hash reference).

It also exposes a L<setter|/SETTER> and a L<getter|/GETTER> that can be used
as the default value by any propagator that shares this assumption.

=head1 METHODS

=head2 new

    $propagator = OpenTelemetry::Propagator::TextMap->new

Constructs a new instance of this propagator. This propagator will do nothing.

=head2 GETTER

    $getter = OpenTelemetry::Propagator::TextMap->GETTER;;
    $value  = $carrier->$getter($key);

Returns a subroutine reference that takes a carrier data structure and a
string key, and returns whatever value the carrier stores under that key.
If no value is stored under that key, this getter returns undefined.

This getter assumes the carrier is (or can be used as) a hash reference.

=head2 SETTER

    $setter = OpenTelemetry::Propagator::TextMap->SETTER;
    $carrier->$setter( $key => $value );

Returns a subroutine reference that takes a carrier data structure and a
string key / value pair, and stores the value under the key in the carrier.
It returns nothing.

This getter assumes the carrier is (or can be used as) a hash reference.

=head1 SEE ALSO

=over

=item L<OpenTelemetry::Context>

=item L<OpenTelemetry::Propagator>

=back

=head1 COPYRIGHT AND LICENSE

...
