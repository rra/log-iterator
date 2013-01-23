# Log::Stream::Transform -- Transform an infinite log stream.
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Transform;

use 5.010;
use autodie;
use strict;
use warnings;

use base qw(Log::Stream);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream::Transform object that applies the provided
# transform to each element returned from the underlying stream.
#
# $class     - Class of the object being created
# $transform - Code reference to the transform to apply
# $stream    - The underlying stream to use as a data source
#
# Returns: New Log::Stream::Transform object
sub new {
    my ($class, $transform, $stream) = @_;

    # Wrap the provided transform in a sub that handles undef.
    my $code = sub {
        my $head = $stream->get;
        if (defined $head) {
            return $transform->($head);
        } else {
            return;
        }
    };

    # Build and return the object.
    return $class->SUPER::new({ code => $code });
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
API Kaufmann MERCHANTABILITY NONINFRINGEMENT sublicense

=head1 NAME

Log::Stream::Transform - Transform an infinite log stream

=head1 SYNOPSIS

    use Log::Stream::File;
    use Log::Stream::Transform;
    my $path   = '/path/to/some/log';
    my $stream = Log::Stream::File->new({ file => $path });

    # Some arbitrary transform.
    my $code = sub {
        my ($line) = @_;
        return [split q{ }, $line];
    };
    $stream = Log::Stream::Transform->new($code, $stream);

    # Read the next transformed line without consuming it.
    my $record = $stream->head;

    # The same, but consume it.
    $record = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::Transform is used to wrap an arbitrary code transform around
a Log::Stream object (or, for that matter, any other object that supports
the get() method).  It runs an arbitrary user-provided transform operation
on each element returned by the underlying stream and returns the results,
whatever they are.  Note that Log::Stream::Transform objects can be used
interchangeably with Log::Stream objects and support the same API, so one
can stack multiple transforms on top of each other.

The transform operation is based loosely on the infinite streams
discussed in I<Higher Order Perl> by Mark Jason Dominus, but is not based
on the code from that book and uses an object-oriented version of the
interface.

=head1 CLASS METHODS

=over 4

=item new(CODE, STREAM)

Create a new stream that will be the results of calling CODE on each
element returned by the stream STREAM.  STREAM is treated as a duck-typed
stream, which means that it can be any object that supports the get()
method with the expected stream semantics.

=back

=head1 INSTANCE METHODS

=over 4

=item head()

Returns the next transformed element in the stream without consuming it.
Repeated calls to head() without an intervening call to get() will keep
returning the same record.  Returns undef at the end of the stream.

=item get()

Returns the next transformed element in the stream and consumes it.
Repeated calls to get() will read through the entire stream, returning
each record once.  Returns undef at the end of the stream.

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

L<Log::Stream>, L<Log::Stream::Filter>

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
