#!/usr/bin/perl
#
# Test that all methods are documented in POD.
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University
#
# See LICENSE for licensing terms.

use strict;
use warnings;

use Test::More;

# Additional regexes for subs that don't require POD documentation.
my @NO_POD_NEEDED = (qr{ \A (?:LOCAL|POP|PUSH)COLOR \z}xms);

# Skip tests if Test::Pod::Coverage is not installed.
if (!eval { require Test::Pod::Coverage }) {
    plan skip_all => 'Test::Pod::Coverage required to test POD coverage';
}
Test::Pod::Coverage->import;

# Test everything found in the distribution.  Ignore some subs that implement
# the keyword interface; they are documented, just in a way that Pod::Coverage
# doesn't understand.
all_pod_coverage_ok({ also_private => [@NO_POD_NEEDED] });
