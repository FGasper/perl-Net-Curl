#!/usr/bin/perl

use strict;
use warnings;

use Net::Curl::Share;
use Net::Curl::Easy qw(:constants);

my $share = Net::Curl::Share->new();

my $handle = Net::Curl::Easy->new();

$handle->setopt(CURLOPT_SHARE() => $share);

close *STDERR;

die "ohno";

END {
    $? = 42;
}
