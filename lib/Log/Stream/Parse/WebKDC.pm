# Log::Stream::Parse::WebKDC -- Stream parser for WebAuth WebKDC logs
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Parse::WebKDC;

use 5.010;
use autodie;
use strict;
use warnings;

use base qw(Log::Stream::Parse::Apache::Error);

use Readonly;

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

# Regex to parse a key/value pair in a WebKDC event log.  Returns the key as
# $1 and the value as $2 or $3.
Readonly my $PAIR_REGEX => qr{
    ([^=\s]+)                           # key
    =
    (?:                                 # two possible value types
      ( [^\"\s]* )                      #   unquoted value
      (?: \s+ | \z )                    #   trailing whitespace or end
      |
      \"                                #   open quote
      ( (?>                             #   quoted value
        \\.                             #     backslash escapes anything
        |
        [^\\\"]                         #     any other character
      )* )
      \"                                #   end of quote
      (?: \s+ | \z )                    #   trailing whitespace or end
    )
}xms;

##############################################################################
# Implementation
##############################################################################

# Given a line of Apache error log output, discard it if it's not a WebKDC log
# line.  Otherwise, parse it into a result structure with fields as described
# in the POD for this module.
#
# $self - The parser object
# $line - The line to parse
#
# Returns: The corresponding data structure or an empty hash on parse failure
sub parse {
    my ($self, $line) = @_;

    # Let the Apache error log parser do most of the work.
    my $result = $self->SUPER::parse($line);
    my $data   = $result->{data};

    # Discard this line unless it's a mod_webkdc log message.
    if (!$data || $data !~ s{ \A mod_webkdc: \s+ }{}xms) {
        return {};
    }

    # One way or another, we will fill out other keys than data.
    delete $result->{data};

    # See if this is an event.  If not, set message.  If so, parse it.
    if ($data =~ s{ \A event = (\S+) \s+ }{}xms) {
        $result->{event} = $1;
        while ($data =~ m{ \G $PAIR_REGEX }goxms) {
            my $key = $1;
            my $value = defined $2 ? $2 : $3;
            $result->{$key} = $value;
        }
    } else {
        $result->{message} = $data;
    }
    return $result;
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery WebAuth WebKDC Kaufmann MERCHANTABILITY NONINFRINGEMENT Readonly
sublicense subclasses timestamp

=head1 NAME

Log::Stream::Parse::WebKDC - Stream parser for WebAuth WebKDC logs

=head1 SYNOPSIS

    use Log::Stream::Parse::WebKDC;
    my $stream; # some existing stream

    # Parse the stream as WebKDC log entries.
    $stream = Log::Stream::Parse::WebKDC->new($stream);

    # Read the next log entry without consuming it.
    my $record = $stream->head;

    # The same, but consume it.
    $record = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later and the Readonly module.

=head1 DESCRIPTION

Log::Stream::Parse::WebKDC provides a stream-based parser for WebKDC
logs.  It expects an Apache error log as the underlying stream and ignores
any lines that aren't from the WebKDC.  Each element returned from the
stream will be an anonymous hash with the following keys:

=over 4

=item timestamp

The timestamp for this error log entry in seconds since UNIX epoch (the
same format as is returned by the Perl time function).

=item level

The Apache log level of this entry.

=item message

A general message.  This key is only present if the log entry represents a
general WebKDC error, trace, or debug message, and if it's present, only
this key plus C<timestamp> and C<level> will be present.

=item event

Indicates that this log entry represents a WebKDC event.  The value will be
one of the recognized WebKDC events, and the remaining keys in the hash will
be the other keys and values from the WebKDC log message.  See the
L<mod_webkdc manual|http://webauth.stanford.edu/manual/mod/mod_webkdc.html>
for more information.

=back

Unparsable lines or lines that aren't mod_webkdc log messages will be
silently skipped.

This object, and any classes derived from it, complies with the
Log::Stream interface and can be wrapped in Log::Stream::Filter or
Log::Stream::Transform objects if desired.

=head1 CLASS METHODS

=over 4

=item new(STREAM[, ARGS...])

Create a new object wrapping the provided Log::Stream object.  The ARGS
argument, if given, must be a reference to a hash.  The default
constructor doesn't do anything with it, but subclasses might.

=back

=head1 INSTANCE METHODS

=over 4

=item get()

Returns the next log entry and consumes it.  Repeated calls to get() will
read through the entire log, returning each entry once.  Returns undef at
the end of the stream.

=item head()

Returns the next log entry without consuming it.  Repeated calls to
head() without an intervening call to get() will keep returning the same
entry.  Returns undef at end of the stream.

=item parse(LINE)

Parses a single log entry and returns the results of the parse.  If a
line could not be parsed, will return an empty anonymous hash (which will
be edited out of the stream normally).

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

L<Log::Stream>, L<Log::Stream::Filter>, L<Log::Stream::Parse>,
L<Log::Stream::Parse::Apache::Error>, L<Log::Stream::Transform>

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
