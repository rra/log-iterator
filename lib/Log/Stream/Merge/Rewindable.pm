# Log::Stream::Merge::Rewindable -- Merge rewindable log streams
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Merge::Rewindable;

use 5.010;
use strict;
use warnings;

use base qw(Log::Stream::Merge);

use Log::Stream::Rewindable;

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream::Merge::Rewindable object that ensures all the
# merged streams are rewindable.
#
# $class   - Class of the object being created
# $code    - Code reference for the merge function
# @streams - The underlying streams to merge
#
# Returns: New Log::Stream::Merge::Rewindable object
sub new {
    my ($class, $code, @streams) = @_;

    # Make all the streams rewindable.
    for my $stream (@streams) {
        if (!$stream->isa('Log::Stream::Rewindable')) {
            $stream = Log::Stream::Rewindable->new($stream);
        }
    }

    # Defer all other work to our parent class.
    return $class->SUPER::new($code, @streams);
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery API Kaufmann MERCHANTABILITY NONINFRINGEMENT STREAMs sublicense

=head1 NAME

Log::Stream::Merge::Rewindable - Merge rewindable log streams

=head1 SYNOPSIS

    use Log::Stream::Merge;
    my ($stream1, $stream2); # some existing streams

    # Merge function may assume all streams are rewindable.  This one
    # only returns elements from $stream1 seen in the top 10 items of
    # $stream2 (possibly out of order).
    my $code = sub {
        my ($one, $two) = @_;
      ONE: {
            my $element = $one->get;
            return if !defined $element;
            $two->bookmark;
          TWO:
            for my $i (1 .. 10) {
                last TWO if !defined $two->head;
                next TWO if $two->get ne $element;

                # Drop the element we found so we don't match twice.
                my @saved = $two->saved;
                pop @saved;
                $two->discard;
                $two->prepend(@saved);
                return $element;
            }
            $two->rewind;
            redo ONE;
        }
    };

    # Implement a stream using the above algorithm.
    my $stream = Log::Stream::Merge->new($code, $stream1, $stream2);

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::Merge::Rewindable is identical to L<Log::Stream::Merge>
except that it ensures that all of its underlying streams are rewindable
by wrapping them in Log::Stream::Rewindable if necessary.  This allows
the merge function to use the features of rewindable streams to examine
the contents of the streams being merged.

A typical use for this type of stream would be code that correlates and
combines information from two different logs, where the entries in one of
the logs can be out of order relative to the other.  Rewindable streams
allows the merge function to look forward in one log for entries matching
the current entry in the other log and then rewind or prepend unprocessed
log entries when finished matching the current entry.

=head1 CLASS METHODS

=over 4

=item new(CODE, STREAM, ...)

Create a new merged stream based on the provided STREAMs.

CODE is a reference to a user-provided merge function and will be called
for each new element and passed, as arguments, all of the STREAM arguments
to this constructor in the same order as they were passed to the
constructor, possibly wrapped in Log::Stream::Rewindable if necessary.
They will continue to be passed even if they've returned end of stream.
CODE is expected to return the next element in the merged stream each time
it is called.  Unlike in Log::Stream::Merge, CODE is mandatory.

STREAM is treated as a duck-typed stream, which means that it can be any
object that supports the get() method with the expected stream semantics.
(Of course, the user-provided CODE method can make additional assumptions
about the streams if warranted.)

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

L<Log::Stream>, L<Log::Stream::Merge>, L<Log::Stream::Rewindable>

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
