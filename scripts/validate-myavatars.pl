#!/usr/bin/perl
# @created 2015-01-03
# @date 2015-01-07
# @author Simon Rubinstein <ssimonrubinstein1@gmail.com>
# http://code.google.com/p/cocobot/
#
# copyright (c) Simon Rubinstein 2010-2015
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
use strict;
use warnings;
use Carp;
use FindBin qw($Script $Bin);
use Data::Dumper;
use utf8;
no utf8;
use lib "../lib";
use Cocoweb;
use Cocoweb::CLI;
use Cocoweb::MyAvatar::File;
my $CLI;
my $myavatarFiles;
my @botsList                   = ();
my @countersList               = ();
my @startTimeList              = ();
my $myAvatarValided            = 0;
my $myavatarCount              = 0;
my $isRestrictedAccountAllowed = 0;
my $isRunFilesUsed             = 0;
my $myavatars_ref;
my $userWanted;
my $myavatarNumOf;

init();
run();

##@method void run()
sub run {

    if ( defined $CLI->myavatar() and defined $CLI->mypass() ) {
        $myavatars_ref = [ $CLI->myavatar() . $CLI->mypass() ];
    }
    else {
        if ($isRunFilesUsed) {
            $myavatars_ref = $myavatarFiles->getRun();
        }
        else {
            $myavatars_ref = $myavatarFiles->getNew();
        }
    }
    $myavatarNumOf = scalar(@$myavatars_ref);

    my $numConcurrentUsers = $CLI->maxOfLoop();
    for ( my $i = 0; $i < $numConcurrentUsers; $i++ ) {
        my $bot = getNewBot();
        next if !defined $bot;
        push @botsList,      $bot;
        push @countersList,  0;
        push @startTimeList, time;
    }

    $numConcurrentUsers = scalar(@botsList);
    while (1) {
        my $processCount = 0;
        for ( my $i = 0; $i < $numConcurrentUsers; $i++ ) {
            next if !defined $botsList[$i];
            $processCount++;
            $countersList[$i]++;
            if (!process(
                    $botsList[$i], $countersList[$i], $startTimeList[$i]
                )
                )
            {
                debug( "delay: " . $CLI->delay() . ' second(s)' );
                sleep $CLI->delay() if $numConcurrentUsers < 2;
                next;
            }
            undef $botsList[$i];
            $botsList[$i]      = getNewBot();
            $countersList[$i]  = 0;
            $startTimeList[$i] = time;
        }
        last if $processCount < 1;
    }
    info("The $Bin script was completed successfully.");
}

sub getNewBot {
    return if scalar(@$myavatars_ref) < 1;
    $myavatarCount++;
    my $val = shift @$myavatars_ref;
    croak Cocoweb::error("$val if bad") if $val !~ m{^(\d{9})([A-Z]{20})$};
    my ( $myavatar, $mypass ) = ( $1, $2 );
    my $bot = $CLI->getBot(
        'generateRandom' => 1,
        'myavatar'       => $myavatar,
        'mypass'         => $mypass
    );
    $bot->display();
    $bot->searchChatRooms();
    $bot->actuam();
    $bot->requestAuthentication();

    if ( !defined($userWanted) ) {
        $userWanted = $CLI->getUserWanted($bot);
        die "User wanted was not found" if !defined $userWanted;
    }
    debug("*** Create new bot $myavatar, $mypass ***");
    return $bot;
}

sub process {
    my ( $bot, $counter, $starttime ) = @_;
    $counter++;
    $bot->setTimz1($counter);
    my $usersList;
    if ( $counter % 160 == 39 ) {
        $bot->requestCheckIfUsersNotSeenAreOffline();
    }
    if ( $counter % 28 == 9 ) {

        #This request is necessary to activate the server side time counter.
        $bot->searchChatRooms();
        $usersList = $bot->requestUsersList();
    }
    $bot->requestMessagesFromUsers();
    my $user = $bot->user();
    info(     '**'
            . $myavatarCount . '/'
            . $myavatarNumOf . '**' . '<'
            . ( time - $starttime )
            . ' seconds>; counter: ['
            . $counter
            . ']; myavatar:'
            . $user->myavatar()
            . '; mypass:'
            . $user->mypass()
            . '; number of validated myavatars: '
            . $myAvatarValided
            . "\n" );
    if ( $counter % 28 == 9 ) {
        my $response = $bot->requestToBeAFriend($userWanted);
        if ( $response->profileTooNew() ) {
            debug("The profile is still too recent.");
        }
        else {
            $myAvatarValided++;
            info("The profile is validated.");
            if (    !defined $CLI->myavatar()
                and !defined $CLI->mypass()
                and !$isRestrictedAccountAllowed )
            {
                my ( $myavatar, $mypass )
                    = ( $user->myavatar(), $user->mypass() );
                $myavatarFiles->moveNewToRun( $myavatar, $mypass );
                $myavatarFiles->updateRun( $myavatar, $mypass );
            }
            return 1;
        }
        $response = $bot->requestWriteMessage( $userWanted, $Script );
        if ( $response->isRestrictedAccount()
            and !$isRestrictedAccountAllowed )
        {
            debug("The account is restricted. Gives up.");
            return 1;
        }
    }
    return 0;
}

##@method void init()
#@brief Perform some initializations
sub init {
    $CLI = Cocoweb::CLI->instance();
    my $opt_ref = $CLI->getOpts(
        'enableLoop'    => 1,
        'searchEnable'  => 1,
        'argumentative' => 'RN'
    );
    if ( !defined $opt_ref ) {
        HELP_MESSAGE();
        exit;
    }
    $isRestrictedAccountAllowed = $opt_ref->{'R'} if exists $opt_ref->{'R'};
    $isRunFilesUsed             = $opt_ref->{'N'} if exists $opt_ref->{'N'};
    $myavatarFiles = Cocoweb::MyAvatar::File->instance();

}

## @method void HELP_MESSAGE()
# Display help message
sub HELP_MESSAGE {
    print STDOUT $Script . ', valide MyAvatar accounts.' . "\n";
    $CLI->printLineOfArgs('-R -N');
    print <<ENDTXT;
  -R                Enable the process of restricted accounts. 
  -N                Use the files in the 'run' directory. 
ENDTXT
    $CLI->HELP();
    exit 0;
}

##@method void VERSION_MESSAGE()
#@brief Displays the version of the script
sub VERSION_MESSAGE {
    $CLI->VERSION_MESSAGE('2015-01-07');
}

