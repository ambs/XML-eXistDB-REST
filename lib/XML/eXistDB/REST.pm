# ABSTRACT: turns baubles into trinkets
package XML::eXistDB::REST;
use strict;
use warnings;

use XML::eXistDB::REST::Collection;

no warnings 'experimental::signatures';
use feature qw.signatures.;

use URI::Encode qw(uri_encode uri_decode);
use HTTP::Tiny;
use XML::DT;

sub new ($class, %options) {
	my $http = HTTP::Tiny->new();
	my $self = bless { http => $http, debug => 1 }, $class;

	$options{server} = $ENV{EXISTDB_REST_SERVER} 
		if not $options{server} and $ENV{EXISTDB_REST_SERVER};
	$options{user} = $ENV{EXISTDB_REST_USER} 
		if not $options{user} and $ENV{EXISTDB_REST_USER};
	$options{password} = $ENV{EXISTDB_REST_PASSWORD} 
		if not $options{password} and $ENV{EXISTDB_REST_PASSWORD};

	my $server = $options{server} || "localhost:8080";
	if ( $server !~ m!^http://! ) {
		if (exists($options{password}) && exists($options{user})) {
			$server = sprintf 'http://%s:%s@%s',
				uri_encode($options{user}),
				uri_encode($options{password}),
				$server;
		}
	}
	
	$server  .= '/exist/rest' unless $server =~ m!exist/rest!;
	$self->{server} = $server;

	$self->{debug} = $options{debug} if exists $options{debug};
		
	return $self;
}

sub delete ($self, $collection, $resource = undef) {
	$resource = $resource ? join("/", $collection, $resource) : $collection;
	$resource = "/$resource" unless $resource =~ m!^/!;
	$resource = uri_encode $resource;

	my %params;
	$params{session} = $self->{session} if defined($self->{session});

	my $query = $self->_construct_query($resource, %params);
	print STDERR "PUT [$query]\n" if $self->{debug};
	
	my $answer = $self->{http}->delete($query);
	$self->_assert_success($answer);
	$self->_collect_cookies($answer);
	
	# return $answer->{content};
}

sub put ($self, $contents, $collection, $resource = undef) {
	$resource = $resource ? join("/", $collection, $resource) : $collection;
	$resource = "/$resource" unless $resource =~ m!^/!;
	$resource = uri_encode $resource;

	my %params;
	$params{session} = $self->{session} if defined($self->{session});

	my $query = $self->_construct_query($resource, %params);
	print STDERR "PUT [$query]\n" if $self->{debug};
	
	my $answer = $self->{http}->put($query, {
		headers => { "content-type" => "application/xml" },
		content => $contents
	});
	$self->_assert_success($answer);
	$self->_collect_cookies($answer);
	
	# return $answer->{content};
}

sub get ($self, $collection, %options) {
	$collection = "/$collection" unless $collection =~ m!^/!;
	$collection = uri_encode $collection;

	my %params = (cache => "yes");
	$params{session} = $self->{session} if defined($self->{session});
	# wrap ...?
	for my $param (qw.xsl query indent encoding howmany start.) {
		$params{$param} = $options{$param} if exists $options{$param}
	}

	my $query = $self->_construct_query($collection, %params);
	print STDERR "GET [$query]\n" if $self->{debug};
	my $answer = $self->{http}->get($query);

	$self->_assert_success($answer);
	$self->_collect_cookies($answer);
	
	return 
		_is_collection($answer->{content})
		?
		bless(_parse_collection($self, $answer->{content}), "XML::eXistDB::REST::Collection")
		:
		$answer->{content};
}

sub _construct_query($self, $collection, %params) {
	my $query = "$self->{server}$collection";
	if (%params) {
		$query .= "?" . join("&", map {"_$_=".uri_encode($params{$_})} keys %params);
	}
	return $query;
}

sub _assert_success($self, $answer) {
	unless ($answer->{success}) {
		print STDERR $answer->{content};
		die "ERROR $answer->{status}: $answer->{reason}" 
	}
}

sub _collect_cookies($self, $answer) {
	## hack to get sessionid -- use a cookie monster.. module, to help with this?
	my %cookies = map { (split /=/) } split /;/, $answer->{'headers'}{'set-cookie'};
	$self->{session} = $cookies{JSESSIONID} || undef;
}

sub _is_collection($item) { $item =~ /<exist:collection/ }

sub _parse_collection ($self, $document) {
	my %handler = (
		-default => sub { $c },
		-type => {
			'exist:result' => 'THE_CHILD',
			'exist:collection' => 'SEQ'
		},
	    'exist:value'      => sub { +{ %v, type => $q, value => $c } },
	    'exist:resource'   => sub { +{ %v, type => $q } },
	    'exist:collection' => sub { +{ %v, type => $q, $c ? (contents => _array_to_hash($c)) : () } });
	return { rest => $self, collection => dtstring($document => %handler) }
}

sub _array_to_hash ($array) {
	my $hash;
	foreach my $elem ($array->@*) {
		$hash->{$elem->{name}} = $elem;
	}
	return $hash;
}

1;
