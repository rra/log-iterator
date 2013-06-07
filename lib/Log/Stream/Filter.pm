# Log::Stream::Filter -- Filter an infinite log stream
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Filter;

use 5.010;
use autodie;
use strict;
use warnings;

use base qw(Log::Stream);

use Scalar::Util qw(reftype);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream::Filter object that applies the provided filter to
# each element returned from the underlying stream.
#
# $class  - Class of the object being created
# $filter - Code reference to the filter to apply
# $stream - The underlying stream to use as a data source
#
# Returns: New Log::Stream::Filter object
sub new {
    my ($class, $filter, $stream) = @_;

    # Find the next valid object in the stream.  We do this in a slightly
    # roundabout way, rather than using get, so that we leave the stream in a
    # state where the head is the next matching object and we don't have a
    # stray head we have to deal with.
    my $head = $stream->head;
    local $_ = $head;
    while (defined($head) && !$filter->($head)) {
        $stream->get;
        $head = $stream->head;
        $_    = $head;
    }

    # If there's a remaining tail, wrap it in a promise.
    my $tail = $stream->tail;
    my $code;
    if (defined($tail)) {
        $code = sub {
            my $next;
          ELEMENT: {
                return if !$tail;
                ($next, $tail) = @{$tail};
                $tail = $tail->();
                local $_ = $next;
                redo ELEMENT if !$filter->($next);
            }
            return [$next, $code];
        };
    }

    # Build and return the object.
    my $self = [$head, $code];
    bless($self, $class);
    return $self;
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery API Kaufmann MERCHANTABILITY NONINFRINGEMENT sublicense

=head1 NAME

Log::Stream::Filter - Filter an infinite log stream

=head1 SYNOPSIS

    use Log::Stream::Filter;
    my $stream; # some existing stream

    # Filter out lines of 40 characters or less.
    my $code = sub { length($_) > 40 };
    $stream = Log::Stream::Filter->new($code, $stream);

    # Read the next filtered line without consuming it.
    my $record = $stream->head;

    # The same, but consume it.
    $record = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::Filter is used to wrap an arbitrary code filter around a
Log::Stream object (or, for that matter, any other object that supports
the get() method).  It runs an arbitrary user-provided filter on each
element returned by the underlying stream.  If the filter returns true,
the element will be passed along; if it returns false, the next element
will be read from the stream, continuing until the filter returns true or
the end of the stream is reached.  Note that Log::Stream::Filter objects
can be used interchangeably with Log::Stream objects and support the same
API, so one can stack multiple transforms and filters on top of each
other.

The filter operation is based loosely on the infinite streams discussed in
I<Higher Order Perl> by Mark Jason Dominus, but is not based on the code
from that book and uses an object-oriented version of the interface.

=head1 CLASS METHODS

=over 4

=item new(CODE, STREAM)

Create a new filtered stream.  CODE will be called with each element of
STREAM as its argument, and only those elements for which CODE returns
true will be passed on.  STREAM is treated as a duck-typed stream, which
means that it can be any object that supports the get() method with the
expected stream semantics.

While calling CODE, $_ will also be set to the element of the STREAM as
a convenience.

=back

=head1 INSTANCE METHODS

=over 4

=item head()

Returns the next valid element in the stream without consuming it.
Repeated calls to head() without an intervening call to get() will keep
returning the same record.  Returns undef at the end of the stream.

=item get()

Returns the next valid element in the stream and consumes it.  Repeated
calls to get() will read through the entire stream, returning each record
once.  Returns undef at the end of the stream.

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

L<Log::Stream>, L<Log::Stream::Transform>

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
