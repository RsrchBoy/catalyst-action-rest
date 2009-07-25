package Test::Action::Class;
use strict;
use warnings;

use Moose;
BEGIN { extends 'Catalyst::Action' };

before execute => sub {
   my ($self, $controller, $c, @args) = @_;
   $c->response->header( 'Using-Action' => 'STATION' );
};

no Moose;

1;
