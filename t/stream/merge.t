#!/usr/bin/perl
#
# Basic test for stream merging.
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

use Test::More tests => 33;

# Load the modules.
BEGIN {
    use_ok('Log::Stream');
    use_ok('Log::Stream::Merge');
}

# Build two trivial little streams.
my @data_one   = qw(first second);
my $code_one   = sub { return shift @data_one };
my $stream_one = Log::Stream->new({ code => $code_one });
isa_ok($stream_one, 'Log::Stream');
my @data_two   = qw(one two three);
my $code_two   = sub { return shift @data_two };
my $stream_two = Log::Stream->new({ code => $code_two });
isa_ok($stream_two, 'Log::Stream');

# Now, merge them with the default algorithm.
my $stream = eval { Log::Stream::Merge->new($stream_one, $stream_two) };
is($@, q{}, 'No exceptions on merge object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Merge');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Merge object');
}

# Check the output.
for my $data (qw(first one second two three)) {
    is($stream->head, $data, "head() returns $data");
    is($stream->get,  $data, "get() returns $data");
}
is($stream->head, undef, 'head() is undef at end of stream');
is($stream->get,  undef, 'get() is undef at end of stream');

# Rebuild the streams.
@data_one   = qw(first second);
@data_two   = qw(one two three);
$stream_one = Log::Stream->new({ code => $code_one });
$stream_two = Log::Stream->new({ code => $code_two });
isa_ok($stream_one, 'Log::Stream');
isa_ok($stream_two, 'Log::Stream');

# Define a merge function that concatenates from both streams instead.  This
# is the example from the module synopsis.
my $code = sub {
    my (@streams) = @_;
    my $result = q{};
    for my $stream (@streams) {
        my $element = $stream->get;
        if (defined $element) {
            $result .= $element;
        }
    }
    return $result;
};
$stream = Log::Stream::Merge->new($code, $stream_one, $stream_two);
isa_ok($stream, 'Log::Stream::Merge');

# Check the output.
for my $data (qw(firstone secondtwo three)) {
    is($stream->head, $data, "head() returns $data");
    is($stream->get,  $data, "get() returns $data");
}
is($stream->head, q{}, 'head() is the empty string at end of streams');
is($stream->get,  q{}, 'get() is the empty string at end of streams');
is($stream->get,  q{}, '...and just keeps returning the empty string');

# Test the merge of two empty streams with the default merge.
my $empty = sub { return };
$stream_one = Log::Stream->new({ code => $empty });
$stream_two = Log::Stream->new({ code => $empty });
$stream = Log::Stream::Merge->new($stream_one, $stream_two);
isa_ok($stream, 'Log::Stream::Merge');
is($stream->head, undef, 'head is undef when merging two empty streams');

# Test a seldom-seen error branch in the constructor.  This would blow up
# later anyway, but we want 100% coverage.  Eventually, we should test that
# our streams can get.
$stream = eval { Log::Stream::Merge->new('some string') };
is($stream, undef, 'Creation failed with a bad code argument');
