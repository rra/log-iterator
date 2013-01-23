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

use Test::More tests => 21;

# Load the module.
BEGIN {
    use_ok('Log::Stream::Parsed::Apache::Error');
}

# Open the parsed log stream.
my $path = File::Spec->catfile(qw(t data samples webkdc));
if (!-r $path) {
    BAIL_OUT("cannot find test data: $path");
}
my $stream
  = eval { Log::Stream::Parsed::Apache::Error->new({ file => $path }) };
is($@, q{}, 'No exceptions on stream object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Parsed::Apache::Error');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Parsed object');
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
