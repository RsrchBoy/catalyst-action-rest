package Catalyst::Controller::REST;

use Moose;
use namespace::autoclean;

extends 'Catalyst::Controller';
with 'Catalyst::ControllerRole::StatusHelpers';
with 'Catalyst::ControllerRole::Serialize';

our $VERSION = '0.85';
$VERSION = eval $VERSION;

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Catalyst::Controller::REST - A RESTful controller

=head1 SYNOPSIS

    package Foo::Controller::Bar;
    use Moose;
    use namespace::autoclean;
    
    BEGIN { extends 'Catalyst::Controller::REST' }

    sub thing : Local : ActionClass('REST') { }

    # Answer GET requests to "thing"
    sub thing_GET {
       my ( $self, $c ) = @_;

       # Return a 200 OK, with the data in entity
       # serialized in the body
       $self->status_ok(
            $c,
            entity => {
                some => 'data',
                foo  => 'is real bar-y',
            },
       );
    }

    # Answer PUT requests to "thing"
    sub thing_PUT {
        $radiohead = $req->data->{radiohead};
        
        $self->status_created(
            $c,
            location => $c->req->uri->as_string,
            entity => {
                radiohead => $radiohead,
            }
        );
    }     

=head1 DESCRIPTION

Catalyst::Controller::REST implements a mechanism for building
RESTful services in Catalyst.  It does this by extending the
normal Catalyst dispatch mechanism to allow for different
subroutines to be called based on the HTTP Method requested,
while also transparently handling all the serialization/deserialization for
you.

This is probably best served by an example.  In the above
controller, we have declared a Local Catalyst action on
"sub thing", and have used the ActionClass('REST').

Below, we have declared "thing_GET" and "thing_PUT".  Any
GET requests to thing will be dispatched to "thing_GET",
while any PUT requests will be dispatched to "thing_PUT".

Any unimplemented HTTP methods will be met with a "405 Method Not Allowed"
response, automatically containing the proper list of available methods.  You
can override this behavior through implementing a custom
C<thing_not_implemented> method.

If you do not provide an OPTIONS handler, we will respond to any OPTIONS
requests with a "200 OK", populating the Allowed header automatically.

Any data included in C<< $c->stash->{'rest'} >> will be serialized for you.
The serialization format will be selected based on the content-type
of the incoming request.  It is probably easier to use the L<STATUS HELPERS>,
which are described below.

"The HTTP POST, PUT, and OPTIONS methods will all automatically
L<deserialize|Catalyst::Action::Deserialize> the contents of
C<< $c->request->body >> into the C<< $c->request->data >> hashref", based on 
the request's C<Content-type> header. A list of understood serialization
formats is L<below|/AVAILABLE SERIALIZERS>.

If we do not have (or cannot run) a serializer for a given content-type, a 415
"Unsupported Media Type" error is generated.

To make your Controller RESTful, simply have it

  BEGIN { extends 'Catalyst::Controller::REST' }

=head1 CONFIGURATION

See L<Catalyst::Action::Serialize/CONFIGURATION>. Note that the C<serialize>
key has been deprecated.

=head1 SERIALIZATION

Catalyst::Controller::REST will automatically serialize your
responses, and deserialize any POST, PUT or OPTIONS requests. It evaluates
which serializer to use by mapping a content-type to a Serialization module.
We select the content-type based on:

=over

=item B<The Content-Type Header>

If the incoming HTTP Request had a Content-Type header set, we will use it.

=item B<The content-type Query Parameter>

If this is a GET request, you can supply a content-type query parameter.

=item B<Evaluating the Accept Header>

Finally, if the client provided an Accept header, we will evaluate
it and use the best-ranked choice.

=back

By default, L<Catalyst::Controller::REST> will return a 
C<415 Unsupported Media Type> response if an attempt to use an unsupported
content-type is made.  You can ensure that something is always returned by
setting the C<default> config option:

  __PACKAGE__->config(default => 'text/x-yaml');

would make it always fall back to the serializer plugin defined for
C<text/x-yaml>.

Serialization (and deserialization) is handled by the
L<Catalyst::ControllerRole::Serialize> role; please see its documentation for
detailed information on how the process works.

=head1 MANUAL RESPONSES

If you want to construct your responses yourself, all you need to
do is put the object you want serialized in $c->stash->{'rest'}.

=head1 IMPLEMENTATION DETAILS

This Controller ties together L<Catalyst::Action::REST>,
L<Catalyst::Action::Serialize>, L<Catalyst::Action::Deserialize>,
L<Catalyst::ControllerRole::StatusHelpers>, and
L<Catalyst::ControllerRole::Serialize>.

It should be suitable for most applications.  You should be aware that it:

=over 4

=item Configures the Serialization Actions

This class provides a default configuration for Serialization.  It is currently:

  __PACKAGE__->config(
      'stash_key' => 'rest',
      'map'       => {
         'text/html'          => 'YAML::HTML',
         'text/xml'           => 'XML::Simple',
         'text/x-yaml'        => 'YAML',
         'application/json'   => 'JSON',
         'text/x-json'        => 'JSON',
         'text/x-data-dumper' => [ 'Data::Serializer', 'Data::Dumper' ],
         'text/x-data-denter' => [ 'Data::Serializer', 'Data::Denter' ],
         'text/x-data-taxi'   => [ 'Data::Serializer', 'Data::Taxi'   ],
         'application/x-storable'   => [ 'Data::Serializer', 'Storable' ],
         'application/x-freezethaw' => [ 'Data::Serializer', 'FreezeThaw' ],
         'text/x-config-general'    => [ 'Data::Serializer', 'Config::General' ],
         'text/x-php-serialization' => [ 'Data::Serializer', 'PHP::Serialization' ],
      },
  );

You can read the full set of options for this configuration block in
L<Catalyst::Action::Serialize>.

=item Sets a C<begin> and C<end> method for you

The C<begin> method uses L<Catalyst::Action::Deserialize>.  The C<end>
method uses L<Catalyst::Action::Serialize>.  If you want to override
either behavior, simply implement your own C<begin> and C<end> actions
and use MRO::Compat:

  package Foo::Controller::Monkey;
  use Moose;
  use namespace::autoclean;
  
  BEGIN { extends 'Catalyst::Controller::REST' }

  sub begin :Private {
    my ($self, $c) = @_;
    ... do things before Deserializing ...
    $self->maybe::next::method($c);
    ... do things after Deserializing ...
  }

  sub end :Private {
    my ($self, $c) = @_;
    ... do things before Serializing ...
    $self->maybe::next::method($c);
    ... do things after Serializing ...
  }

=back

=head1 A MILD WARNING

I have code in production using L<Catalyst::Controller::REST>.  That said,
it is still under development, and it's possible that things may change
between releases.  I promise to not break things unnecessarily. :)

=head1 SEE ALSO

L<Catalyst::Action::REST>, L<Catalyst::Action::Serialize>,
L<Catalyst::Action::Deserialize>

For help with REST in general:

The HTTP 1.1 Spec is required reading. http://www.w3.org/Protocols/rfc2616/rfc2616.txt

Wikipedia! http://en.wikipedia.org/wiki/Representational_State_Transfer

The REST Wiki: http://rest.blueoxen.net/cgi-bin/wiki.pl?FrontPage

=head1 AUTHORS

See L<Catalyst::Action::REST> for authors.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
