package OpenTelemetry::X::Parsing;

our $VERSION = '0.001';

use parent 'OpenTelemetry::X';

1;

__END__

=encoding UTF-8

=head1 NAME

OpenTelemetry::X::Parsing - Unable to parse data from a payload

=head1 SYNOPSIS

    use OpenTelemetry::X;

    die OpenTelemetry::X->create( Parsing => $message );

=head1 DESCRIPTION

Raised when an attempt to parse data from a payload fails.

You should not be manually creating instances of this class. See
L<OpenTelemetry::X> for details on how to create instances of this class.

=head1 SEE ALSO

=over

=item L<OpenTelemetry::X>

=back

=head1 COPYRIGHT AND LICENSE

...
