#!/usr/bin/perl
#
# Test for a basic log stream.
#
# Written by Russ Allbery <rra@cpan.org>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University
#
# See LICENSE for licensing terms.

use 5.010;
use autodie;
use strict;
use warnings;

use Test::More tests => 18;

# Load the module.
BEGIN { use_ok('Log::Stream') }

# The function we'll use to generate the stream.  This returns the string
# 'test' the first time it's called, 'second' the second time it's called,
# undef the third time it's called, and then the string 'error'.  This is used
# to check that we don't call the code reference after it returns undef to
# indicate the end of the stream.
sub stream {
    my @data = ('test', 'second', undef, 'error');
    state $i = 0;
    return $data[$i++];
}

# Create the stream.
my $stream = eval { Log::Stream->new({ code => \&stream }) };
is($@, q{}, 'No exceptions on object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream object');
}

# Check the output.
is($stream->head, 'test',   'First head() is test');
is($stream->head, 'test',   '...and returns the same when called again');
is($stream->get,  'test',   'First get() is test');
is($stream->head, 'second', '...and now head() is second');
is($stream->get,  'second', 'Second get() is second');
is($stream->head, undef,    '...and now head() is undef');
is($stream->get,  undef,    '...and get() is undef');
is($stream->get,  undef,    '...and stays undef');
is($stream->head, undef,    '...and head is still undef');

# Test error handling.
$stream = eval { Log::Stream->new({}) };
is($stream, undef, 'Creation failed without code argument');
like($@, qr{ \A Missing [ ] code [ ] argument [ ] to [ ] new [ ] at [ ] }xms,
    '...error');
$stream = eval { Log::Stream->new({ code => 'foo' }) };
is($stream, undef, 'Creation failed with string code argument');
like(
    $@,
    qr{ \A code [ ] argument [ ] to [ ] new [ ] is [ ] not [ ] a [ ] code
        [ ] reference [ ] at [ ] }xms,
    '...error'
);
my @data = (qw(data));
$stream = eval { Log::Stream->new({ code => \@data }) };
is($stream, undef, 'Creation failed with array code argument');
like(
    $@,
    qr{ \A code [ ] argument [ ] to [ ] new [ ] is [ ] not [ ] a [ ] code
        [ ] reference [ ] at [ ] }xms,
    '...error'
);
