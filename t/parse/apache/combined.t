#!/usr/bin/perl
#
# Test for Apache combined access log parsing.
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

use Test::More tests => 37;

# Load the module.
BEGIN {
    use_ok('Log::Stream::File');
    use_ok('Log::Stream::Parse::Apache::Combined');
}

# Open the test file as a stream.
my $path = File::Spec->catfile(qw(t data samples apache));
if (!-r $path) {
    BAIL_OUT("cannot find test data: $path");
}
my $stream = Log::Stream::File->new({ files => $path });
isa_ok($stream, 'Log::Stream::File');

# Wrap it in a parser object.
$stream = eval { Log::Stream::Parse::Apache::Combined->new($stream) };
is($@, q{}, 'No exceptions on stream object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Parse::Apache::Combined');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Parse object');
}

# Load the result file.  This sets @RESULT.
our @RESULT;
my $results = File::Spec->catfile(qw(t data parsed apache));
do $results;
if ($@) {
    BAIL_OUT("cannot read $results: $@");
}
if ($!) {
    BAIL_OUT("cannot read $results: $!");
}

# Iterate through the results and stream and make sure they match.  Use both
# stream read methods.
for my $i (0 .. $#RESULT) {
    my $log_record = $RESULT[$i];
    is_deeply($stream->head, $log_record, "Head of line $i");
    my $stream_record = $stream->get;
    is_deeply($stream_record, $log_record, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');

# Test a bunch of timestamp conversions directly.
my %timestamp_to_time = (
    '03/Feb/2013:07:04:23 -0800' => 1_359_903_863,
    '03/Feb/2013:07:04:23 -0000' => 1_359_875_063,
    '03/Feb/2013:07:04:23 +0000' => 1_359_875_063,
    '03/Feb/2013:07:04:23 -1230' => 1_359_920_063,
    '01/Jan/2013:00:00:00 -0100' => 1_357_002_000,
    '31/Dec/2012:23:59:59 -0000' => 1_356_998_399,
    '29/Feb/2012:07:14:15 -0130' => 1_330_505_055,
    '29/Feb/2012:07:14:15 +0130' => 1_330_494_255,
    '01/Jan/1970:00:00:00 -0800' => 28_800,
    '01/Jan/1970:00:00:00 -0000' => 0,
);
for my $timestamp (sort keys %timestamp_to_time) {
    my $time = $timestamp_to_time{$timestamp};
    is($stream->_parse_timestamp($timestamp), $time, "Parse of $timestamp");
}
