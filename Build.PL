#!/usr/bin/perl
#
# Build script for Log::Stream distribution.
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

use Module::Build;

# Basic package configuration.
my $build = Module::Build->new(
    module_name          => 'Log::Stream',
    dist_abstract        => 'Stream-based log reading and parsing system',
    dist_author          => 'Russ Allbery <rra@stanford.edu>',
    license              => 'mit',
    recursive_test_files => 1,
    create_makefile_pl   => 'traditional',

    # Other package relationships.
    configure_requires => { 'Module::Build' => 0.28 },
    requires           => {
        'Readonly' => 0,
        perl       => '5.010',
    },
);

# Generate the build script.
$build->create_build_script;
