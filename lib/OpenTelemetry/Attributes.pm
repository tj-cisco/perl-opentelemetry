use Object::Pad ':experimental(init_expr)';
# ABSTRACT: A class encapsulating attribute validation for OpenTelemetry

package OpenTelemetry::Attributes;

our $VERSION = '0.001';

class OpenTelemetry::AttributeMap {
    use Log::Any;
    my $logger = Log::Any->get_logger( category => 'OpenTelemetry' );

    use List::Util qw( any pairs );
    use Ref::Util qw( is_hashref is_arrayref );
    use Storable 'dclone';

    field $max_fields       :param  = undef;
    field $max_field_length :param  = undef;
    field $dropped_fields   :reader = 0;
    field $data                     = {};

    ADJUSTPARAMS ($params) {
        $self->set( %{ delete $params->{data} // {} } );
    }

    method $validate_attribute_value ( $value ) {
        # Attribute values cannot be undefined but logging this is noisy
        return unless defined $value;

        if ( is_arrayref $value ) {
            if ( any { ref } @$value ) {
                $logger->trace('Attribute values that are lists cannot themselves hold references');
                return;
            }

            # Make sure we do not store the same reference that was
            # passed as a value, since the list on the other side of
            # that reference can be modified without going through
            # our checks
            $value = $max_field_length ? [
                map {
                        defined ? substr( $_, 0, $max_field_length ) : $_
                } @$value
            ] : [ @$value ];
        }
        elsif ( ref $value ) {
            $logger->trace('Attribute values cannot be references');
            return;
        }
        elsif ( $max_field_length ) {
            $value = substr $value, 0, $max_field_length;
        }

        ( 1, $value );
    }

    method set ( %args ) {
        my $recorded = 0;
        for ( pairs %args ) {
            my ( $key, $value ) = @$_;

            $key ||= do {
                $logger->debugf("Attribute names should not be empty. Setting to 'null' instead");
                'null';
            };

            my $fields = scalar %$data;
            $fields++ unless exists $data->{$key};

            next if $max_fields && $fields > $max_fields;

            my $ok;
            ( $ok, $value ) = $self->$validate_attribute_value($value);

            next unless $ok;

            $recorded++;
            $data->{$key} = $value;
        }

        my $dropped = +( keys %args ) - $recorded;

        $logger->debugf(
            'Dropped %s attribute entr%s because %s invalid%s',
            $dropped,
            $dropped > 1 ? ( 'ies', 'they were' ) : ( 'y', 'it was' ),
            $max_fields
                ? " or would have exceeded field limit ($max_fields)" : '',
        ) if $logger->is_debug && $dropped > 0;

        $dropped_fields += $dropped;

        return $self;
    }

    method get ( $key ) { $data->{$key} }

    method to_hash () {
        dclone $data;
    }
}

role OpenTelemetry::Attributes {
    field $attributes;

    ADJUSTPARAMS ( $params ) {
        $attributes = OpenTelemetry::AttributeMap->new(
            data             => delete $params->{attributes} // {},
            max_fields       => delete $params->{attribute_count_limit},
            max_field_length => delete $params->{attribute_length_limit},
        );
    }

    method dropped_attributes () { $attributes->dropped_fields }

    method attributes () { $attributes->to_hash }
}

role OpenTelemetry::Attributes::Writable {
    field $attributes;

    ADJUSTPARAMS ( $params ) {
        $attributes = OpenTelemetry::AttributeMap->new(
            data             => delete $params->{attributes} // {},
            max_fields       => delete $params->{attribute_count_limit},
            max_field_length => delete $params->{attribute_length_limit},
        );
    }

    method _set_attribute ( %new ) {
        $attributes->set(%new);
        $self;
    }

    method dropped_attributes () { $attributes->dropped_fields }

    method attributes () { $attributes->to_hash }
}

__END__

=encoding UTF-8

=head1 NAME

OpenTelemetry::Attributes - A common role for OpenTelemetry classes with attributes

=head1 SYNOPSIS

    class My::Class :does(OpenTelemetry::Attributes) { }

    my $class = My::Class->new(
        attributes => \%attributes,
    );

    my $read_only = $class->attributes;

    say $class->dropped_attributes;

=head1 DESCRIPTION

A number of OpenTelemetry classes allow for arbitrary attributes to be stored
on them. Since the rules for these attributes are shared by all of them, this
module provides a role that can be consumed by any class that should have
attributes, and makes it possible to have a consistent behaviour in all of
them.

See the
L<OpenTelemetry specification|https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/common/README.md#attribute>
for more details on these behaviours.

=head2 Allowed values

The values stored in an OpenTelemetry attribute hash can be any defined scalar
that is not a reference. The only exceptions to this rule are array references,
which are allowed as values as long as they do not contain any values that are
themselves undefined or references (of any kind).

=head2 Limits

This role can optionally be configured to limit the number of attributes
it will store, and the length of the stored values. If configured in this way,
information about how many attributes were dropped will be made available
via the L<dropped_attributes|/dropped_attributes> method described below.

=head1 METHODS

=head2 new

    $instance = Class::Consuming::Role->new(
        attributes             => \%attributes // {},
        attribute_count_limit  => $count       // undef,
        attribute_length_limit => $length      // undef,
    );

Creates a new instance of the class that consumes this role. A hash reference
passed as the value for the C<attributes> parameter will be used as the
initial set of attribues.

The C<attribute_count_limit> and C<attribute_length_limit> parameters passed
to the constructor can optionally be used to limit the number of fields the
attribute store will hold, and the length of the stored values. If not set,
the store will have no limit.

If the length limit is set, fields set to plain scalar values will be
truncated at that limit when set. In the case of values that are array
references, the length limit will apply to each individual value.

=head2 attributes

    $hash = $class->attributes;

Returns a hash reference with a copy of the stored attributes. Because this
is a copy, the returned hash reference is read-only.

=head2 dropped_attributes

    $count = $class->dropped_attributes;

Return the number of attributes that were dropped if attribute count limits
have been configured (see L<above|/new>).

=head1 SEE ALSO

=over

=item L<OpenTelemetry specification|https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/common/README.md#attribute>

=back

=head1 COPYRIGHT AND LICENSE

...
