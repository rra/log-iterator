#!/usr/bin/perl
#
# Basic test for stream transforms.
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

use Test::More tests => 15;

# Load the modules.
BEGIN {
    use_ok('Log::Stream');
    use_ok('Log::Stream::Transform');
}

# Build a trivial little stream.
my @data   = qw(first second third);
my $code   = sub { return shift @data };
my $stream = Log::Stream->new({ code => $code });
isa_ok($stream, 'Log::Stream');

# Now, build a trivial transform (and also check $_ is set).
my $transform = sub {
    my ($element) = @_;
    if ($element ne $_) {
        die "\$_ not properly set\n";
    }
    return uc $element;
};
$stream = eval { Log::Stream::Transform->new($transform, $stream) };
is($@, q{}, 'No exceptions on transform object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Transform');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Transform object');
}

# Check the output.
is($stream->head, 'FIRST',  'First head() is FIRST');
is($stream->head, 'FIRST',  '...and returns the same when called again');
is($stream->get,  'FIRST',  'First get() is FIRST');
is($stream->head, 'SECOND', '...and now head() is SECOND');
is($stream->get,  'SECOND', 'Second get() is SECOND');
is($stream->get,  'THIRD',  'Third get() is THIRD');
is($stream->head, undef,    '...and now head() is undef');
is($stream->get,  undef,    '...and get() is undef');
is($stream->get,  undef,    '...and stays undef');
is($stream->head, undef,    '...and head is still undef');
