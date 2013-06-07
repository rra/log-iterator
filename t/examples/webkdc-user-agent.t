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

use lib 't/lib';

use Test::More;
use Test::RRA qw(use_prereq);

# Load required modules or modules that are used by webkdc-user-agent.
use_prereq('File::Slurp', qw(read_file));
use_prereq('HTTP::BrowserDetect');
use_prereq('List::MoreUtils');
use_prereq('Memoize');
use_prereq('Text::CSV');
use_prereq('Test::Script::Run', qw(run_output_matches));

# It's now safe to present a plan.
plan tests => 3;

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

# Test reporting using the CSV file as input.
run_output_matches('webkdc-user-agent', ['-i', $csv_output],
    [@expected], q{}, 'webkdc-user-agent report -i');

# Suppress "only used once" warnings.
END { @Test::Script::Run::BIN_DIRS = () }
