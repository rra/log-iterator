# Log::Stream::Parse::Apache::Error -- Stream parser for Apache error logs
#
# Written by Russ Allbery <rra@cpan.org>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Parse::Apache::Error;

use 5.010;
use strict;
use warnings;

use base qw(Log::Stream::Parse);

use Carp qw(croak);
use Readonly;
use Time::Local qw(timelocal);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

# Map of month names to localtime month numbers.
my %MONTH_TO_NUM = (
    Jan => 0,
    Feb => 1,
    Mar => 2,
    Apr => 3,
    May => 4,
    Jun => 5,
    Jul => 6,
    Aug => 7,
    Sep => 8,
    Oct => 9,
    Nov => 10,
    Dec => 11,
);

# Regex matching an Apache log timestamp.  Returns the timestamp (without the
# day of the week) as $1.
Readonly::Scalar my $TIMESTAMP_REGEX => qr{
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
Readonly::Scalar my $LEVEL_REGEX => qr{ \[ (\w+) \] }xms;

# Regex matching a client IP address.  Returns the IP address as $1.
Readonly::Scalar my $CLIENT_REGEX => qr{
    \[ client \s+ ([[:xdigit:].:]+) \]
}xms;

# Regex matching a whole Apache error log line.  Returns:
#
#     $1 - Timestamp
#     $2 - Log level
#     $3 - Client IP address (may be empty)
#     $4 - Rest of the log line
Readonly::Scalar my $APACHE_ERROR_REGEX => qr{
    \A
      $TIMESTAMP_REGEX
      \s+ $LEVEL_REGEX
      (?> \s+ $CLIENT_REGEX )?
      \s+ (.+)
    \z
}xmso;

# Cache the last converted timestamp and its result.
my $CACHE_TIMESTAMP = q{};
my $CACHE_RESULT;

##############################################################################
# Implementation
##############################################################################

# Given the timestamp from an Apache error log, convert it into seconds since
# epoch.  Do this with hand-rolled code, since str2time is rather slow and
# excessively complex when we already know the exact format.
#
# A timestamp looks like "Sun Feb 03 23:45:07 2013".
#
# $self      - The parser object
# $timestamp - The text timestamp from the log file
#
# Returns: The timestamp in seconds since epoch
sub _parse_timestamp {
    my ($timestamp) = @_;

    # Do memoization with a single cache.  If we saw the same timestamp as the
    # last time we were called, return the same value.  We normally process
    # logs in sequence, so doing more memoization is pointless and just bloats
    # memory usage.
    return $CACHE_RESULT if $timestamp eq $CACHE_TIMESTAMP;

    # Parse the timestamp and map it to localtime values.
    my ($mon, $mday, $hour, $min, $sec, $year) = split m{[ :]+}xms, $timestamp;
    $year -= 1900;

    # Convert assuming the current local time zone.
    my $time = eval {
        $mon = $MONTH_TO_NUM{$mon};
        timelocal($sec, $min, $hour, $mday, $mon, $year);
    };
    return if $@;

    # Cache for the next run.
    $CACHE_TIMESTAMP = $timestamp;
    $CACHE_RESULT    = $time;
    return $time;
}

# Given a line of Apache error log output, parse it into a result structure
# with fields as described in the POD for this module.
#
# $self - The parser object
# $line - The line to parse
#
# Returns: The corresponding data structure or an empty hash on parse failure
sub parse {
    my ($self, $line) = @_;
    if ($line =~ m{ $APACHE_ERROR_REGEX }xmso) {
        my ($timestamp, $level, $client, $data) = ($1, $2, $3, $4);
        $timestamp = _parse_timestamp($timestamp);
        return {} if !defined($timestamp);
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
Allbery API CPAN IP Kaufmann MERCHANTABILITY NONINFRINGEMENT Readonly
TimeDate sublicense subclasses timestamp

=head1 NAME

Log::Stream::Parse::Apache::Error - Stream parser for Apache error logs

=head1 SYNOPSIS

    use Log::Stream::Parse::Apache::Error;
    my $stream; # some existing stream

    # Parse the stream as Apache error log entries.
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
Apache error logs.  Each element returned from the stream will be an
anonymous hash with the following keys:

=over 4

=item timestamp

The timestamp for this error log entry in seconds since UNIX epoch (the
same format as is returned by the Perl time function).

=item level

The Apache log level of this log entry.

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

Returns the next log entry and consumes it.  Repeated calls to get() will
read through the entire log, returning each entry once.  Returns undef at
the end of the stream.

=item head()

Returns the next log entry without consuming it.  Repeated calls to
head() without an intervening call to get() will keep returning the same
entry.  Returns undef at the end of the stream.

=item parse(LINE)

Parses a single line of log and returns the results of the parse.  If a
line could not be parsed, will return an empty anonymous hash (which will
be edited out of the stream normally).

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

L<Log::Stream>, L<Log::Stream::Filter>, L<Log::Stream::Parse>,
L<Log::Stream::Parse::Apache::Combined>, L<Log::Stream::Transform>

Dominus, Mark Jason.  I<Higher Order Perl>.  San Francisco: Morgan
Kaufmann Publishers, 2005.  Print.

The current version of this module is always available from its web site
at L<http://www.eyrie.org/~eagle/software/log-stream/>.

=cut
