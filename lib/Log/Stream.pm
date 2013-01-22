# Log::Stream -- Read a line-based log file as an infinite stream.
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream;

use 5.010;
use autodie;
use strict;
use warnings;

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Create a new Log::Stream object pointing to the provided file.
#
# $class - Class of the object being created
# $file  - Path to the file to associate with the stream
#
# Returns: New Log::Stream object
#  Throws: autodie::exception object on I/O failure
sub new {
    my ($class, $file) = @_;
    open my $fh, q{<}, $file;
    my $self = {
        file => $fh,
        head => $fh->getline,
        tail => sub { return $fh->getline },
    };
    bless $self, $class;
    return $self;
}

# Returns the next line in the stream without consuming it.
#
# $self - The Log::Stream object
#
# Returns: Current value of head
sub head {
    my ($self) = @_;
    return $self->{head};
}

# Returns the next line in the stream and consumes it.  The tail sub is asked
# for the next head.
#
# $self - The Log::Stream object
#
# Returns: Current value of head
#  Throws: autodie::exception on I/O failure
sub get {
    my ($self) = @_;
    my $head = $self->{head};
    $self->{head} = $self->{tail}->();
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

Log::Stream - Read a line-based log file as an infinite stream

=head1 SYNOPSIS

    my $stream = Log::Stream->new('/path/to/log');

    # Read a line without consuming it.
    my $line = $stream->head;

    # Read a line and consume it.
    $line = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream provides an infinite stream interface to line-based log files
such as normal UNIX syslog or application log files.  It is primarily a
building block for more complex log parsers.  An infinite stream is
similar to an iterator, but also supports looking at the next element
without consuming it.

The stream operations are based loosely on the infinite streams discussed
in I<Higher Order Perl> by Mark Jason Dominus, but are not based on the
code from that book and use an object-oriented version of the interface.

All methods may throw autodie::exception exceptions on I/O failure.

=head1 CLASS METHODS

=over 4

=item new(FILE)

Open FILE and create a new Log::Stream object for it.

=back

=head1 INSTANCE METHODS

=over 4

=item head()

Returns the next line in the log stream without consuming it.  Repeated
calls to head() without an intervening call to get() will keep returning
the same line.  Returns undef at end of file.

=item get()

Returns the next line in the log stream and consumes it.  Repeated calls
to get() will read through the entire file, returning each line once.
Returns undef at end of file.

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
