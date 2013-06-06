# Log::Stream::Rewindable -- Make an infinite log stream partly rewindable.
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Rewindable;

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

# Create a new Log::Stream::Rewindable object that supports bookmarking,
# rewinding, and prepending.  This differs from a normal stream by adding two
# pieces of state: the saved elements, which are the elements between the
# current bookmark and the stream head, and the queued elements, which are
# elements returned to the stream by either prepend() or unwind().
#
# $class  - Class of the object being created
# $stream - The underlying stream to use as a data source
#
# Returns: New Log::Stream::Rewindable object
sub new {
    my ($class, $stream) = @_;

    # Our tail function reads from the queue by preference.  Bookmarking has
    # to be done in get(), since we don't want to save the head element.
    my $self = {};
    my $tail = sub {
        if ($self->{queue}) {
            my $element = pop @{ $self->{queue} };
            if (!@{ $self->{queue} }) {
                $self->{queue} = undef;
            }
            return $element;
        } else {
            return $stream->get;
        }
    };

    # Build and return the object.
    $self->{head} = undef;
    $self->{tail} = $tail;
    bless $self, $class;
    return $self;
}

# Set a bookmark.  Do this by creating an anonymous array in $self->{saved}.
# If there is already a bookmark, call discard() first.
#
# $self - The Log::Stream::Rewindable object
#
# Returns: True
sub bookmark {
    my ($self) = @_;
    if ($self->{saved}) {
        $self->discard;
    }
    $self->{saved} = [];
    return 1;
}

# Discard the bookmark and any saved elements.
#
# $self - The Log::Stream::Rewindable object
#
# Returns: True
#  Throws: Text exception if no bookmark is set
sub discard {
    my ($self) = @_;
    if (!$self->{saved}) {
        croak('No bookmark set in stream');
    }
    delete $self->{saved};
    return 1;
}

# Override get() to store retrieved objects in the saved array if we have a
# bookmark set.  We have a bookmark iff $self->{saved} is present.
#
# $self - The Log::Stream::Rewindable object
#
# Returns: Current value of head
sub get {
    my ($self) = @_;
    my $element = $self->SUPER::get;
    if ($self->{saved} && defined $element) {
        push @{ $self->{saved} }, $element;
    }
    return $element;
}

# Prepend the provided elements to the head of the stream by adding them to
# the queue and making the current head the first element.
#
# $self     - The Log::Stream::Rewindable object
# @elements - The elements to add to the stream
#
# Returns: True
sub prepend {
    my ($self, @elements) = @_;

    # If we have a defined head, that means we've pulled an element off the
    # stream into it, and we need to save that element.  Do so by adding it
    # to the elements we're prepending and then clearing head so that we'll
    # retrieve a new element on the next head() or get().
    if (defined $self->{head}) {
        push @elements, $self->{head};
        $self->{head} = undef;
    }

    # Put the elements into the queue if we have any.
    if (@elements > 0) {
        $self->{queue} ||= [];
        push @{ $self->{queue} }, reverse @elements;
    }

    # If the stream was empty, we destroyed the tail.  Rebuild it.
    if (!defined $self->{tail}) {
        $self->{tail} = sub { return pop @{ $self->{queue} } };
    }
    return 1;
}

# Rewind the stream to the bookmark and then drop the bookmark.  We do this by
# adding the saved elements to the stream using prepend and then discarding
# the bookmark.
#
# $self - The Log::Stream::Rewindable object
#
# Returns: True
#  Throws: Text exception if no bookmark is set
sub rewind {
    my ($self) = @_;
    if (!$self->{saved}) {
        croak('No bookmark set in stream');
    }
    $self->prepend($self->saved);
    $self->discard;
    return 1;
}

