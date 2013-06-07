#!/usr/bin/perl
#
# Test for a gzip-compressed file-based log stream.
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

use Test::More tests => 81;

# Load the module.
BEGIN { use_ok('Log::Stream::File::Gzip') }

# Open the test data stream.
my $path = File::Spec->catfile(qw(t data samples syslog.gz));
if (!-r $path) {
    BAIL_OUT("cannot find test data: $path");
}
my $stream = eval { Log::Stream::File::Gzip->new({ files => $path }) };
is($@, q{}, 'No exceptions on object creation');
if ($stream) {
    isa_ok($stream, 'Log::Stream::File::Gzip');
} else {
    ok(0, 'Object creation failed');
    BAIL_OUT('cannot continue without Log::Stream::File::Gzip object');
}

# Open the same test file manually and verify that we get the same results
# from the stream.  Use both stream read methods.
my $uncompressed = File::Spec->catfile(qw(t data samples syslog));
open my $log, q{<}, $uncompressed;
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
$stream = Log::Stream::File::Gzip->new({ files => [$path, $path] });
isa_ok($stream, 'Log::Stream::File::Gzip');
@log_lines = (@log_lines, @log_lines);
for my $i (0 .. $#log_lines) {
    my $log_line = $log_lines[$i];
    is($stream->head, $log_line, "Head of line $i");
    is($stream->get,  $log_line, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');

# Test the empty file.
my $empty = File::Spec->catfile(qw(t data samples empty.gz));
$stream = Log::Stream::File::Gzip->new({ files => $empty });
isa_ok($stream, 'Log::Stream::File::Gzip');
is($stream->head, undef, 'Undef from head of /dev/null');
is($stream->get,  undef, 'Undef from get of /dev/null');

# Test the empty file mixed into other valid files.
my %args = (files => [$empty, $path, $empty, $path]);
$stream = Log::Stream::File::Gzip->new(\%args);
isa_ok($stream, 'Log::Stream::File::Gzip');
for my $i (0 .. $#log_lines) {
    my $log_line = $log_lines[$i];
    is($stream->head, $log_line, "Head of line $i");
    is($stream->get,  $log_line, "Get of line $i");
}
is($stream->head, undef, 'Undef from head at end of file');
is($stream->get,  undef, 'Undef from get at end of file');

# Test constructor error handling.
$stream = eval { Log::Stream::File::Gzip->new({}) };
is($stream, undef, 'Creation failed without files argument');
like($@, qr{ \A Missing [ ] files [ ] argument [ ] to [ ] new [ ] at [ ] }xms,
    '...error');
$stream = eval { Log::Stream::File::Gzip->new({ files => [] }) };
is($stream, undef, 'Creation failed empty files argument');
like($@, qr{ \A Empty [ ] files [ ] argument [ ] to [ ] new [ ] at [ ] }xms,
    '...error');

# A single nonexistent file.
open(my $olderr, '>&', \*STDERR) or BAIL_OUT("Cannot save STDERR: $!");
close(STDERR) or BAIL_OUT("Cannot close STDERR: $!");
$stream
  = eval { Log::Stream::File::Gzip->new({ files => ['./nonexistent'] }) };
open(STDERR, '>&', $olderr) or BAIL_OUT("Cannot restore STDERR: $!");
close($olderr) or BAIL_OUT("Cannot close saved error: $!");
is($stream, undef, 'Creation failed with nonexistent file');
like(
    $@,
    qr{ \A gzip [ ] -dc [ ] [.] /nonexistent [ ] failed [ ] with [ ] exit
        [ ] status [ ] \d+ [ ] at [ ] }xms,
    '...error'
);

# Multiple files, the last of which is nonexistent.
open($olderr, '>&', \*STDERR) or BAIL_OUT("Cannot save STDERR: $!");
close(STDERR) or BAIL_OUT("Cannot close STDERR: $!");
$stream = Log::Stream::File::Gzip->new({ files => [$path, './nonexistent'] });
local $@ = undef;
while ($stream->head && !$@) {
    eval { $stream->get };
}
open(STDERR, '>&', $olderr) or BAIL_OUT("Cannot restore STDERR: $!");
close($olderr) or BAIL_OUT("Cannot close saved error: $!");
like(
    $@,
    qr{ \A gzip [ ] -dc [ ] [.] /nonexistent [ ] failed [ ] with [ ] exit
        [ ] status [ ] \d+ [ ] at [ ] }xms,
    'Error when opening nonexistent file'
);
