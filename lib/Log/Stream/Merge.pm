# Log::Stream::Merge -- Merge multiple infinite log streams
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Merge;

use 5.010;
use strict;
use warnings;

use base qw(Log::Stream);

use Scalar::Util qw(reftype);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream::Merge object that runs either the provided code or
# a standard function to merge the values from multiple streams.
#
# $class   - Class of the object being created
# $code    - Optional code reference for the merge function
# @streams - The underlying streams to merge
#
# Returns: New Log::Stream::Merge object
sub new {
    my ($class, $code, @streams) = @_;

    # See if we have a code reference to merge the values.
    my $type = reftype($code);
    if (!$type || $type ne 'CODE') {
        unshift(@streams, $code);
        $code = undef;
    }

    # Filter out all of the empty streams.
    @streams = grep { defined($_->head) } @streams;

    # If code was provided, we have to keep references to all of the
    # underlying streams and turn the provided code into a closure.
    if ($code) {
        my $closure = sub { return $code->(@streams) };
        return $class->SUPER::new({ code => $closure });
    }

    # Otherwise, if no code was provided, we can provide a very efficient
    # merge that doesn't keep any of the underlying streams.
    else {
        my @pairs = map { [$_->head, $_->generator] } @streams;
        my $generator = sub {
            my $pair;
            ($pair, @pairs) = @pairs;
            return if !defined($pair);
            my $tail = [$pair->[1]->(), $pair->[1]];
            if (defined($tail->[0])) {
                push(@pairs, $tail);
            }
            return $pair->[0];
        };
        my $head = $generator->();
        my $self = defined($head) ? [$head, $generator] : [];
        bless($self, $class);
        return $self;
    }
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery API Kaufmann MERCHANTABILITY NONINFRINGEMENT STREAMs sublicense

=head1 NAME

Log::Stream::Merge - Merge multiple infinite log streams

=head1 SYNOPSIS

    use Log::Stream::Merge;
    my ($stream1, $stream2); # some existing streams

    # Default merge behavior.
    my $stream = Log::Stream::Merge->new($stream1, $stream2);

    # Read the next filtered line without consuming it.
    my $record = $stream->head;

    # The same, but consume it.
    $record = $stream->get;

    # Define a custom merge function.  Note that this stream will never
    # end, just keep returning the empty string.
    my $code = sub {
        my (@streams) = @_;
        my $result = q{};
        for my $stream (@streams) {
            my $element = $stream->get;
            if (defined $element) {
                $result .= $element;
            }
        }
        return $result;
    };

    # A merge stream that concatenates the stream values.
    $stream = Log::Stream::Merge->new($code, $stream1, $stream2);

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::Merge merges together two infinite streams.  Normally, the
underlying streams are Log::Stream objects, but any other object that
supports the head() and get() methods can be used.

By default, the result returns the next element from each stream in a
round-robin fashion, dropping streams from the rotation once they've been
exhausted.  However, the user can provide a custom merge function, which
has access to the underlying streams and can do whatever sort of merging
it desires.

Stream merging is based loosely on the union operation on infinite streams
discussed in I<Higher Order Perl> by Mark Jason Dominus, but lacks the
power of the functional method used in the book.

=head1 CLASS METHODS

=over 4

=item new([CODE,] STREAM, ...)

Create a new merged stream based on the provided STREAMs.

CODE, if given, is a reference to a user-provided merge function and will
be called for each new element and passed, as arguments, all of the STREAM
arguments to this constructor in the same order as they were passed to the
constructor.  They will continue to be passed even if they've returned end
of stream.  CODE is expected to return the next element in the merged
stream each time it is called.

If CODE is not provided, the default merge function returns the next
element of each of the underlying streams in a round-robin fashion,
skipping over streams that have reached the end of the stream.

STREAM is treated as a duck-typed stream, which means that it can be any
object that supports the head() and get() methods with the expected stream
semantics.  (Of course, the user-provided CODE method can make additional
assumptions about the streams if warranted.)

=back

=head1 INSTANCE METHODS

=over 4

=item get()

Returns the next element in the merged stream and consumes it.  Repeated
calls to get() will read through the entire merged stream, returning each
element once.  Returns undef at the end of the stream.

=item head()

Returns the next element in the merged stream without consuming it.
Repeated calls to head() without an intervening call to get() will keep
returning the same record.  Returns undef at the end of the stream.

=back

=head1 BUGS

Since the head and tail data structures of Log::Stream objects are hidden,
the tail promise cannot be rewritten by a user-provided code reference in
the way that I<Higher Order Perl> recommends.  The default merge behavior
therefore uses a strategy that the user of this module cannot access
without creating a new class that inherits from it, and several possible
merge strategies are much more awkward to implement using this module than
they would be with the functional interface to streams.

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
