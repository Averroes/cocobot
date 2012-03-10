# @brief
# @created 2012-02-17
# @date 2012-03-10
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
package Cocoweb::Request;
use strict;
use warnings;
use Cocoweb;
use Cocoweb::Config;
use Cocoweb::Config::Hash;
use Cocoweb::Encode;
use base 'Cocoweb::Object';
use Carp;
use Data::Dumper;
use Encode qw(encode FB_PERLQQ);
use LWP::UserAgent;
use Time::HiRes qw(usleep nanosleep);
use utf8;
no utf8;

__PACKAGE__->attributes(
    'myport',
    'url1',
    ## 0 = all; 1 = mens;  womens: 2
    'genru',
    ## 0 = all; 1 = -30 / 2 = 20 to 40 / 3 = 30 to 50 / 4 = 40 and more
    'yearu',
    'userFound',
    'speco',
    'convert'
);

my $conf_ref;
my $agent_ref;
my $userAgent;

##@method void init($args)
#@brief Perform some initializations
sub init {
    my ( $self, %args ) = @_;
    if ( !defined $conf_ref ) {
        my $conf = Cocoweb::Config->instance()->getConfigFile('request.conf');
        $conf_ref = $conf->all();
        foreach my $name (
            'urly0',  'urlprinc',    'current-url', 'avatar-url',
            'avaref', 'urlcocoland', 'urlav'
          )
        {
            $conf->isString($name);
        }
        $agent_ref = $conf->getHash('user-agent');
        my $uaConf = Cocoweb::Config::Hash->new( 'hash' => $agent_ref );
        $uaConf->isString('agent');
        $uaConf->isInt('timeout');
        $uaConf->isHash('header');
        $userAgent = LWP::UserAgent->new(
            'agent'   => $agent_ref->{'agent'},
            'timeout' => $agent_ref->{'timeout'}
        );
    }

    my $myport = 3000 + randum(1000);

    $self->attributes_defaults(
        'myport'    => $myport,
        'url1'      => $conf_ref->{'urly0'} . ':' . $myport . '/',
        'genru'     => 0,
        'yearu'     => 0,
        'userFound' => {},
        'speco'     => 0,
        'convert'   => Cocoweb::Encode->instance()
    );

    #debug( "url1: " . $self->url1() );
}

##@method string getValue($name)
#@brief Returns a value in the configuration file 'request.conf'
#@param string $name A name value to return
#@rerturn string The requested value
sub getValue {
    my ( $self, $name ) = @_;
    if ( exists $conf_ref->{$name} ) {
        return $conf_ref->{$name};
    }
    else {
        croak error( 'Error: The "' 
              . $name
              . '" value was not found in the configuration.' );
    }
}

## @method object execute($url, $cookie_ref)
#@brief Executes a HTTP request with the object HTTP::Request
#@param string An HTTP request method, e.g. 'GET' or 'POST'
#@param string An URL for the HTTP request
#@param hashref
#@return object A HTTP::Response object
sub execute {
    my ( $self, $method, $url, $cookie_ref ) = @_;
    croak error("The HTTP method is missing")             if !defined $method;
    croak error("The URL of the HTTP request is missing") if !defined $url;
    my $req = HTTP::Request->new( $method => $url );
    foreach my $field ( keys %{ $agent_ref->{'header'} } ) {
        $req->header( $field => $agent_ref->{'header'}->{$field} );
    }
    if ( defined $cookie_ref and scalar keys %$cookie_ref > 0 ) {
        debug( ( scalar keys %$cookie_ref ) . ' cookies where found' );
        my $cookieStr = '';
        foreach my $k ( keys %$cookie_ref ) {
            my $val = $self->jsEscape( $cookie_ref->{$k} );
            $cookieStr .= $k . "=" . $val . ';';
        }
        chop($cookieStr);
        $req->header( 'Cookie' => $cookieStr );
    }

    #debug($req->as_string());
    my $response = $userAgent->request($req);
    if ( !$response->is_success() ) {
        croak error( $response->status_line() );
    }
    return $response;
}

## @method string jsEscape($string)
# @brief works to escape a string to JavaScript's URI-escaped string.
# @author Koichi Taniguchi
sub jsEscape {
    my ( $self, $string ) = @_;
    $string =~ s{([\x00-\x29\x2C\x3A-\x40\x5B-\x5E\x60\x7B-\x7F])}
    {'%' . uc(unpack('H2', $1))}eg;    # XXX JavaScript compatible
    $string = encode( 'ascii', $string, sub { sprintf '%%u%04X', $_[0] } );
    return $string;
}

