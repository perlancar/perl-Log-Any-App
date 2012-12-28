package Alt::Log::Any::App::FWR;
use base qw(Alt::Base);

# VERSION

1;
# ABSTRACT: Log::Any::App which uses Log::Dispatch::FileWriteRotate for file output

=head1 DESCRIPTION

This distribution contains an alternate implementation of L<Log::Any::App>. This
implementation uses a different backend for file output
(L<Log::Dispatch::FileWriteRotate> instead of L<Log::Dispatch::FileRotate>). The
goal is to interoperate more easily with other modules that uses
L<File::Write::Rotate>, like L<Process::Govern>. The parameters are also
slightly different (no more C<DatePattern>, adds C<period> and C<suffix>).

FYI, the future 1.0 of Log::Any::App will probably also use
Log::Dispatch::FileWriteRotate.


=head1 SEE ALSO

L<Alt>

=cut
