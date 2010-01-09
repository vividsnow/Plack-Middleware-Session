package Plack::Session;
use strict;
use warnings;

our $VERSION   = '0.03';
our $AUTHORITY = 'cpan:STEVAN';

use Plack::Util::Accessor qw( id expired _manager );

sub fetch_or_create {
    my($class, $request, $manager) = @_;

    my($id, $session);
    if ($id = $manager->state->extract($request) and
        $session = $manager->store->fetch($id)) {
        return $class->new( id => $id, _stash => $session, _manager => $manager, _changed => 0 );
    } else {
        $id = $manager->state->generate($request);
        return $class->new( id => $id, _stash => {}, _manager => $manager, _changed=> 1 );
    }
}

sub new {
    my ($class, %params) = @_;
    bless { %params } => $class;
}

## Data Managment

sub dump {
    my $self = shift;
    $self->{_stash};
}

sub get {
    my ($self, $key) = @_;
    $self->{_stash}{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{_changed}++;
    $self->{_stash}{$key} = $value;
}

sub remove {
    my ($self, $key) = @_;
    $self->{_changed}++;
    delete $self->{_stash}{$key};
}

sub keys {
    my $self = shift;
    keys %{$self->{_stash}};
}

## Lifecycle Management

sub expire {
    my $self = shift;
    $self->{_stash} = {};
    $self->expired(1);
}

sub commit {
    my $self = shift;

    if ($self->expired) {
        $self->_manager->store->cleanup($self->id);
    } else {
        $self->_manager->store->store($self->id, $self);
    }

    $self->{_changed} = 0;
}

sub is_changed {
    my $self = shift;
    $self->{_changed} > 0;
}

sub finalize {
    my ($self, $response) = @_;

    $self->commit if $self->is_changed || $self->expired;
    if ($self->expired) {
        $self->_manager->state->expire_session_id($self->id, $response);
    } else {
        $self->_manager->state->finalize($self->id, $response, $self);
    }
}

1;

__END__

=pod

=head1 NAME

Plack::Session - Middleware for session management

=head1 SYNOPSIS

  use Plack::Session;

  my $store = Plack::Session::Store->new;
  my $state = Plack::Session::State->new;

  my $s = Plack::Session->new(
      store   => $store,
      state   => $state,
      request => Plack::Request->new( $env )
  );

  # ...

=head1 DESCRIPTION

This is the core session object, you probably want to look
at L<Plack::Middleware::Session>, unless you are writing your
own session middleware component.

=head1 METHODS

=over 4

=item B<new ( %params )>

The constructor expects keys in C<%params> for I<state>,
I<store> and I<request>. The I<request> param is expected to be
a L<Plack::Request> instance or an object with an equivalent
interface.

=item B<id>

This is the accessor for the session id.

=item B<state>

This is expected to be a L<Plack::Session::State> instance or
an object with an equivalent interface.

=item B<store>

This is expected to be a L<Plack::Session::Store> instance or
an object with an equivalent interface.

=back

=head2 Session Data Management

These methods allows you to read and write the session data like
Perl's normal hash. The operation is not synced to the storage until
you call C<finalize> on it.

=over 4

=item B<get ( $key )>

=item B<set ( $key, $value )>

=item B<remove ( $key )>

=item B<keys>

=back

=head2 Session Lifecycle Management

=over 4

=item B<commit>

This method synchronizes the session data to the data store, without
waiting for the response final phase.

=item B<expire>

This method can be called to expire the current session id. It marks
the session as expire and call the C<cleanup> method on the C<store>
and the C<expire_session_id> method on the C<state>.

=item B<finalize ( $manager, $response )>

This method should be called at the end of the response cycle. It will
call the C<store> method on the C<store> and the C<expire_session_id>
method on the C<state>. The C<$response> is expected to be a
L<Plack::Response> instance or an object with an equivalent interface.

=back

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little E<lt>stevan.little@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2009, 2010 Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

