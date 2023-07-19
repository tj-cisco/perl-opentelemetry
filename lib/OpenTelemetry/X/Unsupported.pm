package OpenTelemetry::X::Unsupported;

our $VERSION = '0.001';

use parent 'OpenTelemetry::X';

1;

__END__

=encoding UTF-8

=head1 NAME

OpenTelemetry::X::Unsupported - Attempted to use an unsupported version

=head1 SYNOPSIS

    use OpenTelemetry::X;

    die OpenTelemetry::X->create( Unsupported => $message );

=head1 DESCRIPTION

Raised when an operation encountered a request to use a version that is not
supported.

You should not be manually creating instances of this class. See
L<OpenTelemetry::X> for details on how to create instances of this class.

=head1 SEE ALSO

=over

=item L<OpenTelemetry::X>

=back

=head1 COPYRIGHT AND LICENSE

...
