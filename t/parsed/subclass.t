#!/usr/bin/perl
#
# Test the subclassing and filtering of Log::Stream::Parsed.
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University
#
# See LICENSE for licensing terms.

use 5.010;
use autodie;
use strict;
use warnings;

use File::Spec;

use Test::More tests => 11;

# Load the modules.
BEGIN {
    use_ok('Log::Stream');
    use_ok('Log::Stream::Parsed');
}

# Subclass Log::Stream::Parsed with something that returns references.
## no critic (Modules::ProhibitMultiplePackages)
package Log::Stream::Parsed::Test;
use base qw(Log::Stream::Parsed);

# Parser that returns the line it was passed in for first, the empty hash for
# second, and a references to the line that was passed in for third.
#
# $self - Log::Stream::Parsed::Test object
# $line - The line of input from the stream
#
# Returns: A reference to $line
sub parse {
    my ($self, $line) = @_;
    return
        $line eq 'first'  ? $line
      : $line eq 'second' ? {}
      :                     \$line;
}

# Back to main to test its behavior.
package main;

# Build a simple little stream.
my @data   = qw(first second third);
my $code   = sub { return shift @data };
my $stream = Log::Stream->new({ code => $code });
isa_ok($stream, 'Log::Stream');

# Create a new parser object.
$stream = eval { Log::Stream::Parsed::Test->new($stream) };
is($@, q{}, 'No exceptions on stream object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Parsed::Test');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Parsed object');
}

# Check the output.  Emacs cperl-mode hates \'third'.
my $third = 'third';
for my $data ('first', \$third) {
    is_deeply($stream->head, $data, "Head of $data");
    is_deeply($stream->get,  $data, "Get of $data");
}
is($stream->head, undef, 'Undef from head at end of stream');
is($stream->get,  undef, 'Undef from get at end of stream');
