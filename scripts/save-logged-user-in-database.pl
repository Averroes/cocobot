#!/usr/bin/perl
#@brief 
#@created 2012-03-09
#@date 2012-03-09
#@author Simon Rubinstein <ssimonrubinstein1@gmail.com>
# http://code.google.com/p/cocobot/
#
# copyright (c) Simon Rubinstein 2010-2012
# Id: $Id
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
use FindBin qw($Script $Bin);
use Time::HiRes;
use utf8;
no utf8;
use lib "../lib";
use Cocoweb;
use Cocoweb::CLI;
my $CLI;

init();
run();

##@method ivoid run()
sub run {
    my $bot = $CLI->getBot( 'generateRandom' => 1 );
    $bot->process();
    if ( !$bot->isPremiumSubscription() ) {
        die error( 'The script is reserved for users with a'.  ' Premium subscription.' );
    }
    while(1) {
        my ($seconds, $microseconds) = Time::HiRes::gettimeofday;
        my $userFound_ref = $bot->getUsersList();
        my $t0 = [Time::HiRes::gettimeofday];
        print "t0 = $t0\n";
        my $elapsed = Time::HiRes::tv_interval ( $t0 );
        print "$elapsed\n";

        sleep(4);

    }

    info("The $Bin script was completed successfully.");
}



## @method void init()
sub init {
    $CLI = Cocoweb::CLI->instance();
    my $opt_ref = $CLI->getOpts();
    if ( !defined $opt_ref ) {
        HELP_MESSAGE();
        exit;
    }
}

## @method void HELP_MESSAGE()
# Display help message
sub HELP_MESSAGE {
    print <<ENDTXT;
Usage: 
 $Script [-u mynickname -y myage -s mysex -a myavatar -p mypass -v -d]
  -u mynickname      An username
  -y myage           Year old
  -s mysex           M for man or W for women
  -a myavatar        Code 
  -p mypass
  -v                 Verbose mode
  -d                 Debug mode
ENDTXT
    exit 0;
}

## @method void VERSION_MESSAGE()
sub VERSION_MESSAGE {
    print STDOUT <<ENDTXT;
    $Script $Cocoweb::VERSION (2012-03-09) 
     Copyright (C) 2010-2012 Simon Rubinstein 
     Written by Simon Rubinstein 
ENDTXT
}

