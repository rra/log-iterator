#!/usr/bin/perl
#
# Basic test for log parsing infrastructure.
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
    use_ok('Log::Stream::Parsed');
}

# Open the parsed log stream.
my $path = File::Spec->catfile(qw(t data samples syslog));
if (!-r $path) {
    BAIL_OUT("cannot find test data: $path");
}
my $stream = eval { Log::Stream::Parsed->new($path) };
is($@, q{}, 'No exceptions on stream object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Parsed');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Parsed object');
}

# Open the same test file manually and verify that we get the same results
# from the stream.  Use both stream read methods.
open my $log, q{<}, $path;
my @log_lines = <$log>;
close $log;
for my $i (0 .. $#log_lines) {
    my $log_record = { data => $log_lines[$i] };
    is_deeply($stream->head, $log_record, "Head of line $i");
    my $stream_record = $stream->get;
    is_deeply($stream_record, $log_record, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');
