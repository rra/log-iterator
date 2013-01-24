#!/usr/bin/perl
#
# Test for a simple file-based log stream.
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

use Test::More tests => 78;

# Load the module.
BEGIN { use_ok('Log::Stream::File') }

# Open the test data stream.
my $path = File::Spec->catfile(qw(t data samples syslog));
if (!-r $path) {
    BAIL_OUT("cannot find test data: $path");
}
my $stream = eval { Log::Stream::File->new({ files => $path }) };
is($@, q{}, 'No exceptions on object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::File');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::File object');
}

# Open the same test file manually and verify that we get the same results
# from the stream.  Use both stream read methods.
open my $log, q{<}, $path;
my @log_lines = <$log>;
close $log;
chomp @log_lines;
for my $i (0 .. $#log_lines) {
    my $log_line = $log_lines[$i];
    is($stream->head, $log_line, "Head of line $i");
    is($stream->get,  $log_line, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');

# Test handling multiple files by opening the same file twice.
$stream = Log::Stream::File->new({ files => [$path, $path] });
isa_ok($stream, 'Log::Stream::File');
@log_lines = (@log_lines, @log_lines);
for my $i (0 .. $#log_lines) {
    my $log_line = $log_lines[$i];
    is($stream->head, $log_line, "Head of line $i");
    is($stream->get,  $log_line, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');

# Test the empty device.
my $devnull = File::Spec->devnull;
$stream = Log::Stream::File->new({ files => $devnull });
isa_ok($stream, 'Log::Stream::File');
is($stream->head, undef, 'Undef from head of /dev/null');
is($stream->get,  undef, 'Undef from get of /dev/null');

# Test the empty device mixed into other valid files.
my %args = (files => [$devnull, $path, $devnull, $path]);
$stream = Log::Stream::File->new(\%args);
isa_ok($stream, 'Log::Stream::File');
for my $i (0 .. $#log_lines) {
    my $log_line = $log_lines[$i];
    is($stream->head, $log_line, "Head of line $i");
    is($stream->get,  $log_line, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');

# Test error handling.
$stream = eval { Log::Stream::File->new({}) };
is($stream, undef, 'Creation failed without files argument');
like($@, qr{ \A Missing [ ] files [ ] argument [ ] to [ ] new [ ] at [ ] }xms,
    '...error');
$stream = eval { Log::Stream::File->new({ files => [] }) };
is($stream, undef, 'Creation failed empty files argument');
like($@, qr{ \A Empty [ ] files [ ] argument [ ] to [ ] new [ ] at [ ] }xms,
    '...error');
