#!/usr/bin/perl
#
# Check the SYNOPSIS section of the documentation for syntax errors.
#
# The canonical version of this file is maintained in the rra-c-util package,
# which can be found at <http://www.eyrie.org/~eagle/software/rra-c-util/>.
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
use Test::RRA qw(use_prereq);

use_prereq('Perl::Critic::Utils');
use_prereq('Test::Synopsis');

# The default Test::Synopsis all_synopsis_ok() function requires that the
# module be in a lib directory.  Use Perl::Critic::Utils to find the modules
# in blib, or lib if it doesn't exist.
my @files = Perl::Critic::Utils::all_perl_files('blib');
if (!@files) {
    @files = Perl::Critic::Utils::all_perl_files('lib');
}
plan tests => scalar @files;

# Run the actual tests.
for my $file (@files) {
    synopsis_ok($file);
}
