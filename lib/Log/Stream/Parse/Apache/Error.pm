# Log::Stream::Parse::Apache::Error -- Stream parser for Apache error logs
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Parse::Apache::Error;

use 5.010;
use autodie;
use strict;
use warnings;

use base qw(Log::Stream::Parse);

use Date::Parse ();
use Readonly;

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

# Regex matching an Apache log timestamp.  Returns the timestamp (without the
# day of the week) as $1.
Readonly my $TIMESTAMP_REGEX => qr{
    \[
      \w{3} \s+                 # Day of the week
      (                         # Start of interesting timestamp
          \w{3}                 #   month
          \s+ \d+               #   day of month
          \s+ \d{2}:\d{2}:\d{2} #   time of day
          \s+ \d{4}             #   year
      )
    \]
}xms;

# Regex matching an Apache log level.  Returns the log level as $1.
Readonly my $LEVEL_REGEX => qr{ \[ (\w+) \] }xms;

# Regex matching a client IP address.  Returns the IP address as $1.
Readonly my $CLIENT_REGEX => qr{ \[ client \s+ ([[:xdigit:].:]+) \] }xms;

# Regex matching a whole Apache error log line.  Returns:
#
#     $1 - Timestamp
#     $2 - Log level
#     $3 - Client IP address (may be empty)
#     $4 - Rest of the log line
Readonly my $APACHE_ERROR_REGEX => qr{
    \A
      $TIMESTAMP_REGEX
      \s+ $LEVEL_REGEX
      (?: \s+ $CLIENT_REGEX )?
      \s+ (.+)
    \z
}xms;

##############################################################################
# Implementation
##############################################################################

# Given a line of Apache error log output, parse it into a result structure
# with fields as described in the POD for this module.
#
# $self - The parser object
# $line - The line to parse
#
# Returns: The corresponding data structure or an empty hash on parse failure
sub parse {
    my ($self, $line) = @_;
    if ($line =~ $APACHE_ERROR_REGEX) {
        my ($timestamp, $level, $client, $data) = ($1, $2, $3, $4);
        $timestamp = Date::Parse::str2time($timestamp);
        my $result = {
            timestamp => $timestamp,
            level     => $level,
            data      => $data,
        };
        if (defined $client) {
            $result->{client} = $client;
        }
        return $result;
    } else {
        return {};
    }
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
API CPAN IP Kaufmann MERCHANTABILITY NONINFRINGEMENT Readonly TimeDate
sublicense subclasses timestamp

=head1 NAME

Log::Stream::Parse::Apache::Error - Stream parser for Apache error logs

=head1 SYNOPSIS

    use Log::Stream::File;
    use Log::Stream::Parse::Apache::Error;
    my $path   = '/path/to/some/log';
    my $stream = Log::Stream::File->new({ file => $path });
    $stream = Log::Stream::Parse::Apache::Error->new($stream);

    # Read the next log record without consuming it.
    my $record = $stream->head;

    # The same, but consume it.
    $record = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later and the Date::Parse module (available as part of the
TimeDate distribution on CPAN) and Readonly module.

=head1 DESCRIPTION

Log::Stream::Parse::Apache::Error provides a stream-based parser for
Apache error logs.  Each record returned from the stream will be an
anonymous hash with the following elements:

=over 4

=item timestamp

The timestamp for this error log entry in seconds since UNIX epoch (the
same format as is returned by the Perl time function).

=item level

The Apache log level of this line.

=item client

The IP address of the client that provoked this message.  This key may not
be present if no client information was available.

=item data

The rest of the log entry.

=back

Unparsable lines will be silently skipped.

This object, and any classes derived from it, complies with the
Log::Stream interface and can be wrapped in Log::Stream::Filter or
Log::Stream::Transform objects if desired.

=head1 CLASS METHODS

=over 4

=item new(STREAM[, ARGS...])

Create a new object wrapping the provided Log::Stream object.  The ARGS
argument, if given, must be an anonymous hash.  The default constructor
doesn't do anything with it, but subclasses might.

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

Parses a single line of log and returns the results of the parse.

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
L<Log::Stream::Transform>

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
