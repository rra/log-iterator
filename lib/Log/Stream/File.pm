# Log::Stream::File -- Read a line-based log file as an infinite stream
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::File;

use 5.010;
use autodie;
use strict;
use warnings;

use base qw(Log::Stream);

use Carp qw(croak);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream::File object pointing to the provided file.
#
# $class - Class of the object being created
# $args  - Anonymous hash of arguments, with file as the only supported key
#
# Returns: New Log::Stream::File object
#  Throws: Text exception for invalid arguments
#          autodie::exception object on I/O failure
sub new {
    my ($class, $args) = @_;

    # Ensure we were given a valid files argument and open the first file.
    ## no critic (InputOutput::RequireBriefOpen)
    if (!defined $args->{files}) {
        croak('Missing files argument to new');
    }
    my @files = ref $args->{files} ? @{ $args->{files} } : ($args->{files});
    if (!@files) {
        croak('Empty files argument to new');
    }
    open my $fh, q{<}, shift @files;

    # Our generator code reads from each file in turn until hitting end of
    # file and then opens the next one.
    my $code = sub {
        my $line;
      LINE: {
            $line = $fh->getline;
            if (!defined $line) {
                return if !@files;
                open $fh, q{<}, shift @files;
                redo LINE;
            }
        }
        chomp $line;
        return $line;
    };

    # Construct and return the object.
    return $class->SUPER::new({ code => $code });
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Kaufmann MERCHANTABILITY NONINFRINGEMENT parsers sublicense

=head1 NAME

Log::Stream::File - Read a line-based log file as an infinite stream

=head1 SYNOPSIS

    use Log::Stream::File;
    my $stream = Log::Stream::File->new({ files => '/path/to/log' });

    # Read a line without consuming it.
    my $line = $stream->head;

    # Read a line and consume it.
    $line = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::File provides an infinite stream interface to line-based log
files such as normal UNIX syslog or application log files.  It is
primarily a building block for more complex log parsers.  An infinite
stream is similar to an iterator, but also supports looking at the next
element without consuming it.

The stream operations are based loosely on the infinite streams discussed
in I<Higher Order Perl> by Mark Jason Dominus, but are not based on the
code from that book and use an object-oriented version of the interface.

All methods may throw autodie::exception exceptions on I/O failure.

=head1 CLASS METHODS

=over 4

=item new(ARGS)

Open FILE and create a new Log::Stream::File object for it.  ARGS should
be an anonymous hash with only one key: C<files>, whose value is either a
single file name (as a string) or an anonymous array of files.  If
multiple files are given, they will be read from in the order given,
advancing to the next file once end of file is reached in the previous
file.

=back

=head1 INSTANCE METHODS

=over 4

=item head()

Returns the next line in the log stream without consuming it.  The
trailing newline will be removed.  Repeated calls to head() without an
intervening call to get() will keep returning the same line.  Returns
undef at end of file.

=item get()

Returns the next line in the log stream and consumes it.  The trailing
newline will be removed.  Repeated calls to get() will read through the
entire file, returning each line once.  Returns undef at end of file.

=back

=head1 DIAGNOSTICS

=over 4

=item Empty files argument to new

(F) The argument to the C<files> key was an empty list of files.

=item Missing files argument to new

(F) The anonymous hash passed to new() did not contain a C<files> key.

=back

=head1 AUTHOR

Russ Allbery <rra@stanford.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2013 The Board of Trustees of the Leland Stanford Junior
University

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

=head1 SEE ALSO

L<Log::Stream>

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
