# Log::Stream::Parsed -- Record-based log parser built on streams
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Parsed;

use 5.010;
use autodie;
use strict;
use warnings;

use base qw(Log::Stream::Transform);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream::Parsed object that creates a Log::Stream object
# with the provided arguments and then applies the parse() method to each
# element returned from the underlying stream.
#
# $class - Class of the object being created
# @args  - Path to the file to associate with the stream
#
# Returns: New Log::Stream::Parsed object
sub new {
    my ($class, @args) = @_;
    my $stream = Log::Stream->new(@args);

    # Getting the variables set up so that $self is set properly in the
    # transform for method look-up is tricky.  Create an object of our class
    # so that we can find parse.
    my $self = {};
    bless $self, $class;
    my $transform = sub { my ($line) = @_; return $self->parse($line) };

    # Let Log::Stream::Transform do all the heavy lifting.  This will use the
    # $self that we provide to read and transform the first line.  We then
    # replace it with the new Log::Stream::Transform object.
    $self = $class->SUPER::new($transform, $stream);

    # Reconsecreate and return our object.
    bless $self, $class;
    return $self;
}

# Simple log parser, meant to be overridden.
#
# $self - Log::Stream::Parsed object
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
API Kaufmann MERCHANTABILITY NONINFRINGEMENT sublicense subclasses

=head1 NAME

Log::Stream::Parsed - Record-based log parser built on streams

=head1 SYNOPSIS

    use Log::Stream::Parsed;
    my $stream = Log::Stream::Parsed->new('/path/to/some/log');

    # Read the next log record without consuming it.
    my $record = $stream->head;

    # The same, but consume it.
    $record = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::Parsed provides an infrastructure for parsing logs based on
infinite streams.  It is similar to Log::Stream except that it parses each
log line and returns, rather than a text line, some kind of data structure
representing that log record.

This class is designed to be subclassed, overriding the parse() method.
The default log parser just returns an anonymous hash for each line with a
single key, C<data>, whose value is the entire line.  But subclasses can
do arbitrarily complex parsing by overriding just the parse() method and
using the rest of the infrastructure.

Log::Stream::Parsed objects (and objects derived from it) are themselves
streams, and hence can be wrapped in Log::Stream::Transform objects if
desired.

All methods may propagate autodie::exception exceptions from the
underlying stream.

=head1 CLASS METHODS

=over 4

=item new(ARGS...)

Create a new underlying Log::Stream object and then build a parsed stream
around it.  All arguments are passed as-is to the Log::Stream constructor.

=back

=head1 INSTANCE METHODS

=over 4

=item get()

Returns the next record from the log and consumes it.  Repeated calls to
get() will read through the entire log, returning each record once.
Returns undef at the end of the stream.

=item head()

Returns the next log record without consuming it.  Repeated calls to
head() without an intervening call to get() will keep returning the same
record.  Returns undef at end of file.

=item parse(LINE)

Parses a single line of log and returns the results of the parse.  The
results can be anything that would be useful for an application.  Most
commonly, it will be an anonymous hash containing the data from that line.

This method is meant to be overridden by subclasses.  The default
implementation just returns an anonymous hash with one key, C<data>, whose
value is the entire line.

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
