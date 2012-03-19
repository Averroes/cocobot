# @created 2012-03-19
# @date 2012-03-19
# @author Simon Rubinstein <ssimonrubinstein1@gmail.com>
# http://code.google.com/p/cocobot/
#
# copyright (c) Simon Rubinstein 2010-2012
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
package Cocoweb::User::HashList;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use POSIX;

use Cocoweb;
use Cocoweb::User;
use Cocoweb::User::List;
use base 'Cocoweb::User::List';


##@method void init(%args)
#@brief Perform some initializations
sub init {
    my ( $self, %args ) = @_;
    $self->attributes_defaults( 'all' => {} );
}

sub populate {
    my (
        $self,       $mynickID, $myage,  $mysex, $citydio,
        $mynickname, $myXP,     $mystat, $myver
    ) = @_;
    my $users_ref = $self->all();
    if ( exists $users_ref->{$mynickID} ) {
        $users_ref->{$mynickID}->{'isNew'}  = 0;
        $users_ref->{$mynickID}->{'isView'} = 1;
    }
    else {
        $users_ref->{$mynickID} = Cocoweb::User->new(
            'mynickID'   => $mynickID,
            'myage'      => $myage,
            'mysex'      => $mysex,
            'citydio'    => $citydio,
            'mynickname' => $mynickname,
            'myXP'       => $myXP,
            'mystat'     => $mystat,
            'myver'      => $myver
        );
    }

}

##@method hashref checkIfNicknameExists($pseudonym)
#@brief Check if a pseudonym already exists in the list
#       of pseudonym already read.
#@param string The pseudonym wanted
#@return hashref
sub checkIfNicknameExists {
    my ( $self, $pseudonym ) = @_;
    return if !defined $pseudonym or length($pseudonym) == 0;
    my $user_ref = $self->all();
    foreach my $id ( keys %$user_ref ) {
        my $name = $user_ref->{$id}->{'mynickname'};
        if ( lc($name) eq lc($pseudonym) ) {
            debug("The pseudonym '$pseudonym' was found");
            return $user_ref->{$id};
        }
    }
    debug("The pseudonym '$pseudonym' was not found");
    return;
}

1