## @method void getCityco($user_ref)
sub getCityco {
    my ( $self, $user ) = @_;

    my $zip = $user->zip();
    croak error("Error: The '$zip' zip code is invalid!")
      if $zip !~ /^\d{5}$/;
    my $i = index( $zip, '0' );
    if ( $i == 0 ) {
        $zip = substr( $zip, 1, 5 );
    }
    my $url      = $conf_ref->{'urlcocoland'} . $zip . '.js';
    my $response = $self->execute( 'GET', $url );
    my $res      = $response->content();

    # Retrieves a string like "var cityco='30926*PARIS*';"
    if ( $res !~ m{var\ cityco='([^']+)';}xms ) {
        die error( 'Error: cityco have not been found!'
              . 'The HTTP requests "'
              . $url
              . '" return: '
              . $res );
    }
    my $cityco = $1;

    #debug("cityco: $cityco");
    my @tmp = split( /\*/, $cityco );
    my ( $citydio, $townzz );
    my $count = scalar @tmp;
    die error("Error: The cityco is not valid (cityco: $cityco)")
      if $count % 2 != 0
          or $count == 0;

    if ( $count == 2 ) {
        $citydio = $tmp[0];
        $townzz  = $tmp[1];
    }
    else {
        my $r = int( rand( $count / 2 ) );
        $r += $r;
        $citydio = $tmp[$r];
        $townzz  = $tmp[ $r + 1 ];
    }

    #debug("citydio: $citydio; townzz: $townzz");
    $user->citydio($citydio);
    $user->townzz($townzz);
}

##@method void firsty($user)
#@brief The first HTTP request sent to the server
#@param object $user An 'Cocoweb::User' object
sub firsty {
    my ( $self, $user ) = @_;
    $self->agix( $user,
            $self->url1() . '40'
          . $user->mynickname() . '*'
          . $user->myage()
          . $user->mysex()
          . $user->citydio()
          . $user->myavatar()
          . $self->speco()
          . $user->mypass() );
}

##@method void agir($user, $txt1)
#@brief Initiates a standard request to the server
#@param object $user An 'Cocoweb::User' object
#@param string $txt1 The parameter of the HTTP request
sub agir {
    my ( $self, $user, $txt3 ) = @_;
    $self->agix( $user,
            $self->url1()
          . substr( $txt3, 0, 2 )
          . $user->mynickID()
          . $user->monpass()
          . substr( $txt3, 2 ) );
}

