# Log::Stream::Parse::Apache::Combined -- Stream parser for Apache logs
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2009, 2012, 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::Parse::Apache::Combined;

use 5.010;
use strict;
use warnings;

use base qw(Log::Stream::Parse);

use Carp qw(croak);
use Readonly;
use Time::Local qw(timegm);
use Text::CSV;

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

# Build a CSV parser for the Apache access logs.  The quote and escape syntax
# is something that Text::CSV can deal with, and it is much, much faster than
# using regular expressions.
Readonly::Scalar my $CSV_PARSER => Text::CSV->new(
    {
        sep_char    => q{ },
        quote_char  => q{"},    #"# cperl-mode
        escape_char => q{\\},
    }
);

# Regex to parse the query string.  We could use Text::CSV for this as well,
# but that doesn't handle weird cases such as unescaped double quotes in the
# query.
Readonly::Scalar my $QUERY_STRING_REGEX => qr{
    \A
    (?> ( [[:upper:]]+ ) \s+ )  # method (1)
    ( \S+ )                     # query itself (2)
    (?: \s+ ( HTTP/[\d.]+ ) )?  # optional protocol (3)
    \z
}xms;

# Cache the last converted timestamp and its result.
my $CACHE_TIMESTAMP = q{};
my $CACHE_RESULT;

##############################################################################
# Implementation
##############################################################################

# Given the timestamp from an Apache combined log, convert it into seconds
# since epoch.  Do this with hand-rolled code, since str2time is rather slow
# and excessively complex when we already know the exact format.
#
# A timestamp looks like "[03/Feb/2013:07:04:23 -0800]" and we get it in two
# parts, broken on the space.
#
# $self      - The parser object
# $timestamp - The text timestamp from the log file
#
# Returns: The timestamp in seconds since epoch
sub _parse_timestamp {
    my ($timestamp, $zone) = @_;

    # Do memoization with a single cached value.  If we saw the same timestamp
    # as the last time we were called, return the same value.  We normally
    # process logs in sequence, so doing more memoization is pointless and
    # just bloats memory usage.
    my $key = $timestamp . $zone;
    return $CACHE_RESULT if $key eq $CACHE_TIMESTAMP;

    # Parse the timestamp and map it to localtime values.
    my ($mday, $mon, $year, $hour, $min, $sec)
      = split(m{[/: ]}xms, substr($timestamp, 1));
    $year -= 1900;
    chop($zone);

    # Convert assuming a GMT time.
    my $time = eval {
        local $SIG{__WARN__} = sub { croak($_[0]) };
        $mon = $MONTH_TO_NUM{$mon};
        timegm($sec, $min, $hour, $mday, $mon, $year);
    };
    return if $@;

    # Handle the time zone offset.  Note that the zone is [+-]HHMM, not a
    # quantity of seconds.
    my $zone_sign = substr($zone, 0, 1) . '1';
    my $zone_hour = substr($zone, 1, 2);
    my $zone_min  = substr($zone, 3);
    $time -= $zone_sign * ($zone_hour * 60 + $zone_min) * 60;

    # Cache for the next run.
    $CACHE_TIMESTAMP = $key;
    $CACHE_RESULT    = $time;
    return $time;
}

# Given a line of Apache access log output, parse it into a result structure
# with fields as described in the POD for this module.
#
# $self - The parser object
# $line - The line to parse
#
# Returns: The corresponding data structure or an empty hash on parse failure
sub parse {
    my ($self, $line) = @_;

    # Attempt to parse the line.  If this fails, return the empty hash.
    if (!$CSV_PARSER->parse($line)) {
        return {};
    }

    # Read the results out of the parser.  We have four possibilities: seven
    # basic fields (the timestamp has internal whitespace, so it looks like
    # eight), with or without a leading virtual host, and with or without
    # trailing referrer and user agent information.
    #
    # Parsing this way and determining what we have from numeric field counds
    # is kind of ugly, but it saves about 25% of the run time compared to
    # parsing more directly with regular expressions.
    my @fields = $CSV_PARSER->fields;

    # If the log format added extra fields at the end, ignore them.
    if (@fields > 11) {
        @fields = @fields[0 .. 10];
    }

    # If there are too few fields, consider this unparsable.
    return {} if @fields < 8;

    # If there are an odd number of fields, we have a leading virtual host.
    my $vhost;
    if (@fields == 9 || @fields == 11) {
        $vhost = shift(@fields);
    }

    # Pull out the timestamp and parse it.  We also use this as our sanity
    # check to ensure that the line is a valid Apache log line.
    my (
        $client, $user,   $ident, $time,     $zone,
        $query,  $status, $size,  $referrer, $agent
    ) = @fields;
    my $timestamp = _parse_timestamp($time, $zone);
    return {} if !defined($timestamp);

    # Parse the query string.
    my ($method, $base_query, $protocol);
    if ($query =~ m{ $QUERY_STRING_REGEX }xmso) {
        ($method, $query, $protocol) = ($1, $2, $3);
        $base_query = $query;
        $base_query =~ s{ [?] .* }{}xms;
    }

    # Return the results.
    return {
        vhost      => $vhost,
        client     => $client,
        user       => $user ne q{-} ? $user : undef,
        ident_user => $ident ne q{-} ? $ident : undef,
        timestamp  => $timestamp,
        method     => $method,
        query      => $query,
        base_query => $base_query,
        protocol   => $protocol,
        status     => $status,
        size       => $size,
        referrer   => (@fields > 8 && $referrer ne q{-}) ? $referrer : undef,
        user_agent => (@fields > 9 && $agent ne q{-}) ? $agent : undef,
    };
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery API ARGS CGI CPAN CSV DNS Dominus IP Kaufmann MERCHANTABILITY
NONINFRINGEMENT Readonly TimeDate Unparsable hostname ident prepend
sublicense subclasses timestamp undef unparsed vhost

=head1 NAME

Log::Stream::Parse::Apache::Combined - Stream parser for Apache logs

=head1 SYNOPSIS

    use Log::Stream::Parse::Apache::Combined;
    my $stream; # some existing stream

    # Parse the stream as Apache combined log entries.
    $stream = Log::Stream::Parse::Apache::Combined->new($stream);

    # Read the next log record without consuming it.
    my $record = $stream->head;

    # The same, but consume it.
    $record = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later and the Readonly and Text::CSV modules (both available
from CPAN).

=head1 DESCRIPTION

Log::Stream::Parse::Apache::Combined provides a stream-based parser for
Apache access logs in the combined format.  Each element returned from the
stream will be an anonymous hash with the following keys:

=over 4

=item timestamp

The timestamp for this error log entry in seconds since UNIX epoch (the
same format as is returned by the Perl time function).

=item vhost

The local virtual host that was accessed.  This may not be set if the log
format doesn't prepend the virtual host to each access log line.

=item client

The hostname or IP address of the client.  Normally, this will be the IP
address, unless Apache is configured to do reverse DNS resolution for all
clients.

=item user

The authenticated user (the value of REMOTE_USER).  This key will be
omitted if there is no user authentication information.

=item ident_user

The user information from ident (the third column of the combined log
format).  This is almost always omitted.

=item method

The method used for this query.  This will be set if the query string
could be parsed; otherwise, the full unparsed string will be available
as query.

=item query

The URL (relative to this virtual host) that was accessed.  This will
include any CGI parameters, but will not include the protocol information.
If the query string cannot be parsed, this key will contain the full,
unparsed query and neither C<method> nor C<base_query> will be set.

=item base_query

Only the URL of the access, with any C<?> and anything after it stripped
off.  Note that this module has no way of knowing what part of the URL may
be path information, so all of that will still be included in the value of
this key.

=item protocol

The protocol specified for this access, if any.

=item status

The HTTP status code of this access.

=item size

The size of the reply returned by the server.

=item referrer

The referrer reported by the browser, if any was present.  This key will
be absent if there was no referrer information.

=item user_agent

The User-Agent header reported by the browser, if any was present.  This
key will be absent if there was no user agent information.

=back

Unparsable lines will be silently skipped.  Note that keys may exist with
undefined values even if the data in question wasn't present in that line
of the log.

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

=head1 WARNINGS

This module uses a single static CSV parser for speed and therefore is not
thread-safe.

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
