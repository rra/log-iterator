# Log::Stream::Parse -- Record-based log parser built on streams
#
# Written by Russ Allbery <rra@cpan.org>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Parse;

use 5.010;
use strict;
use warnings;

use base qw(Log::Stream::Transform);

use Log::Stream::Filter;
use Scalar::Util qw(reftype);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream::Parse object wrapping the provided Log::Stream.
# We set up both a transform and a filter, the latter to discard any lines
# that parse into the empty hash.
#
# $class  - Class of the object being created
# $stream - The underlying Log::Stream object
# $args   - Any additional arguments for the parser
#
# Returns: New Log::Stream::Parse object
sub new {
    my ($class, $stream, $args) = @_;

    # Pre-create $self so that we can refer to it in the transform closure.
    my $self = [];
    bless($self, $class);

    # Delegate the stream transformation to our parse() method.  We set things
    # up this way because it ensures method lookup will work properly for our
    # subclasses that override parse().
    my $transform = sub { return $self->parse($_) };

    # Our filter discards any elements that are the empty hash.
    my $filter = sub {
        my $type = reftype($_);
        if ($type && $type eq 'HASH' && keys %{$_} == 0) {
            return 0;
        } else {
            return 1;
        }
    };

    # Now, let Log::Stream::Transform and Log::Stream::Filter do all the heavy
    # lifting.  The filter is on the outside, but we inherit from
    # Log::Stream::Transform, so we have to reconsecrate the final object.
    $self = $class->SUPER::new($transform, $stream);
    $self = Log::Stream::Filter->new($filter, $self);
    bless($self, $class);
    return $self;
}

# Simple log parser, meant to be overridden.
#
# $self - Log::Stream::Parse object
# $line - The line to parse
#
# Returns: An anonymous hash with one key, data, whose value is the line
sub parse {
    my ($self, $line) = @_;
    return { data => $line };
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery API Kaufmann MERCHANTABILITY NONINFRINGEMENT sublicense subclasses

=head1 NAME

Log::Stream::Parse - Record-based log parser built on streams

=head1 SYNOPSIS

    use Log::Stream::Parse;
    my $stream; # some existing stream

    # Wrap stream in a parser.
    $stream = Log::Stream::Parse->new($stream);

    # Read the next log record without consuming it.
    my $record = $stream->head;

    # The same, but consume it.
    $record = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::Parse provides an infrastructure for parsing logs based on
infinite streams.  It is similar to Log::Stream except that it parses each
log line and returns, rather than a text line, some kind of data structure
representing that log record.

This class is designed to be subclassed, overriding the parse() method.
The default log parser just returns an anonymous hash for each line with a
single key, C<data>, whose value is the entire line.  But subclasses can
do arbitrarily complex parsing by overriding just the parse() method and
using the rest of the infrastructure.

Log::Stream::Parse objects (and objects derived from it) are themselves
streams, and hence can be wrapped in Log::Stream::Filter or
Log::Stream::Transform objects if desired.

=head1 CLASS METHODS

=over 4

=item new(STREAM[, ARGS])

Create a new Log::Stream::Parse object wrapping the provided Log::Stream
object.  The ARGS argument, if given, must be a reference to a hash.  The
default Log::Stream::Parse constructor doesn't do anything with it, but
subclasses might.

=back

=head1 INSTANCE METHODS

=over 4

=item get()

Returns the next log record and consumes it.  Repeated calls to get() will
read through the entire log, returning each record once.  Returns undef at
the end of the stream.

=item head()

Returns the next log record without consuming it.  Repeated calls to
head() without an intervening call to get() will keep returning the same
record.  Returns undef at the end of the stream.

=item parse(LINE)

Parses a single line of log and returns the results of the parse.  The
results can be anything that would be useful for an application.  Most
commonly, it will be an anonymous hash containing the data from that line.

This method is meant to be overridden by subclasses.  The default
implementation just returns an anonymous hash with one key, C<data>, whose
value is the entire line.

This method should return the empty anonymous hash to indicate that the
line could not be parsed.  Those lines will be silently omitted in the
output of the parsed stream.

=back

=head1 AUTHOR

Russ Allbery <rra@cpan.org>

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

L<Log::Stream>, L<Log::Stream::Filter>, L<Log::Stream::Transform>

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
