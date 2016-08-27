# ABSTRACT: turns baubles into trinkets
package XML::eXistDB::REST::Collection;

use warnings;
use strict;        

no warnings 'experimental::signatures';
use feature qw.signatures.;

sub contains($self, $resource) {
	$resource = $self->_norm($resource);

	return exists($self->{collection}{contents}{$resource});
}

sub get($self, $resource) {
	$resource = $self->_norm($resource);
	return $self->{rest}->get(join("/", $self->{collection}{name} , $resource));
}

sub delete($self, $resource) {
	$self->{rest}->delete($self->{collection}{name}, $resource );

	$self->{collection} = $self->{rest}->get($self->{collection}{name})->{collection};
}

sub put($self, $content, $resource) {
	$self->{rest}->put($content, $self->{collection}{name}, $resource );

	$self->{collection} = $self->{rest}->get($self->{collection}{name})->{collection};
}

sub _norm ($self, $resource) {
	$resource =~ s!^$self->{collection}{name}!!g;
	$resource =~ s!^/|/$!!g;
	return $resource;
}

1;
