package Catalyst::ControllerRole::REST::StatusHelpers;

use Moose::Role;
use namespace::autoclean;

use Params::Validate qw(SCALAR OBJECT);

our $VERSION = '0.85';
$VERSION = eval $VERSION;

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

We use the config slot of 'stash_key' to determine where in the stash we put
our entity data to serialize.  (Note that this role does not do serialization
-- you should either handle this yourself in an end action, or using something
like L<Catalyst::ControllerRole::Serialize>.  See
L<Catalyst::Controller::REST> for more information.)

=cut 

requires 'config';
requires 'COMPONENT';

before COMPONENT => sub {
    my $class = shift @_;

    $class->config(
        $class->merge_config_hashes({ 'stash_key' => 'rest' }, $class->config)
    );
    return;
};

=begin

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

=head1 STATUS HELPERS

Since so much of REST is in using HTTP, we provide these Status Helpers.
Using them will ensure that you are responding with the proper codes,
headers, and entities.

These helpers try and conform to the HTTP 1.1 Specification.  You can
refer to it at: L<http://www.w3.org/Protocols/rfc2616/rfc2616.txt>.
These routines are all implemented as regular subroutines, and as
such require you pass the current context ($c) as the first argument.

=over

=item status_ok

Returns a "200 OK" response.  Takes an "entity" to serialize.

Example:

  $self->status_ok(
    $c,
    entity => {
        radiohead => "Is a good band!",
    }
  );

=cut

sub status_ok {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { entity => 1, }, );

    $c->response->status(200);
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_created

Returns a "201 CREATED" response.  Takes an "entity" to serialize,
and a "location" where the created object can be found.

Example:

  $self->status_created(
    $c,
    location => $c->req->uri->as_string,
    entity => {
        radiohead => "Is a good band!",
    }
  );

In the above example, we use the requested URI as our location.
This is probably what you want for most PUT requests.

=cut

sub status_created {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate(
        @_,
        {
            location => { type     => SCALAR | OBJECT },
            entity   => { optional => 1 },
        },
    );

    my $location;
    if ( ref( $p{'location'} ) ) {
        $location = $p{'location'}->as_string;
    } else {
        $location = $p{'location'};
    }
    $c->response->status(201);
    $c->response->header( 'Location' => $location );
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_accepted

Returns a "202 ACCEPTED" response.  Takes an "entity" to serialize.

Example:

  $self->status_accepted(
    $c,
    entity => {
        status => "queued",
    }
  );

=cut

sub status_accepted {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { entity => 1, }, );

    $c->response->status(202);
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_no_content

Returns a "204 NO CONTENT" response.

=cut

sub status_no_content {
    my $self = shift;
    my $c    = shift;
    $c->response->status(204);
    $self->_set_entity( $c, undef );
    return 1.;
}

=item status_multiple_choices

Returns a "300 MULTIPLE CHOICES" response. Takes an "entity" to serialize, which should
provide list of possible locations. Also takes optional "location" for preferred choice.

=cut

sub status_multiple_choices {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate(
        @_,
        {
            entity => 1,
            location => { type     => SCALAR | OBJECT, optional => 1 },
        },
    );

    my $location;
    if ( ref( $p{'location'} ) ) {
        $location = $p{'location'}->as_string;
    } else {
        $location = $p{'location'};
    }
    $c->response->status(300);
    $c->response->header( 'Location' => $location ) if exists $p{'location'};
    $self->_set_entity( $c, $p{'entity'} );
    return 1;
}

=item status_bad_request

Returns a "400 BAD REQUEST" response.  Takes a "message" argument
as a scalar, which will become the value of "error" in the serialized
response.

Example:

  $self->status_bad_request(
    $c,
    message => "Cannot do what you have asked!",
  );

=cut

sub status_bad_request {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { message => { type => SCALAR }, }, );

    $c->response->status(400);
    $c->log->debug( "Status Bad Request: " . $p{'message'} ) if $c->debug;
    $self->_set_entity( $c, { error => $p{'message'} } );
    return 1;
}

=item status_not_found

Returns a "404 NOT FOUND" response.  Takes a "message" argument
as a scalar, which will become the value of "error" in the serialized
response.

Example:

  $self->status_not_found(
    $c,
    message => "Cannot find what you were looking for!",
  );

=cut

sub status_not_found {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { message => { type => SCALAR }, }, );

    $c->response->status(404);
    $c->log->debug( "Status Not Found: " . $p{'message'} ) if $c->debug;
    $self->_set_entity( $c, { error => $p{'message'} } );
    return 1;
}

=item gone

Returns a "41O GONE" response.  Takes a "message" argument as a scalar,
which will become the value of "error" in the serialized response.

Example:

  $self->status_gone(
    $c,
    message => "The document have been deleted by foo",
  );

=cut

sub status_gone {
    my $self = shift;
    my $c    = shift;
    my %p    = Params::Validate::validate( @_, { message => { type => SCALAR }, }, );

    $c->response->status(410);
    $c->log->debug( "Status Gone " . $p{'message'} ) if $c->debug;
    $self->_set_entity( $c, { error => $p{'message'} } );
    return 1;
}

sub _set_entity {
    my $self   = shift;
    my $c      = shift;
    my $entity = shift;
    if ( defined($entity) ) {
        $c->stash->{ $self->{'stash_key'} } = $entity;
    }
    return 1;
}

=back

=head1 MANUAL RESPONSES

If you want to construct your responses yourself, all you need to
do is put the object you want serialized in $c->stash->{'rest'}.

=head1 A MILD WARNING

I have code in production using L<Catalyst::Controller::REST>.  That said,
it is still under development, and it's possible that things may change
between releases.  I promise to not break things unnecessarily. :)

=head1 SEE ALSO

L<Catalyst::Controller::REST>, L<Catalyst::Action::REST>,
L<Catalyst::Action::Serialize>, L<Catalyst::Action::Deserialize>.

This role should also be suitable with L<Catalyst::Controller::Resources>.

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
