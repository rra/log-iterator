#!/usr/bin/perl
#
# Check for perlcritic errors in all code.
#
# Checks all Perl code in blib/lib, t, and Makefile.PL for problems uncovered
# by perlcritic.  This test is disabled unless RRA_MAINTAINER_TESTS is set,
# since coding style will not interfere with functionality and newer versions
# of perlcritic may introduce new checks.
#
# Written by Russ Allbery <rra@cpan.org>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

use 5.006;
use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::RRA qw(skip_unless_maintainer use_prereq);
use Test::RRA::Config qw(@CRITIC_IGNORE);

# Skip tests unless we're running the test suite in maintainer mode.
skip_unless_maintainer('Coding style tests');

# Load prerequisite modules.
use_prereq('Perl::Critic::Utils');
use_prereq('Test::Perl::Critic');

# Force the embedded Perl::Tidy check to use the correct configuration.
local $ENV{PERLTIDY} = 't/data/perltidyrc';

# Import the configuration file and run Perl::Critic.
Test::Perl::Critic->import(-profile => 't/data/perlcriticrc');

# By default, Test::Perl::Critic only checks blib.  We also want to check t,
# Build.PL, and examples.
my @files = Perl::Critic::Utils::all_perl_files('blib');
if (!@files) {
    @files = Perl::Critic::Utils::all_perl_files('lib');
}
push(@files, Perl::Critic::Utils::all_perl_files('t'));
push(@files, 'Build.PL');
if (-d 'examples') {
    push(@files, Perl::Critic::Utils::all_perl_files('examples'));
}

# Strip out Autoconf templates or left-over perltidy files.
@files = grep { !m{ [.](?:in|tdy) }xms } @files;

# Strip out ignored files.
my %ignore = map { $_ => 1 } @CRITIC_IGNORE;
@files = grep { !$ignore{$_} } @files;

# Declare a plan now that we know what we're testing.
plan tests => scalar @files;

# Run the actual tests.
for my $file (@files) {
    critic_ok($file);
}