# Return a list of all elements between the bookmark and the current position
# in the stream.
#
# $self - The Log::Stream::Rewindable object
#
# Returns: List of elements
#  Throws: Text exception if no bookmark is set
sub saved {
    my ($self) = @_;
    if (!$self->{saved}) {
        croak('No bookmark set in stream');
    }
    return @{ $self->{saved} };
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery API Kaufmann MERCHANTABILITY NONINFRINGEMENT seekable sublicense

=head1 NAME

Log::Stream::Rewindable - Make an infinite log stream partly rewindable

=head1 SYNOPSIS

    use Log::Stream::Rewindable;
    my $stream; # some existing stream

    # Wrap the stream to make it rewindable.
    $stream = Log::Stream::Rewindable->new($stream);

    # Set a bookmark and consume some elements.
    $stream->bookmark;
    $stream->get;
    $stream->get;

    # Returns the elements retrieved with get() since the bookmark.
    my @elements = $stream->saved;

    # Rewinds the stream to the bookmark.
    $stream->rewind;

    # Adds elements to the front of the stream.
    $stream->prepend(qw(one two three));

    # Discard removes the bookmark and any saved elements.
    $stream->bookmark;
    my $element = $stream->get;
    $stream->discard;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::Rewindable wraps an arbitrary stream (or, for that matter,
any other object that supports the get() method) and makes it partly
rewindable.  The stream does not become fully seekable, but the caller can
set a (single) bookmark, rewind the stream to the bookmark, or retrieve
all stream elements since the bookmark.

Be aware that all elements between the bookmark and the current head of
the stream are cached in memory, so setting a bookmark and then reading
lots of elements from a stream without calling discard() or rewind() can
consume a significant amount of memory.

=head1 CLASS METHODS

=over 4

=item new(STREAM)

Create a new rewindable stream that wraps STREAM.  STREAM is treated as a
duck-typed stream, which means that it can be any object that supports the
get() method with the expected stream semantics.

=back

=head1 INSTANCE METHODS

=over 4

=item bookmark()

Sets a bookmark at the current stream position.  The stream can then be
rewound to this point with rewind(), and all of the elements between the
bookmark and the current position can be retrieved with saved().  A
bookmark must be set before rewind(), saved(), or discard() may be called.

If a bookmark is already set and bookmark() is called again, it is
equivalent to calling discard() followed by bookmark().  All saved stream
elements are discarded, and the bookmark is reset to the current stream
position.

=item discard()

Discards the current bookmark and any saved data.  After discard(), the
stream can no longer be rewound until bookmark() is called again.

=item get()

Returns the next element in the stream and consumes it.  Repeated calls to
get() will read through the entire stream, returning each record once.
Returns undef at the end of the stream.

=item head()

Returns the next element in the stream without consuming it.  Repeated
calls to head() without an intervening call to get() will keep returning
the same record.  Returns undef at the end of the stream.

=item prepend(ELEMENT[, ELEMENT ...])

Prepend the provided elements to the stream.  The first element given will
become the new head element, and those elements will be returned in
sequence before any subsequent items in the stream.  This can be used
along with saved() to remove some elements from a stream and then return
the rest for further processing.

prepend() will make a shallow copy of the provided elements, but not a
deep copy.

If rewind() is used after prepend(), the prepended elements will remain in
the stream, but will be after the elements re-added to the stream by
rewind().  In other words, prepend() behaves as if its arguments were
inserted into the stream before the current head, even during rewind().

=item rewind()

Rewind the stream to the current bookmark and drop the bookmark.  The
elements of the stream retrieved since the last call to bookmark() can now
be retrieved again exactly as before.  bookmark() must be called before
rewind() can be called.

=item saved()

Returns, as a list, all of the elements between the bookmark and the
current position in the stream.  bookmark() must be called before calling
saved().  The saved elements are not affected by this call; to also remove
them from the stream, call discard() after saved().

This can be used along with prepend() to remove some elements from a
stream and then return the rest for further processing.

=back

=head1 DIAGNOSTICS

=over 4

=item No bookmark set in stream

(F) discard(), rewind(), or saved() was called while there was no bookmark
set in the stream.

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
