use strict;
use warnings;

use Test::More;
use Net::Curl::Easy;

my $easy = Net::Curl::Easy->new();

my $tests = [
	["", ""],
	["\0", "%00"],
	["foo\0bar", "foo%00bar"],
	["тестовое сообщение", "%D1%82%D0%B5%D1%81%D1%82%D0%BE%D0%B2%D0%BE%D0%B5%20%D1%81%D0%BE%D0%BE%D0%B1%D1%89%D0%B5%D0%BD%D0%B8%D0%B5"],
	["~`!@#\$%^&*()-_=+{}[];:'\"<>,./?\\|\n\r\t", "~%60%21%40%23%24%25%5E%26%2A%28%29-_%3D%2B%7B%7D%5B%5D%3B%3A%27%22%3C%3E%2C.%2F%3F%5C%7C%0A%0D%09"],
];

plan tests => @$tests * 2;

for my $test(@$tests) {
	my ($raw, $escaped) = @$test;

	my $just_escaped = $easy->escape($raw);
	ok($just_escaped eq $escaped, "escape '$just_escaped' eq '$escaped'");

	my $just_unescaped = $easy->unescape($escaped);
	ok($just_unescaped eq $raw, "unescape '$just_unescaped' eq '$raw'");
}
