#!/usr/bin/perl
#
# Basic test for stream filters.
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

use File::Spec;

use Test::More tests => 19;

# Load the modules.
BEGIN {
    use_ok('Log::Stream');
    use_ok('Log::Stream::Filter');
}

# Build a trivial little stream.
my @data   = qw(first second third fourth);
my $code   = sub { return shift @data };
my $stream = Log::Stream->new({ code => $code });
isa_ok($stream, 'Log::Stream');

# Now, build a trivial filter (and also check $_ is set).
my $filter = sub {
    my ($element) = @_;
    if ($element ne $_) {
        die "$_ not properly set\n";
    }
    return scalar $element =~ m{d}xms;
};
$stream = eval { Log::Stream::Filter->new($filter, $stream) };
is($@, q{}, 'No exceptions on filter object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Filter');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Filter object');
}

# Check the output.
is($stream->head, 'second', 'First head() is second');
is($stream->head, 'second', '...and returns the same when called again');
is($stream->get,  'second', 'First get() is second');
is($stream->head, 'third',  '...and now head() is second');
is($stream->get,  'third',  'Second get() is third');
is($stream->head, undef,    '...and now head() is undef');
is($stream->get,  undef,    '...and get() is undef');
is($stream->get,  undef,    '...and stays undef');
is($stream->head, undef,    '...and head is still undef');

# Test filtering a single element stream.
@data   = qw(first);
$stream = Log::Stream->new({ code => $code });
$stream = eval { Log::Stream::Filter->new($filter, $stream) };
is($@,            q{},   'No exceptions on filter object creation');
is($stream->head, undef, 'First head() is undef on short stream');

# Test filtering an empty stream.
$code = sub { return };
$stream = Log::Stream->new({ code => $code });
$stream = eval { Log::Stream::Filter->new($filter, $stream) };
is($@,                 q{},   'No exceptions on filter object creation');
is($stream->head,      undef, 'First head() is undef on empty stream');
is($stream->generator, undef, 'tail() is undef on empty stream');
