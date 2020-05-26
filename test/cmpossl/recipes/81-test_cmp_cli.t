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
use OpenSSL::Test qw/:DEFAULT with data_file data_dir bldtop_dir/;
use OpenSSL::Test::Utils;
use Data::Dumper; # for debugging purposes only

setup("test_cmp_cli");

plan skip_all => "This test is not supported in a no-cmp build"
    if disabled("cmp");

sub chop_dblquot { # chop any leading & trailing '"' (needed for Windows)
    my $str = shift;
    $str =~ s/^\"(.*?)\"$/$1/;
    return $str;
}

my $proxy = "<EMPTY>";
$proxy = chop_dblquot($ENV{http_proxy} // $ENV{HTTP_PROXY} // $proxy);
$proxy =~ s{^https?://}{}i;
my $no_proxy = $ENV{no_proxy} // $ENV{NO_PROXY};

my $app = "cmpClient";
my $test_config = "test_config.cnf";

my @cmp_basic_tests = (
    [ "show help",                        [ "-help"                                        ], 0 ],
    [ "unknown CLI option",               [ "-config", $test_config, "-asdffdsa"           ], 1 ],
    [ "CLI option not starting with '-'", [ "-config", $test_config, "days", "1"           ], 1 ],
    [ "bad int syntax: non-digit",        [ "-config", $test_config, "-days", "a/"         ], 1 ],
    [ "bad int syntax: float",            [ "-config", $test_config, "-days", "3.14"       ], 1 ],
    [ "bad int syntax: trailing garbage", [ "-config", $test_config, "-days", "314_+"      ], 1 ],
    [ "bad int: out of range",            [ "-config", $test_config, "-days", "2147483648" ], 1 ],
);

# the CMP server configuration consists of:
                # The CA name (implies directoy with certs etc. and CA-specific section in config file)
my $ca_dn;      # The CA's Distinguished Name
my $server_dn;  # The server's Distinguished Name
my $server_cn;  # The server's domain name
my $server_ip;  # The server's IP address
my $server_port;# The server's port
my $server_tls; # The server's TLS port, if any, or 0
my $server_cert;# The server's cert
my $secret;     # The secret for PBM
my $column;     # The column number of the expected result
my $sleep = 0;  # The time to sleep between two requests

sub load_server_config {
    my $name = shift; # name of section to load
    open (CH, $test_config) or die "Connot open $test_config: $!";
    my $active = 0;
    while (<CH>) {
        if (m/\[\s*$name\s*\]/) {
            $active = 1;
        } elsif (m/\[\s*.*?\s*\]/) {
            $active = 0;
        } elsif ($active) {
            $ca_dn       = $1 eq "" ? '""""' : $1 if m/^\s*ca_dn\s*=\s*(.*)?\s*$/;
            $server_dn   = $1 eq "" ? '""""' : $1 if m/^\s*server_dn\s*=\s*(.*)?\s*$/;
            $server_cn   = $1 eq "" ? '""""' : $1 if m/^\s*server_cn\s*=\s*(.*)?\s*$/;
            $server_ip   = $1 eq "" ? '""""' : $1 if m/^\s*server_ip\s*=\s*(.*)?\s*$/;
            $server_port = $1 eq "" ? '""""' : $1 if m/^\s*server_port\s*=\s*(.*)?\s*$/;
            $server_tls  = $1 eq "" ? '""""' : $1 if m/^\s*server_tls\s*=\s*(.*)?\s*$/;
            $server_cert = $1 eq "" ? '""""' : $1 if m/^\s*server_cert\s*=\s*(.*)?\s*$/;
            $secret      = $1 eq "" ? '""""' : $1 if m/^\s*pbm_secret\s*=\s*(.*)?\s*$/;
            $column      = $1 eq "" ? '""""' : $1 if m/^\s*column\s*=\s*(.*)?\s*$/;
            $sleep       = $1 eq "" ? '""""' : $1 if m/^\s*sleep\s*=\s*(.*)?\s*$/;
        }
    }
    close CH;
    die "Cannot find all CMP server config values in $test_config section [$name]\n"
        if !defined $ca_dn || !defined $server_cn || !defined $server_ip
        || !defined $server_port || !defined $server_tls || !defined $server_cert
        || !defined $secret || !defined $column || !defined $sleep;
    $server_dn = $server_dn // $ca_dn;
}

my @server_configurations = (); # ("EJBCA", "Insta", "SimpleLra");
@server_configurations = split /\s+/, $ENV{CMP_TESTS} if $ENV{CMP_TESTS};
# set env variable, e.g., CMP_TESTS="EJBCA Insta" to include certain CAs

my @all_aspects = ("connection", "verification", "credentials", "commands", "enrollment", "certstatus");
@all_aspects = split /\s+/, $ENV{CMP_ASPECTS} if $ENV{CMP_ASPECTS};
# set env variable, e.g., CMP_ASPECTS="commands enrollment" to select specific aspects

my $faillog;
if ($ENV{HARNESS_FAILLOG}) {
    my $file = $ENV{HARNESS_FAILLOG};
    open($faillog, ">", $file) or die "Cannot open $file for writing: $!";
}

sub test_cmp_cli {
    my $name = shift;
    my $aspect = shift;
    my $n = shift;
    my $i = shift;
    my $title = shift;
    my $params = shift;
    my $expected_exit = shift;
    my $path_app = bldtop_dir($app);
    with({ exit_checker => sub {
        my $actual_exit = shift;
        my $OK = $actual_exit == $expected_exit;
        if ($faillog && !$OK) {
            my $invocation = ("$path_app ").join(' ', map { $_ eq "" ? '""' : $_ =~ m/ / ? '"'.$_.'"' : $_ } @$params);
            print $faillog "$name $aspect \"$title\" ($i/$n) expected=$expected_exit actual=$actual_exit\n";
            print $faillog "$invocation\n\n";
        }
        return $OK; } },
         sub { ok(run(cmd([$path_app, @$params,])),
                  $title); });
}

sub test_cmp_cli_aspect {
    my $name = shift;
    my $aspect = shift;
    my $tests = shift;
    subtest "CMP app CLI $name $aspect\n" => sub {
        my $n = scalar @$tests;
        plan tests => $n;
        my $i = 1;
        foreach (@$tests) {
          SKIP: {
              test_cmp_cli($name, $aspect, $n, $i++, $$_[0], $$_[1], $$_[2]);
              sleep($sleep);
            }
        }
    };
}

indir "../cmpossl/test/recipes/81-test_cmp_cli_data" => sub {
    plan tests => 1 + @server_configurations * @all_aspects;

    test_cmp_cli_aspect("basic", "options", \@cmp_basic_tests);

    # TODO: complete and thoroughly review _all_ of the around 500 test cases
    foreach my $server_name (@server_configurations) {
        $server_name = chop_dblquot($server_name);
        load_server_config($server_name);
        foreach my $aspect (@all_aspects) {
            $aspect = chop_dblquot($aspect);
            if (not($server_name =~ m/Insta/)) { # do not update aspect-specific settings for Insta
            load_server_config($aspect); # update with any aspect-specific settings
            }
            indir $server_name => sub {
                my $tests = load_tests($server_name, $aspect);
                test_cmp_cli_aspect($server_name, $aspect, $tests);
            };
        };
    };
};

close($faillog) if $faillog;

sub load_tests {
    my $name = shift;
    my $aspect = shift;
    my $file = data_file("test_$aspect.csv");
    my @result;

    open(my $data, '<', $file) || die "Cannot open $file for reading: $!";
  LOOP:
    while (my $line = <$data>) {
        chomp $line;
        $line =~ s{\r\n}{\n}g; # adjust line endings
        $line =~ s{_CA_DN}{$ca_dn}g;
        $line =~ s{_SERVER_DN}{$server_dn}g;
        $line =~ s{_SERVER_CN}{$server_cn}g;
        $line =~ s{_SERVER_IP}{$server_ip}g;
        $line =~ s{_SERVER_PORT}{$server_port}g;
        $line =~ s{_SERVER_TLS}{$server_tls}g;
        $line =~ s{_SERVER_CERT}{$server_cert}g;
        $line =~ s{_SECRET}{$secret}g;
        my $noproxy = $line =~ m/,\s*-no_proxy\s*,(.*?)(,|$)/ ? $1 : $no_proxy;
        next LOOP if $no_proxy && ($noproxy =~ $server_cn || $noproxy =~ $server_ip) && $line =~ m/,\s*-proxy\s*,/;
        $line =~ s{-section,,}{-section,,-proxy,$proxy,} unless $line =~ m/,\s*-proxy\s*,/;
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
    close($data);
    return \@result;
}
