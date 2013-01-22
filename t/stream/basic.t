#!/usr/bin/perl
#
# Basic test for log streaming.
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

use Test::More tests => 17;

# Load the module.
BEGIN {
    use_ok('Log::Stream');
}

# Open the test data stream.
my $path = File::Spec->catfile(qw(t data samples syslog));
if (!-r $path) {
    BAIL_OUT("cannot find test data: $path");
}
my $stream = eval { Log::Stream->new($path) };
is($@, q{}, 'No exceptions on object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream object');
}

# Open the same test file manually and verify that we get the same results
# from the stream.  Use both stream read methods.
open my $log, q{<}, $path;
my @log_lines = <$log>;
close $log;
for my $i (0 .. $#log_lines) {
    my $log_line = $log_lines[$i];
    is($stream->head, $log_line, "Head of line $i");
    my $stream_line = $stream->get;
    is($stream_line, $log_line, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');
