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
use autodie;
use strict;
use warnings;

use base qw(Log::Stream::Parse);

use Date::Parse qw(str2time);
use Memoize;
use Readonly;

# Memoize str2time, which is otherwise painfully slow.
memoize('str2time');

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

# Components of an Apache access log.
Readonly my $VHOST_REGEX  => qr{ (?: ( [\w._:-]+ ) \s )?      }xms;
Readonly my $CLIENT_REGEX => qr{ ( [[:xdigit:].:]+ )          }xms;
Readonly my $USER_REGEX   => qr{ ( \S+ )                      }xms;
Readonly my $TIME_REGEX   => qr{ \[ ( [^\]]+ ) \]             }xms;
Readonly my $STRING_REGEX => qr{ \" ( (?> \\. | [^\"] )+ ) \" }xms;

# Regex to match a single line of Apache access log output.
Readonly my $APACHE_ACCESS_REGEX => qr{
    \A
    (?>
      $VHOST_REGEX              # optional virtual host (1)
      $CLIENT_REGEX             # client IP address (2)
      \s $USER_REGEX            # authentication information (3)
      \s $USER_REGEX            # ident information (4)
      \s $TIME_REGEX            # timestamp (5)
    )                           # stop backtracking once we find timestamp
    \s $STRING_REGEX            # query (6)
    \s ( \d+ )                  # HTTP status (7)
    \s ( \d+ )                  # size (8)
    (?:                         # look for user agent (optional)
      \s $STRING_REGEX          # referrer (9)
      \s $STRING_REGEX          # user agent (10)
    )?
    \s* \z
}xms;

# Regex to parse the query string.
Readonly my $QUERY_STRING_REGEX => qr{
    \A
    (?> ( [[:upper:]]+ ) \s+ )  # method (1)
    ( \S+ )                     # query itself (2)
    (?: \s+ ( HTTP/[\d.]+ ) )?  # optional protocol (3)
    \z
}xms;

##############################################################################
# Implementation
##############################################################################

# Given a line of Apache access log output, parse it into a result structure
# with fields as described in the POD for this module.
#
# $self - The parser object
# $line - The line to parse
#
# Returns: The corresponding data structure or an empty hash on parse failure
sub parse {
    my ($self, $line) = @_;
    if ($line =~ m{ $APACHE_ACCESS_REGEX }oxms) {
        my (
            $vhost,     $client,       $user,   $ident_user,
            $timestamp, $query_string, $status, $size,
            $referrer,  $user_agent
        ) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);

        # Flesh out the basic information.
        $timestamp = str2time($timestamp);
        my $result = {
            timestamp => $timestamp,
            client    => $client,
            status    => $status,
            size      => $size,
        };

        # Optional information.  Only add the key if we have a useful value.
        if (defined $vhost) {
            $result->{vhost} = $vhost;
        }
        if ($user ne q{-}) {
            $result->{user} = $user;
        }
        if ($ident_user ne q{-}) {
            $result->{ident_user} = $ident_user;
        }
        if (defined($referrer) && $referrer ne q{-}) {
            $referrer =~ s{ \\ (.) }{$1}gxms;
            $result->{referrer} = $referrer;
        }
        if (defined($user_agent) && $user_agent ne q{-}) {
            $user_agent =~ s{ \\ (.) }{$1}gxms;
            $result->{user_agent} = $user_agent;
        }

        # Parse the query string.
        $query_string =~ s{ \\ (.) }{$1}gxms;
        if ($query_string =~ m{ $QUERY_STRING_REGEX }oxms) {
            my ($method, $query, $protocol) = ($1, $2, $3);
            my $base_query = $query;
            $base_query =~ s{ [?] .* }{}xms;
            $result->{method}     = $method;
            $result->{query}      = $query;
            $result->{base_query} = $base_query;
            if (defined $protocol) {
                $result->{protocol} = $protocol;
            }
        } else {
            $result->{query} = $query_string;
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
API ARGS CGI CPAN DNS Dominus IP Kaufmann MERCHANTABILITY NONINFRINGEMENT
Readonly TimeDate Unparsable hostname ident prepend sublicense subclasses
timestamp undef unparsed vhost

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

Perl 5.10 or later and the Date::Parse module (available as part of the
TimeDate distribution on CPAN) and Readonly module.

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