##@method void agix($user, $url, $cookie_ref)
#@brief Performs an HTTP Requests to invoke a remote method
#@param object $user An 'Cocoweb::User' object
#@param string An URL for the HTTP request
#@param hashref $cookie_ref A hash that contains possible cookies.
sub agix {
    my ( $self, $user, $url, $cookie_ref ) = @_;
    croak error("The URL of the HTTP request is missing") if !defined $url;
    info("url: $url");
    my $response = $self->execute( 'GET', $url, $cookie_ref );
    my $res = $response->content();

    #debug($res);
    die error(
        'Error: the JavaScript function not found in the string: ' . $res )
      if $res !~ m{^([^\(]+)\('([^']*)'\)}xms;
    my $function = $1;
    my $arg      = $2;

    #info( 'function: ' . $function . '; arg: ' . $arg );
    my $process;
    eval( '$process = \&' . $function );
    if ($@) {
        die sayError($@);
    }
    $self->$process( $user, $arg );
}

##@method void process1($user, $urlu)
#@brief Method called back after an HTTP request to the server
#@param object $user An 'Cocoweb::User' object
#@param string $urlu String returned by the server
sub process1 {
    my ( $self, $user, $urlu ) = @_;
    my ($todo) = ('');

    debug("urlu: $urlu");
    my $urlo = $urlu;
    my $hzy = index( $urlo, '#' );
    $urlo = substr( $urlo, $hzy + 1, length($urlo) - $hzy - 1 );

    my $urlw = index( $urlo, '|' );
    if ( $urlw > 0 ) {
        $todo = '#' . substr( $urlo, $urlw + 1, length($urlo) - $urlw - 1 );
    }

    my $firstChar = substr( $urlo, 0, 1 );
    my $molki = ord($firstChar);

    debug("firstChar: $firstChar; molki = $molki");

    #
    if ( $molki < 58 ) {
        $self->process1Int( $user, $urlo );
    }
    else {
        info("process1() $molki code unknown");
    }
}

## @method void process1Int($user, $urlo)
sub process1Int {
    my ( $self, $user, $urlo ) = @_;

    #debug("urlo: $urlo");
    my $olko = parseInt( substr( $urlo, 0, 2 ) );
    info("olko: $olko");

    # The first part of authentication was performed successfully
    # The server returns an ID and a password for the current session
    if ( $olko == 12 ) {
        my $lebonnick = parseInt( substr( $urlo, 2, 6 ) );
        $user->mynickID( '' . $lebonnick );
        $user->monpass( substr( $urlo, 8, 6 ) );
        $user->mycrypt( parseInt( substr( $urlo, 14, 21 - 14 ) ) );
        info(   'mynickID: '
              . $user->mynickID()
              . '; monpass: '
              . $user->monpass()
              . '; mycrypt: '
              . $user->mycrypt() );
        $olko = 51;
    }

    if ( $olko == 51 ) {

        #setTimeout("agir('51'+agento)",500);
        usleep( 1000 * 500 );
        $self->agir( $user,
            '51' . $self->convert()->writo( $agent_ref->{'agent'} ) );
    }

    if ( $olko == 99 ) {
        my $bud = parseInt( substr( $urlo, 2, 3 ) );
        info("bud: $bud");

        if ( $bud == 444 ) {
            my $urlu =
              $self->convert()->transformix( substr( $urlo, 5 ), -1, 0 );
            return $urlu;
        }

        if ( $bud == 447 or $bud == 445 ) {
            die error( substr( $urlo, 5 ) );
        }

        # Retrieves information about an user, for Premium subscribers only
        if ( $bud == 555 ) {
            my $urlu =
              $self->convert()->transformix( substr( $urlo, 5 ), -1, 0 );
            return $urlu;
        }

        # The second part of the authentication is completed successfully
        # The server returns some information about the user account.
        if ( $bud == 556 ) {

  #agix(urlav+myage+mysex+parami[3]+myavatar+mynickID+monpass+mycrypt,4)
  #agix(url1+"40"+mynickname+"*"+myage+mysex+parami[3]+myavatar+speco+mypass,4);
  #$self->agix( $user,
  #          $conf_ref->{'urlav'}
  #        . $user->myage()
  #        . $user->mysex()
  #        . $user->citydio()
  #        . $user->myavatar()
  #        . $user->mynickID()
  #        . $user->monpass()
  #        . $user->mycrypt() );
            $user->mystat( parseInt( substr( $urlo, 6, 1 ) ) );
            $user->myXP( parseInt( substr( $urlo, 5, 1 ) ) );
            $user->myver( parseInt( substr( $urlo, 7, 1 ) ) );
            info(   'mystat: '
                  . $user->mystat()
                  . '; myXP:'
                  . $user->myXP()
                  . '; myver: '
                  . $user->myver() );

        }
    }

    # Retrieves the list of pseudonyms
    if ( $olko == 34 ) {
        $self->populate( $self->userFound(), $urlo, 0 );
    }
    elsif ( $olko == 13 ) {
        die error("You have been disconnected. Log back on Coco.fr");
    }
    elsif ( $olko == 10 ) {
        die error( 'You are disconnected because someone with the'
              . ' same IP is already connected to the chat server.'
              . ' Otherwise try to connect in 30 seconds.' );
    }
    elsif ( $olko == 36 ) {
        if ( $user->mystat() < 6 ) {
            $user->mystat( parseInt( substr( $user, 2 ) ) % 10 );
        }
    }

    if ( $olko == 87 ) {
        $olko = 89;
    }

    if ( $olko == 23 ) {

        #$self->yabon();
    }

    # Retrieves the list of rooms
    if ( $olko == 89 ) {
    }

    if ( $olko == 39 ) {
        my $infor = substr( $urlo, 2 );
        die error("cookie bug. infor: $infor ($urlo)");
    }

    # No more private conversation is accepted
    if ( $olko == 98 ) {
        info("No more private conversation is accepted.");
        $olko = 967;
    }

    # No more male user message is accepted
    if ( $olko == 96 ) {
        info("No more male user message is accepted.");
        $olko = 967;
    }

    #A message has been sent to the chat.
    if ( $olko == 97 ) {
        $olko = 967;
    }
    if ( $olko == 66 ) {
        $olko = 967;
    }
    if ( $olko == 48 ) {
        $self->populate( $user->amiz(), $urlo, 0 );
        return $user->amiz();
    }

    if ( $olko == 967 ) {
    }

}

sub clearUsersList {
    my ($self) = @_;

    $self->userFound( {} );

}

## @method void populate($userFound_ref, $urlo, $offsat)
sub populate {
    my ( $self, $userFound_ref, $urlo, $offsat ) = @_;
    my $countNew      = 0;
    if ( length($urlo) > 12 ) {
        my ( $indux, $mopo, $hzy ) = ( 0, 0, 2 );
        while ( $mopo < 1 ) {
            $indux = index( $urlo, '#', $hzy );
            if ( $indux < 2 ) {
                $mopo = 2;
            }
            else {

                my $id = parseInt( substr( $urlo, 8 + $hzy, 6 ) );
                $countNew++ if !exists $userFound_ref->{$id};
                $userFound_ref->{$id} = {
                    'id'   => $id,
                    'old'  => parseInt( substr( $urlo, $hzy, 2 ) ),
                    'sex'  => parseInt( substr( $urlo, 2 + $hzy, 1 ) ),
                    'city' => parseInt( substr( $urlo, 3 + $hzy, 5 ), 10 ),
                    'login' => substr( $urlo, 17 + $hzy, $indux - 17 - $hzy ),
                    'niv'  => parseInt( substr( $urlo, 14 + $hzy, 1 ) ),
                    'stat' => parseInt( substr( $urlo, 15 + $hzy, 1 ) ),
                    'ok'   => parseInt( substr( $urlo, 16 + $hzy, 1 ) )
                };
                $hzy = $indux + 1;
            }
        }
    }
    debug("$countNew new logins was found");
}

##@method void searchnow($user)
#@brief Call the remote method to retrieve the list of pseudonyms.
#@param object @user An 'User object' object
sub searchnow {
    my ( $self, $user ) = @_;
    debug( 'genru: ' . $self->genru() . '; yearu: ' . $self->yearu() );
    $self->agir( $user, '10' . $self->genru() . $self->yearu() );
}

##@method void cherchasalon($user)
#@param object @user An 'User object' object
sub cherchasalon {
    my ( $self, $user ) = @_;
    $self->agir( $user, '89' );
}

##@method void actuam($user)
#@brief Get the list of contacts, nicknamed 'amiz'
#@param object @user An 'User object' object
#@return string
sub actuam {
    my ( $self, $user ) = @_;
    $self->agir( $user, '48' );
}

##@method void getUserInfo()
#@brief Get the number of days remaining until the end of
#       the Premium subscription.
#@param object @user An 'User object' object
sub getUserInfo {
    my ( $self, $user ) = @_;
    $self->agir( $user, '77369' );
}

## @method void writus($user, $s1, $nickId)
#@brief
#@param object @user An 'User object' object
#@param string $s1
sub writus {
    my ( $self, $user, $s1, $nickId ) = @_;
    return if !defined $s1 or length($s1) == 0;
    my $s2 = '';
    $s2 = $self->convert()->writo($s1);
    my $sendito = '99' . $nickId . $user->roulix() . $s2;
    $self->agir( $user, '99' . $nickId . $user->roulix() . $s2 );
    my $roulix = $user->roulix();
    if ( ++$roulix > 8 ) {
        $roulix = 0;
    }
    $user->roulix($roulix);
}

##@method string infuz($user, $nickId)
#@brief Retrieves information about an user
#       for Premium subscribers only
#@param object  $user   An 'User object' object
#@param integer $nickId the nickname ID which information is requested
#@return string Nickname information. The information includes:
#               a unique code, ISP, status, level, connection time,
#               a country code and city. This information is not reliable.
sub infuz {
    my ( $self, $user, $nickId ) = @_;
    if ( $user->isPremiumSubscription() ) {
        return $self->agir( $user, '83555' . $nickId );
    }
    else {
        warning('The command "infuz" is reserved for users with a'
              . ' Premium subscription.' );
        return;
    }
}

## @method hashref searchPseudonym($user, $pseudonym)
#@param string The pseudonym wanted
sub searchPseudonym {
    my ( $self, $user, $pseudonym ) = @_;
    debug("pseudonym: $pseudonym");
    my $pseudonym_ref;
    $pseudonym_ref = $self->checkIfPseudonymExists($pseudonym);
    return $pseudonym_ref if defined $pseudonym_ref;
    foreach my $g ( 1, 2 ) {
        $self->genru($g);
        foreach my $y ( 1, 2, 3, 4 ) {
            $self->yearu($y);
            $self->searchnow($user);
            $pseudonym_ref = $self->checkIfPseudonymExists($pseudonym);
            return $pseudonym_ref if defined $pseudonym_ref;
        }
    }
    return $self->userFound()
      if !defined $pseudonym
          or length($pseudonym) == 0;
    debug("The pseudonym '$pseudonym' was not found");
    return;
}

##@method hashref checkIfPseudonymExists($pseudonym)
#@brief Check if a pseudonym already exists in the list
#       of pseudonym already read.
#@param string The pseudonym wanted
#@return hashref
sub checkIfPseudonymExists {
    my ( $self, $pseudonym ) = @_;
    return if !defined $pseudonym or length($pseudonym) == 0;
    my $userFound_ref = $self->userFound();
    foreach my $id ( keys %$userFound_ref ) {
        my $name = $userFound_ref->{$id}->{'login'};
        if ( lc($name) eq lc($pseudonym) ) {
            debug("The pseudonym '$pseudonym' was found");
            return $userFound_ref->{$id};
        }
    }
    debug("The pseudonym '$pseudonym' was not found");
    return;
}

1;

