#!/usr/bin/perl
#
# Test for rewindable streams.
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

use Test::More tests => 79;

# Load the modules.
BEGIN {
    use_ok('Log::Stream');
    use_ok('Log::Stream::Rewindable');
}

# Build a trivial little stream.
my @data   = qw(first second third fourth);
my $code   = sub { return shift @data };
my $stream = Log::Stream->new({ code => $code });
isa_ok($stream, 'Log::Stream');

# Make it rewindable.
$stream = eval { Log::Stream::Rewindable->new($stream) };
is($@, q{}, 'No exceptions on filter object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::Rewindable');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::Rewindable object');
}

# Normal expected output if we use head and get on the first element.
is($stream->head, 'first',  'First head() is first');
is($stream->head, 'first',  '...and returns the same when called again');
is($stream->get,  'first',  'First get() is first');
is($stream->head, 'second', 'Head is now second');

# Set a bookmark and then consume a couple of elements.
ok($stream->bookmark, 'Bookmark successful');
is($stream->get,  'second', 'Second get() is second');
is($stream->get,  'third',  'Third get() is third');
is($stream->head, 'fourth', 'Head is now fourth');

# Rewind and we should be back where we were.
ok($stream->rewind, 'Rewind successful');
is($stream->head, 'second', 'Head is second after rewind');

# Set another bookmark and consume the entire stream.
ok($stream->bookmark, 'Bookmark successful');
is($stream->get,  'second', 'Second get() is second');
is($stream->get,  'third',  'Third get() is third');
is($stream->get,  'fourth', 'Fourth get() is fourth');
is($stream->head, undef,    'Head is now undef');
is($stream->get,  undef,    'Get returns undef');

# Test rewinding from exhausting the stream.
ok($stream->rewind, 'Rewind successful');
is($stream->get, 'second', 'Second get() is second after rewinding');

# Test bookmarking in the middle of rewound elements.
ok($stream->bookmark, 'Rewind successful');
is($stream->get, 'third',  'Third get() is third');
is($stream->get, 'fourth', 'Fourth get() is fourth');
is($stream->get, undef,    'Get returns undef');
ok($stream->rewind, 'Rewind successful');
is($stream->get, 'third',  'Third get() is third after rewinding');
is($stream->get, 'fourth', 'Fourth get() is fourth');
is($stream->get, undef,    'Get returns undef');

# Test prepending some data to the stream.
ok($stream->prepend(qw(fifth sixth)), 'Prepend successful');
is($stream->head, 'fifth', 'Head is now fifth');
is($stream->get,  'fifth', 'Fifth get() is fifth');

# Test bookmarking in the middle of prepended data.
ok($stream->bookmark, 'Bookmark successful');
is($stream->get, 'sixth', 'Sixth get() is sixth');
is($stream->get, undef,   'Get returns undef');
ok($stream->rewind, 'Rewind successful');
is($stream->get, 'sixth', 'Get returns sixth after rewind');

# Refresh the stream.
@data = qw(first second third fourth);
$stream = Log::Stream::Rewindable->new(Log::Stream->new({ code => $code }));
isa_ok($stream, 'Log::Stream::Rewindable');

# Test discarding bookmarked data.
ok($stream->bookmark, 'Bookmark successful');
is($stream->get, 'first',  'First get() is first after refresh');
is($stream->get, 'second', 'Second get() is second');
ok($stream->discard, 'Discard successful');
my $return = eval { $stream->rewind };
ok(!$return, 'Rewind fails after discard');
like(
    $@,
    qr{ \A No [ ] bookmark [ ] set [ ] in [ ] stream [ ] at [ ] }xms,
    '...with correct error'
);
$return = eval { $stream->discard };
ok(!$return, 'Discard fails after discard');
like(
    $@,
    qr{ \A No [ ] bookmark [ ] set [ ] in [ ] stream [ ] at [ ] }xms,
    '...with correct error'
);

# Test retreiving the bookmarked data.
ok($stream->bookmark, 'Bookmark successful');
is($stream->get, 'third',  'Third get() is third');
is($stream->get, 'fourth', 'Fourth get() is fourth');
is($stream->get, undef,    'Found end of stream');
is_deeply([$stream->saved], [qw(third fourth)], 'Saved data is correct');
ok($stream->rewind, '...and can still rewind');
is($stream->head, 'third', '...to the correct point');
$return = eval { $stream->rewind };
ok(!$return, '...but cannot rewind again');
like(
    $@,
    qr{ \A No [ ] bookmark [ ] set [ ] in [ ] stream [ ] at [ ] }xms,
    '...with correct error'
);
$return = eval { $stream->saved };
ok(!$return, '...and cannot retrieve saved data');
like(
    $@,
    qr{ \A No [ ] bookmark [ ] set [ ] in [ ] stream [ ] at [ ] }xms,
    '...with correct error'
);
ok($stream->bookmark, 'Bookmark successful');
is_deeply([$stream->saved], [], '...and immediate saved returns empty list');

# Refresh the stream.
@data = qw(first second third fourth);
$stream = Log::Stream::Rewindable->new(Log::Stream->new({ code => $code }));
isa_ok($stream, 'Log::Stream::Rewindable');

# Calling bookmark twice does an implicit discard.
ok($stream->bookmark, 'Bookmark successful');
is($stream->get, 'first',  'First get() is first after refresh');
is($stream->get, 'second', 'Second get() is second');
ok($stream->bookmark, 'Calling bookmark again is successful');
is_deeply([$stream->saved], [], '...and there are no saved elements');
is($stream->get, 'third', 'Third get() is third');
ok($stream->rewind, 'Rewind successful');
is($stream->head, 'third', '...and returns to the second bookmark');

# Try prepending nothing with an empty head.
is($stream->get, 'third', 'get() returns third');
ok($stream->prepend(), 'Prepend of nothing succeeds');
is($stream->head, 'fourth', 'Head is now fourth');
is($stream->get,  'fourth', '...and get() returns fourth');

# Test starting with an empty stream.
$code = sub { return };
$stream = Log::Stream::Rewindable->new(Log::Stream->new({ code => $code }));
isa_ok($stream, 'Log::Stream::Rewindable');
is($stream->head, undef, 'Head of empty stream is undef');
ok($stream->prepend('first'), 'Prepending to an empty stream works');
is($stream->head, 'first', 'Head is now first');
is($stream->get,  'first', '... and get returns first');
