#!/usr/bin/perl
#
# Test for merging of rewindable streams.
#
# Written by Russ Allbery <rra@cpan.org>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University
#
# See LICENSE for licensing terms.

use 5.010;
use strict;
use warnings;

use File::Spec;
use Readonly;

use Test::More tests => 16;

# Load the modules.
BEGIN {
    use_ok('Log::Stream');
    use_ok('Log::Stream::Merge::Rewindable');
    use_ok('Log::Stream::Rewindable');
}

# The threshold for how far we'll look into the second stream for elements
# that match the first stream.
Readonly my $THRESHOLD => 10;

# Build two trivial little streams.
my @data_one   = qw(11 4 17 2 4 11);
my $code_one   = sub { return shift @data_one };
my $stream_one = Log::Stream->new({ code => $code_one });
isa_ok($stream_one, 'Log::Stream');
my @data_two   = qw(1 2 3 4 5 6 7 8 9 10 11);
my $code_two   = sub { return shift @data_two };
my $stream_two = Log::Stream->new({ code => $code_two });
isa_ok($stream_two, 'Log::Stream');

# Make the first stream rewindable so that we can test both branches.
$stream_one = Log::Stream::Rewindable->new($stream_one);
isa_ok($stream_one, 'Log::Stream::Rewindable');

# Our merging algorithm is the example from the module synopsis.  We return
# only those elements from the first stream where a matching element occurs
# in the second stream within the top ten elements.
my $code = sub {
    my ($one, $two) = @_;
  ONE: {
        my $element = $one->get;
        return if !defined $element;
        $two->bookmark;
      TWO:
        for my $i (1 .. $THRESHOLD) {
            last TWO if !defined $two->head;
            next TWO if $two->get ne $element;

            # Drop the element we found so we don't match twice.
            my @saved = $two->saved;
            pop @saved;
            $two->discard;
            $two->prepend(@saved);
            return $element;
        }
        $two->rewind;
        redo ONE;
    }
};

# Build a merged stream with that algorithm.
my $stream = eval {
    Log::Stream::Merge::Rewindable->new($code, $stream_one, $stream_two);
};
is($@, q{}, 'No exceptions on merge object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Merge::Rewindable');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Merge::Rewindable object');
}

# Check the output.
for my $data (qw(4 2 11)) {
    is($stream->head, $data, "head() returns $data");
    is($stream->get,  $data, "get() returns $data");
}
is($stream->head, undef, 'head() is undef at end of stream');
is($stream->get,  undef, 'get() is undef at end of stream');
