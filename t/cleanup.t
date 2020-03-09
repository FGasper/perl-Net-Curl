#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use Test::More;

use File::Spec;

my $end42_path = File::Spec->catfile( $FindBin::Bin, 'assets', 'end_42_on_die.pl' );

system $^X, $end42_path;

if ($? != (42 << 8)) {
    require Config;
    plan skip_all => "This perl ($Config::Config{'version'}) doesn’t appear to set exit value from \$? in END. (CHILD_ERROR=$?)\n";
}

plan tests => 2;

my @inc_args = map { ('-I', $_) } @INC;

{
    my $add_throw_path = File::Spec->catfile( $FindBin::Bin, 'assets', 'add_then_throw.pl' );
    system $^X, @inc_args, $add_throw_path;

    is( $?, (42 << 8), 'multi: exception did not cause segfault' );
}

{
    my $add_throw_path = File::Spec->catfile( $FindBin::Bin, 'assets', 'add_share_then_throw.pl' );
    system $^X, @inc_args, $add_throw_path;

    is( $?, (42 << 8), 'share: exception did not cause segfault' );
}
