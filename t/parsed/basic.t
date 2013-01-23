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

use Test::More tests => 15;

# Load the modules.
BEGIN {
    use_ok('Log::Stream');
    use_ok('Log::Stream::Parsed');
}

# Build a trivial little stream.
my @data   = qw(first second third fourth);
my $code   = sub { return shift @data };
my $stream = Log::Stream->new({ code => $code });
isa_ok($stream, 'Log::Stream');

# Wrap it in a parser object.
$stream = eval { Log::Stream::Parsed->new($stream) };
is($@, q{}, 'No exceptions on stream object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Parsed');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Parsed object');
}

# Check the output.
for my $data (qw(first second third fourth)) {
    my $element = { data => $data };
    is_deeply($stream->head, $element, "Head of $data");
    is_deeply($stream->get,  $element, "Get of $data");
}
is($stream->head, undef, 'Undef from head at end of stream');
is($stream->get,  undef, 'Undef from get at end of stream');
