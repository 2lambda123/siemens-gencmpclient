#! /usr/bin/env perl
# Copyright 2007-2019 The OpenSSL Project Authors. All Rights Reserved.
# Copyright Nokia 2007-2019
# Copyright Siemens AG 2015-2019
#
# Licensed under the Apache License 2.0 (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html

use lib "cmpossl/util/perl";

use strict;
use warnings;

use POSIX;
use OpenSSL::Test qw/:DEFAULT with data_file data_dir/;
use OpenSSL::Test::Utils;
use Data::Dumper; # for debugging purposes only

setup("test_cmp_cli");

plan skip_all => "This test is not supported in a no-cmp build"
    if disabled("cmp");

my $proxy = "<EMPTY>";
$proxy = $ENV{http_proxy} // $ENV{HTTP_PROXY} // $proxy;
$proxy =~ s/^\"(.*?)\"$/$1/; # chop any leading/trailing '"' (for Windows)
$proxy =~ s{http://}{};
my $no_proxy = $ENV{no_proxy} // $ENV{NO_PROXY};

my $test_config = "test_config.cnf";

my @cmp_basic_tests = (
    [ "output help",                      [ "-help"], 0 ],
    [ "unknown CLI parameter",            [ "-config", $test_config, "-asdffdsa"], 1 ],
    [ "bad int syntax: non-digit",        [ "-config", $test_config, "-msg_timeout", "a/" ], 1 ],
    [ "bad int syntax: float",            [ "-config", $test_config, "-msg_timeout", "3.14" ], 1 ],
    [ "bad int syntax: trailing garbage", [ "-config", $test_config, "-msg_timeout", "314_+" ], 1 ],
    [ "bad int: out of range",            [ "-config", $test_config, "-msg_timeout", "2147483648" ], 1 ],
);

# the CA server configuration consists of:
                # The CA name (implies directoy with certs etc. and CA-specific section in config file)
my $ca_dn;      # The CA's Distinguished Name
my $server_dn;  # The server's Distinguished Name
my $server_cn;  # The server's domain name
my $server_ip;  # The server's IP address
my $server_port;# The server's port
my $server_cert;# The server's cert
my $secret;     # The secret for PBM
my $column;     # The column number of the expected result
my $sleep = 0;  # The time to sleep between two requests

sub load_config {
    my $name = shift;
    my $write_new = shift;
    open (CH, $test_config) or die "Can't open $test_config: $!";
    if ($write_new) {
        $ca_dn = undef;
        $server_dn = undef;
        $server_cn = undef;
        $server_ip = undef;
        $server_port = undef;
        $server_cert = undef;
        $secret = undef;
        $column = undef;
        $sleep = undef;
    }
    my $active = 0;
    while (<CH>) {
        if (m/\[\s*$name\s*\]/) {
            $active = 1;
            } elsif (m/\[\s*.*?\s*\]/) {
                $active = 0;
        } elsif ($active) {
            $ca_dn = $1 if m/\s*recipient\s*=\s*(.*)?\s*$/;
            $server_dn = $1 if m/\s*ra\s*=\s*(.*)?\s*$/;
            $server_cn = $1 if m/\s*server_cn\s*=\s*(.*)?\s*$/;
            $server_ip = $1 if m/\s*server_ip\s*=\s*(.*)?\s*$/;
            $server_port = $1 if m/\s*server_port\s*=\s*(.*)?\s*$/;
            $server_cert = $1 if m/\s*server_cert\s*=\s*(.*)?\s*$/;
            $secret = $1 if m/\s*pbm_secret\s*=\s*(.*)?\s*$/;
            $column = $1 if m/\s*column\s*=\s*(.*)?\s*$/;
                $sleep = $1 if m/\s*sleep\s*=\s*(.*)?\s*$/;
        }
    }
    close CH;
    die "Can't find all CA config values in $test_config section [$name]\n"
        if !defined $ca_dn || !defined $server_cn || !defined $server_ip || !defined $server_port ||
           !defined $server_cert || !defined $secret || !defined $column || !defined $sleep;
    $server_dn = $server_dn // $ca_dn;
}

my @ca_configurations = (); # ("EJBCA", "Insta", "SimpleLra");
@ca_configurations = split /\s+/, $ENV{CMP_TESTS} if $ENV{CMP_TESTS};
# set env variable, e.g., CMP_TESTS="EJBCA Insta" to include certain CAs

my @all_aspects = ("connection", "verification", "credentials", "commands", "enrollment", "certstatus");
@all_aspects = split /\s+/, $ENV{CMP_ASPECTS} if $ENV{CMP_ASPECTS};
# set env variable, e.g., CMP_ASPECTS="commands" to select specific aspects

sub test_cmp_cli {
    my @args = @_;
    my $name = shift;
    my $title = shift;
    my $params = shift;
    my $expected_exit = shift;
    with({ exit_checker => sub {
        my $OK = shift == $expected_exit;
        print Dumper @args if!($OK); # TODO: for debugging purposes only
        return $OK; } },
         sub { ok(run(app(["cmpClient", @$params,])),
                  $title); });
}

sub test_cmp_cli_aspect {
    my $name = shift;
    my $aspect = shift;
    my $tests = shift;
    subtest "CMP app CLI $name $aspect\n" => sub {
        plan tests => scalar @$tests;
        foreach (@$tests) {
          SKIP: {
              test_cmp_cli($name, $$_[0], $$_[1], $$_[2]);
              sleep($sleep);
            }
        }
    };
}

indir "../cmpossl/test/recipes/81-test_cmp_cli_data" => sub {
    plan tests => 1 + @ca_configurations * @all_aspects;

    test_cmp_cli_aspect("basic", "", \@cmp_basic_tests);

    # TODO: complete and thoroughly review _all_ of the around 500 test cases
    foreach my $name (@ca_configurations) {
        $name =~ s/^\"(.*?)\"$/$1/; # chop any leading/trailing '"' (for Win)
        load_config($name,1);
        foreach my $aspect (@all_aspects) {
            $aspect =~ s/^\"(.*?)\"$/$1/; # chop any leading/trailing '"'
            if (not($name =~ m/Insta/)) { # overwrite CA server configuration with settings defined in aspect section if it is not Insta
                load_config($aspect,0);
            }
        }
        indir $name => sub {
            foreach my $aspect (@all_aspects) {
                $aspect =~ s/^\"(.*?)\"$/$1/; # chop any leading/trailing '"'
                my $tests = load_tests($name, $aspect);
                test_cmp_cli_aspect($name, $aspect, $tests);
            };
        };
    };
};

sub load_tests {
    my $name = shift;
    my $aspect = shift;
    my $file = data_file("test_$aspect.csv");
    my @result;

    open(my $data, '<', $file) || die "Cannot load $file\n";
  LOOP:
    while (my $line = <$data>) {
        chomp $line;
        #next LOOP if ($line =~ m/tls_/i); # skip tests requiring TLS
        $line =~ s{\r\n}{\n}g; # adjust line endings
        $line =~ s{_CA_DN}{$ca_dn}g;
        $line =~ s{_SERVER_DN}{$server_dn}g;
        $line =~ s{_SERVER_CN}{$server_cn}g;
        $line =~ s{_SERVER_IP}{$server_ip}g;
        $line =~ s{_SERVER_PORT}{$server_port}g;
        $line =~ s{_SRVCERT}{$server_cert}g;
        $line =~ s{_SECRET}{$secret}g;
        next LOOP if $no_proxy && $no_proxy =~ $server_cn && $line =~ m/,-proxy,/;
        $line =~ s{-section,,}{-section,,-proxy,$proxy,} unless $line =~ m/,-proxy,/;
        $line =~ s{-section,,}{-config,../$test_config,-section,$name $aspect,};
        my @fields = grep /\S/, split ",", $line;
        s/^<EMPTY>$// for (@fields); # used for proxy=""
        s/^\s+// for (@fields); # remove leading  whitepace from elements
        s/\s+$// for (@fields); # remove trailing whitepace from elements
        s/^\"(\".*?\")\"$/$1/ for (@fields); # remove escaping from quotation marks from elements
        my $expected_exit = $fields[$column];
        my $title = $fields[2];
        next LOOP if (!defined($expected_exit) or ($expected_exit ne 0 and $expected_exit ne 1));
        @fields = grep {$_ ne 'BLANK'} @fields[3..@fields-1];
        push @result, [$title, \@fields, $expected_exit];
    }
    return \@result;
}