#!/usr/bin/perl
#
# Test for Apache error log parsing.
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
use Time::Local qw(timelocal);

use Test::More tests => 36;

# Load the module.
BEGIN {
    use_ok('Log::Stream::File');
    use_ok('Log::Stream::Parse::Apache::Error');
}

# Open the test file as a stream.
my $path = File::Spec->catfile(qw(t data samples webkdc));
if (!-r $path) {
    BAIL_OUT("cannot find test data: $path");
}
my $stream = Log::Stream::File->new({ files => $path });
isa_ok($stream, 'Log::Stream::File');

# Wrap it in a parser object.
$stream = eval { Log::Stream::Parse::Apache::Error->new($stream) };
is($@, q{}, 'No exceptions on stream object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Parse::Apache::Error');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Parse object');
}

# Load the result file.  This sets @RESULT.
our @RESULT;
my $results = File::Spec->catfile(qw(t data parsed webkdc-apache));
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

# Test a bunch of timestamp conversions directly.  We can only test if we can
# force a time zone, since the date format doesn't include the time zone.
local $ENV{TZ} = 'PST8PDT';
SKIP: {
    my $time = timelocal(23, 4, 7, 3, 1, 113);
    if ($time != 1_359_903_863) {
        skip 'cannot change time zone', 6;
    }

    # The set of times to test, except for ambiguous daylight savings.
    my %timestamp_to_time = (
        'Feb 03 07:04:23 2013' => 1_359_903_863,
        'Jan 01 00:00:00 2013' => 1_357_027_200,
        'Dec 31 23:59:59 2012' => 1_357_027_199,
        'Feb 29 07:14:15 2012' => 1_330_528_455,
        'Apr  2 01:59:59 2000' => 954_669_599,
        'Apr  2 03:00:00 2000' => 954_669_600,
        'Jan 01 00:00:00 1970' => 28_800,
        'Dec 31 16:00:00 1969' => 0,
    );
    for my $timestamp (sort keys %timestamp_to_time) {
        my $wanted = $timestamp_to_time{$timestamp};
        is($stream->_parse_timestamp($timestamp),
            $wanted, "Parse of $timestamp");
    }

    # Time during daylight savings is ambiguous.  Allow either.
    $time = $stream->_parse_timestamp('Oct 29 01:30:00 2000');
    if ($time == 972_808_200) {
        is($time, 972_808_200, 'Parse of Oct 29 01:30:00 2000');
    } else {
        is($time, 972_811_800, 'Parse of Oct 29 01:30:00 2000');
    }
}
