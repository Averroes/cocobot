# @brief
# @created 2012-12-10
# @date 2013-18-01 
# @author Simon Rubinstein <ssimonrubinstein1@gmail.com>
# http://code.google.com/p/cocobot/
#
# copyright (c) Simon Rubinstein 2010-2013
# Id: $Id$
# Revision: $Revision$
# Date: $Date$
# Author: $Author$
# HeadURL: $HeadURL$
#
# cocobot is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# cocobot is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.
package Cocoweb::Alert::XMPP;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Net::XMPP;
use Cocoweb;
use base 'Cocoweb::Object';

__PACKAGE__->attributes(
    'name',           'hostname',   'port',     'componentname',
    'connectiontype', 'tls',        'username', 'password',
    'to',             'resource', 'subject'
);

##@method void init(%args)
#@brief Perform some initializations
sub init {
    my ( $self, %args ) = @_;
    my $conf = $args{'conf'};

    $self->attributes_defaults(
        'name'           => $conf->getString('name'),
        'hostname'       => $conf->getString('hostname'),
        'port'           => $conf->getInt('port'),
        'componentname'  => $conf->getString('componentname'),
        'connectiontype' => $conf->getString('connectiontype'),
        'tls'            => $conf->getBool('tls'),
        'username'       => $conf->getString('username'),
        'password'       => $conf->getString('password'),
        'to'             => $conf->getString('to'),
        'resource'       => $conf->getString('resource'),
        'subject'        => $conf->getString('subject')
    );
}

sub connectionProcess {
    my ($self) = @_;
    my $connection = new Net::XMPP::Client();

    debug("Connect to " . $self->hostname());
    my $status = $connection->Connect(
        'hostname'       => $self->hostname(),
        'port'           => $self->port(),
        'componentname'  => $self->componentname(),
        'connectiontype' => $self->connectiontype(),
        'tls'            => $self->tls(),
        'ssl_verify'     => 0x00
    );

    croak error( 'XMPP connection failed: ' . $! ) if !defined $status;

    # change hostname
    my $sid = $connection->{SESSION}->{id};
    $connection->{STREAM}->{SIDS}->{$sid}->{hostname} = $self->componentname();

    # authenticate
    debug("Authenticate " . $self->username());
    my @result = $connection->AuthSend(
        'username' => $self->username(),
        'password' => $self->password(),
        'resource' => $self->resource()
    );

    croak error( 'Authorization failed:' . $result[0] . '-' . $result[1] )
      if $result[0] ne 'ok';

    debug('PresenceSend()');
    $connection->PresenceSend( 'show' => 'available' );
    return $connection;
}

sub messageSend {
    my ( $self, $body ) = @_;
    my $connection = $self->connectionProcess();
    debug('MessageSend()');
    $connection->MessageSend(
        to       => $self->to(),
        resource => $self->resource(),
        subject  => $self->subject(),
        type     => 'chat',
        body     => $body
    );
    $connection->Disconnect();
}

1;
