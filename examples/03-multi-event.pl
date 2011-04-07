=head1 Multi::Event

This module shows how to use WWW::CurlOO::Multi interface with an event
library, AnyEvent in this case.

=head2 Problems

AnyEvent does not allow registering io callbacks for both reading and writing,
but it rarely is useful.

=head2 Motivation

This is the most efficient method for using WWW::CurlOO::Multi interface,
but it requires a really good understanding of it. This code tries to show
the quirks found when using event-based programming.

=head2 MODULE CODE

=cut
package Multi::Event;

use strict;
use warnings;
use AnyEvent;
use WWW::CurlOO::Multi qw(/^CURL_POLL_/ /^CURL_CSELECT_/);
use base qw(WWW::CurlOO::Multi);

# XXX: remove
my $multi;

sub new
{
	my $class = shift;

	# no base object, we'll use the default hash
	#my
	$multi = $class->SUPER::new();
	$multi->setopt( WWW::CurlOO::Multi::CURLMOPT_SOCKETFUNCTION,
		\&_cb_socket );
	$multi->setopt( WWW::CurlOO::Multi::CURLMOPT_TIMERFUNCTION,
		\&_cb_timer );

	$multi->{active} = -1;

	return $multi;
}

sub _cb_socket
{
	my ( $easy, $socket, $poll ) = @_;
	#warn "on_socket( $socket => $poll )\n";

	# socket callback receives the $easy handle as first argument.
	# Right now $socket belongs to that $easy, but it can be
	# shared with another easy handle if server supports persistent
	# connections.
	# This is why we register socket events inside multi object
	# and not $easy.

	# XXX: this is missing yet
	#my $multi = $easy->multi;

	# deregister old io events
	delete $multi->{ "r$socket" };
	delete $multi->{ "w$socket" };

	# AnyEvent does not support registering a socket for both reading and
	# writing. This is rarely used so there is no harm in separating
	# the events.

	# register read event
	if ( $poll == CURL_POLL_IN or $poll == CURL_POLL_INOUT ) {
		$multi->{ "r$socket" } = AE::io $socket, 0, sub {
			$multi->socket_action( $socket, CURL_CSELECT_IN );
		};
	}

	# register write event
	if ( $poll == CURL_POLL_OUT or $poll == CURL_POLL_INOUT ) {
		$multi->{ "w$socket" } = AE::io $socket, 1, sub {
			$multi->socket_action( $socket, CURL_CSELECT_OUT );
		};
	}

	return 1;
}

sub _cb_timer
{
	my ( $multi, $timeout_ms ) = @_;
	#warn "on_timer( $timeout_ms )\n";

	# deregister old timer
	delete $multi->{timer};

	my $cb = sub {
		$multi->socket_action( WWW::CurlOO::Multi::CURL_SOCKET_TIMEOUT );
	};

	if ( $timeout_ms < 0 ) {
		# Negative timeout means there is no timeout at all. Normally happens
		# if there are no handles anymore.
		#
		# However, curl_multi_timeout(3) says:
		#
		# Note: if libcurl returns a -1 timeout here, it just means that
		# libcurl currently has no stored timeout value. You must not wait
		# too long (more than a few seconds perhaps) before you call
		# curl_multi_perform() again.

		# XXX: this is missing yet
		#if ( $multi->handles ) {
			$multi->{timer} = AE::timer 10, 10, $cb;
		#}
	} else {
		$multi->{timer} = AE::timer $timeout_ms / 1000, 0, $cb;
	}

	return 1;
}

# add one handle and kickstart download
sub add_handle($$)
{
	my $multi = shift;
	my $easy = shift;

	die "easy cannot finish()\n"
		unless $easy->can( 'finish' );

	# calling socket_action with default arguments will trigger socket callback
	# and register io
	#
	# It _must_ be called after add_handle(), AE will take care of that.
	#
	# We are delaying the call because in some cases socket_action may finish
	# inmediatelly (i.e. there was some error or we used persistent connections
	# and server returned data right away) and it could confuse our
	# application.
	AE::timer 0, 0, sub {
		$multi->socket_action();
	};

	$multi->SUPER::add_handle( $easy );
}

# perform and call any callbacks that have finished
sub socket_action
{
	my $multi = shift;

	my $active = $multi->SUPER::socket_action( @_ );
	return if $multi->{active} == $active;

	$multi->{active} = $active;

	while ( my ( $easy, $result ) = $multi->info_read() ) {
		#if ( $msg == CURLMSG_DONE ) {
		$multi->remove_handle( $easy );
		$easy->finish( $result );
		#}
	}
}

1;

=head2 TEST Easy package

Multi::Event requires Easy object to provide finish() method.

=cut
package Easy::Event;
use strict;
use warnings;
use WWW::CurlOO::Easy;
use base qw(WWW::CurlOO::Easy);

sub new
{
	my $class = shift;
	my $uri = shift;
	my $cb = shift;

	my $easy = $class->SUPER::new( { uri => $uri, body => '', cb => $cb } );
	$easy->setopt( WWW::CurlOO::Easy::CURLOPT_URL(), $uri );
	$easy->setopt( WWW::CurlOO::Easy::CURLOPT_WRITEHEADER(), \$easy->{headers} );
	$easy->setopt( WWW::CurlOO::Easy::CURLOPT_FILE(), \$easy->{body} );

	return $easy;
}

sub finish
{
	my ( $easy, $result ) = @_;

	printf "\nFinished downloading %s: %s: %d bytes\n", 
		$easy->{uri}, $result, length $easy->{body};

	$easy->{cb}->( $easy->{body} );
}

1;

=head2 TEST APPLICATION

	#!perl
	use strict;
	use warnings;
	use Easy::Event;
	use Multi::Event;
#nopod
=cut
package main;
#endnopod
use AnyEvent;

my $multie = Multi::Event->new();
my $cv = AE::cv;


my @uris = (
	"http://www.google.com/search?q=perl",
	"http://www.google.com/search?q=curl",
	"http://www.google.com/search?q=perl+curl",
);


my $i = scalar @uris;
sub done
{
	my $body = shift;

	# process...
	
	unless ( --$i ) {
		$cv->send;
	}
}

my $timer;
$timer = AE::timer 0, 0.1, sub {
	my $uri = shift @uris;
	$multie->add_handle( Easy::Event->new( $uri, \&done ) );

	unless ( @uris ) {
		undef $timer;
	}
};

$cv->recv;

exit 0;
#nopod
# vim: ts=4:sw=4
