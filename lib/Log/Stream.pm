# Log::Stream -- Parent class for logs as infinite streams.
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream;

use 5.010;
use autodie;
use strict;
use warnings;

use Carp qw(croak);
use Scalar::Util qw(reftype);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream object from a code reference.  Child classes may
# either reuse this by setting the code reference or override it entirely.
#
# $class - Class of the object being created
# $args  - Anonymous hash of arguments, with code as the only supported key
#
# Returns: New Log::Stream object
#  Throws: Text exceptions on invalid arguments
sub new {
    my ($class, $args) = @_;

    # Ensure we were given a valid code argument.
    if (!defined $args->{code}) {
        croak('Missing code argument to new');
    }
    my $type = reftype($args->{code});
    if (!$type || $type ne 'CODE') {
        croak('code argument to new is not a code reference');
    }

    # Build and return the object.
    my $self = {
        head => undef,
        tail => $args->{code},
    };
    bless $self, $class;
    return $self;
}

# Internal helper function to set the head element.  This handles deferred
# processing of head: if head is currently undef but tail is defined, calls
# the tail function to generate the head element.  Also handles clearing the
# tail function once it returns undef.
#
# $self - The Log::Stream object
#
# Returns: undef
sub _set_head {
    my ($self) = @_;
    return if defined $self->{head};
    return if !defined $self->{tail};
    $self->{head} = $self->{tail}->();
    if (!defined $self->{head}) {
        $self->{tail} = undef;
    }
    return;
}

# Returns the next line in the stream without consuming it.  If head is undef,
# that means we've not read the next line yet, so we internally use get() to
# read it.
#
# $self - The Log::Stream object
#
# Returns: Current value of head
sub head {
    my ($self) = @_;
    $self->_set_head;
    return $self->{head};
}

# Returns the next line in the stream and consumes it.  The tail sub is asked
# for the next head.  As soon as tail returns undef, we close the stream (by
# setting tail to undef).
#
# $self - The Log::Stream object
#
# Returns: Current value of head
#  Throws: autodie::exception on I/O failure
sub get {
    my ($self) = @_;
    $self->_set_head;
    my $head = $self->{head};
    $self->{head} = undef;
    return $head;
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Kaufmann MERCHANTABILITY NONINFRINGEMENT parsers sublicense

=head1 NAME

Log::Stream - Parent class for logs as infinite streams

=head1 SYNOPSIS

    use Log::Stream;
    my @data;
    my $code = sub { return shift @data };
    my $stream = Log::Stream->new({ code => $code });

    # Read a line without consuming it.
    my $line = $stream->head;

    # Read a line and consume it.
    $line = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream provides an infinite stream interface to arbitrary data.  It's
primarily intended as a superclass for reading log files and a building
block for more complex log parsers, but it can be used as a generic stream
object if desired.  An infinite stream is similar to an iterator, but also
supports looking at the next element without consuming it.

The stream operations are based loosely on the infinite streams discussed
in I<Higher Order Perl> by Mark Jason Dominus, but are not based on the
code from that book and use an object-oriented version of the interface.

=head1 CLASS METHODS

=over 4

=item new(ARGS)

Create a new Log::Stream object.  ARGS should be an anonymous hash with
only one key: C<code>, whose value is a code reference to call to generate
the next element in the stream.  When the code reference returns undef,
that's the end of the stream, and all subsequent attempts to read from the
stream will also return undef.

=back

=head1 INSTANCE METHODS

=over 4

=item head()

Returns the next element in the stream without consuming it.  Repeated
calls to head() without an intervening call to get() will keep returning
the same line.  Returns undef at the end of the stream.

=item get()

Returns the next element in the stream and consumes it.  Repeated calls to
get() will read through the entire stream, returning each element once.
Returns undef at the end of the stream.

=back

=head1 DIAGNOSTICS

=over 4

=item code argument to new is not a code reference

(F) The value of the code key in the anonymous hash passed to new() is not
a code reference.

=item Missing code argument to new

(F) The anonymous hash passed to new() did not contain a code key.

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

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
