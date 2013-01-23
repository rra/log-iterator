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

use Test::More tests => 20;

# Load the modules.
BEGIN {
    use_ok('Log::Stream');
    use_ok('Log::Stream::Transform');
}

# A basic log parser.  This one splits a syslog log into timestamp and
# remaining data.
#
# $line - The input line to parse
#
# Returns: A reference to a hash representing that line
#          undef on parse failure
sub syslog_parser {
    my ($line) = @_;
    if ($line =~ m{ \A (\w{3} \s+ \d+ \s+ [\d:]+) \s+ (.*) \z }xms) {
        my ($timestamp, $data) = ($1, $2);
        return { timestamp => $timestamp, data => $data };
    } else {
        return;
    }
}

# Open the test data stream.
my $path = File::Spec->catfile(qw(t data samples syslog));
if (!-r $path) {
    BAIL_OUT("cannot find test data: $path");
}
my $stream = eval { Log::Stream->new($path) };
is($@, q{}, 'No exceptions on stream object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream object');
}

# Wrap a stream transform around it.
$stream = eval { Log::Stream::Transform->new(\&syslog_parser, $stream) };
is($@, q{}, 'No exceptions on filter object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Transform');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Transform object');
}

# Open the same test file manually and verify that we get the same results
# from the stream.  Use both stream read methods.
open my $log, q{<}, $path;
my @log_records = map { syslog_parser($_) } <$log>;
close $log;
for my $i (0 .. $#log_records) {
    my $log_record = $log_records[$i];
    is_deeply($stream->head, $log_record, "Head of line $i");
    my $stream_record = $stream->get;
    is_deeply($stream_record, $log_record, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');
