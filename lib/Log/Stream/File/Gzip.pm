# Log::Stream::File::Gzip -- Read a gzipped log file as an infinite stream
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University

##############################################################################
# Modules and declarations
##############################################################################

package Log::Stream::File::Gzip;

use 5.010;
use autodie;
use strict;
use warnings;

# We do not actually use any Log::Stream::File code, so don't inherit from it.
use base qw(Log::Stream);

use Carp qw(croak);

# Module version.  Waiting for Perl 5.12 to switch to the new package syntax.
our $VERSION = '1.00';

##############################################################################
# Implementation
##############################################################################

# Internal helper function to spawn a gzip process to read the given file.
#
# $file - File to uncompress
#
# Returns: File descriptor of running gzip process.
sub _gunzip {
    my ($file) = @_;
    open(my $fh, q{-|}, 'gzip', '-dc', $file);
    return $fh;
}

# Create a new Log::Stream::File::Gzip object from the provided files.
#
# $class - Class of the object being created
# $args  - Anonymous hash of arguments, with files as the only supported key
#
# Returns: New Log::Stream::File::Gzip object
#  Throws: Text exception for invalid arguments or gzip failure
#          autodie::exception if forking gzip fails
sub new {
    my ($class, $args) = @_;

    # Ensure we were given a valid files argument and open the first file.
    if (!defined($args->{files})) {
        croak('Missing files argument to new');
    }
    my @files = ref($args->{files}) ? @{ $args->{files} } : ($args->{files});
    if (!@files) {
        croak('Empty files argument to new');
    }
    my $file = shift(@files);
    my $fh   = _gunzip($file);

    # Our generator code reads from each file in turn until hitting end of
    # file and then opens the next one.  We have to check if gunzip failed and
    # abort.
    my $code = sub {
        my $line;
      LINE: {
            $line = readline($fh);
            if (!defined($line)) {
                eval { close($fh) };
                if ($? != 0) {
                    croak("gzip -dc $file failed with exit status $?");
                }
                return if !@files;
                $file = shift(@files);
                $fh   = _gunzip($file);
                redo LINE;
            }
        }
        chomp($line);
        return $line;
    };

    # Construct and return the object.
    return $class->SUPER::new({ code => $code });
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery Kaufmann MERCHANTABILITY NONINFRINGEMENT parsers sublicense zlib

=head1 NAME

Log::Stream::File::Gzip - Read a gzipped log file as an infinite stream

=head1 SYNOPSIS

    use Log::Stream::File::Gzip;
    my $path   = '/path/to/log.gz';
    my $stream = Log::Stream::File::Gzip->new({ files => $path });

    # Read a line without consuming it.
    my $line = $stream->head;

    # Read a line and consume it.
    $line = $stream->get;

=head1 REQUIREMENTS

Perl 5.10 or later.

=head1 DESCRIPTION

Log::Stream::File::Gzip is identical to Log::Stream::File except that it
reads from a log file compressed with gzip or zlib.  For more information,
see L<Log::Stream::File>.

All methods may throw autodie::exception exceptions on I/O failure.

=head1 CLASS METHODS

=over 4

=item new(ARGS)

Create a new Log::Stream::File::Gzip.  ARGS should be an anonymous hash
with only one key: C<files>, whose value is either a single file name (as
a string) or an anonymous array of files.  All files must be compressed
with gzip or zlib.  If multiple files are given, they will be read from in
the order given, advancing to the next file once end of file is reached in
the previous file.

=back

=head1 INSTANCE METHODS

=over 4

=item head()

Returns the next line in the log stream without consuming it.  The
trailing newline will be removed.  Repeated calls to head() without an
intervening call to get() will keep returning the same line.  Returns
undef at the end of all files.

=item get()

Returns the next line in the log stream and consumes it.  The trailing
newline will be removed.  Repeated calls to get() will read through the
entire file, returning each line once.  Returns undef at the end of all
files.

=back

=head1 DIAGNOSTICS

=over 4

=item Empty files argument to new

(F) The argument to the C<files> key was an empty list of files.

=item Missing files argument to new

(F) The anonymous hash passed to new() did not contain a C<files> key.

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
