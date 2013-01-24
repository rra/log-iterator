#!/usr/bin/perl
#
# Some basic sanity checks of examples/webkdc-user-agent.
#
# This isn't a comprehensive test suite.  The example is mostly checked with
# real log files.  It just runs it on some basic input data and exercises
# simple functionality to ensure that nothing is horribly broken.
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

use Test::More;

# Check if we have the modules required to run webkdc-user-agent.
if (!eval { require File::Slurp }) {
    plan skip_all => 'HTTP::BrowserDetect required for test';
}
if (!eval { require HTTP::BrowserDetect }) {
    plan skip_all => 'HTTP::BrowserDetect required for test';
}
if (!eval { require Test::Script::Run }) {
    plan skip_all => 'Test::Script::Run required for test';

    # Suppress "only used once" warnings.
    @Test::Script::Run::BIN_DIRS = ();
}
File::Slurp->import;
Test::Script::Run->import;

# It's now safe to present a plan.
plan tests => 2;

# Our script is found in the examples directory.
local @Test::Script::Run::BIN_DIRS = qw(examples);

# Generate the paths to our test files.
my $webkdc = File::Spec->catfile(qw(t data samples webkdc));
if (!-r $webkdc) {
    BAIL_OUT("cannot find test data: $webkdc");
}
my $access = File::Spec->catfile(qw(t data samples apache));

# Test CSV output.
my $csv_output = File::Spec->catfile(qw(t data output webkdc-user-agent.csv));
my @expected   = read_file($csv_output);
chomp @expected;
run_output_matches('webkdc-user-agent', ['-c', $webkdc, $access],
    [@expected], q{}, 'webkdc-user-agent -c');

# Test the report.
my $report = File::Spec->catfile(qw(t data output webkdc-user-agent));
@expected = read_file($report);
chomp @expected;
run_output_matches('webkdc-user-agent', [$webkdc, $access],
    [@expected], q{}, 'webkdc-user-agent report');
