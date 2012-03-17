# @brief Handle SQLite database
# @created 2012-03-11
# @date 2012-03-17
# @author Simon Rubinstein <ssimonrubinstein1@gmail.com>
# http://code.google.com/p/cocobot/
#
# copyright (c) Simon Rubinstein 2012
# Id: $Id$
# Revision$
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
package Cocoweb::DB;
use Cocoweb;
use base 'Cocoweb::Object::Singleton';
use Carp;
use FindBin qw($Script);
use DBI;
use Data::Dumper;
use Term::ANSIColor;
use strict;
use warnings;

__PACKAGE__->attributes( 'dbh', 'filename', 'ISO3166Regex' );

##@method object init($class, $instance)
sub init {
    my ( $class, $instance ) = @_;
    my $config = Cocoweb::Config->instance()->getConfigFile('database.conf');
    $instance->attributes_defaults(
        'dbh'          => undef,
        'filename'     => $config->getString('filename'),
        'ISO3166Regex' => $config->getString('ISO-3166-1-alpha-2')
    );
    return $instance;
}

##@method array getInitTowns()
#@brief Returns a list of town codes from the configuration file
#@return array A list of two elements:
#              - a hash table containing town codes
#              - an Cocoweb::Config::Plaintext object
sub getInitTowns {
    my ($self) = @_;
    my $towns = Cocoweb::Config->instance()->getConfigFile( 'towns.txt', 1 );
    my $ISO3166Regex = $self->ISO3166Regex();
    $ISO3166Regex = qr/^$ISO3166Regex.*/;
    my $towns_ref = $towns->getAsHash();
    foreach my $town ( keys %$towns_ref ) {
        die error("The string $town is not valid") if $town !~ $ISO3166Regex;
    }
    info( 'number of town codes: ' . scalar( keys %$towns_ref ) );
    return ( $towns_ref, $towns );
}

##@method array getInitISPs()
#@brief Returns a list of ISP codes from the configuration file
#@return array A list of two elements:
#              - a hash table containing ISP codes
#              - an Cocoweb::Config::Plaintext object
sub getInitISPs() {
    my ($self) = @_;
    my $ISPs = Cocoweb::Config->instance()->getConfigFile( 'ISPs.txt', 1 );
    my $ISPs_ref = $ISPs->getAsHash();
    info( 'number of ISP codes: ' . scalar( keys %$ISPs_ref ) );
    return ( $ISPs_ref, $ISPs );
}

##@method void connect()
sub connect {
    my ($self) = @_;
    my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $self->filename(),
        '', '', { 'PrintError' => 0, 'RaiseError' => 1, 'AutoCommit' => 1 } );
    if ( !defined($dbh) ) {
        my $errorMsg = $DBI::errstr;
        $errorMsg = 'DBI->connect() was failed' if !defined $errorMsg;
        croak error($errorMsg);
    }
    debug( $self->filename() . 'database connection successful' );
    $self->dbh($dbh);
}

##@method void createTables()
#@brief Creates the tables in the database
sub createTables {
    my ($self) = @_;

    my $query;

    $query = <<ENDTXT;
    CREATE TABLE IF NOT EXISTS `codes` (
    `id`            INTEGER UNSIGNED NOT NULL PRIMARY KEY,
    `code`          CHAR(3) UNIQUE NOT NULL,
    `creation_date` DATETIME NOT NULL,
    `update_date`   DATETIME NOT NULL)
ENDTXT
    $self->dbh()->do($query);

    $query = <<ENDTXT;
    CREATE TABLE IF NOT EXISTS `nicknames` (
    `id`            INTEGER PRIMARY KEY AUTOINCREMENT,
    `login`         VARCHAR(16) NOT NULL,
    `sex`           INTEGER NOT NULL,
    `old`           INTEGER NOT NULL,
    `city`          INTEGER NOT NULL,
    `nickid`        INTEGER NOT NULL,
    `niv`           INTEGER NOT NULL,
    `ok`            INTEGER NOT NULL,
    `stat`          INTEGER NOT NULL,
    `code`          INTEGER NOT NULL,
    `ISP`           INTEGER NOT NULL,
    `status`        INTEGER NOT NULL,
    `level`         INTEGER NOT NULL,
    `since`         INTEGER NOT NULL,
    `town`          INTEGER NOT NULL,
    `premimum`      INTEGER NOT NULL,
    `creation_date` DATETIME NOT NULL,
    `update_date`   DATETIME NOT NULL)
ENDTXT
    $self->dbh()->do($query);

    $query = <<ENDTXT;
    CREATE TABLE IF NOT EXISTS `ISPs` (
    `id`            INTEGER PRIMARY KEY AUTOINCREMENT,
    `name`          VARCHAR(255) UNIQUE NOT NULL)
ENDTXT
    $self->dbh()->do($query);

    $query = <<ENDTXT;
    CREATE TABLE IF NOT EXISTS `towns` (
    `id`            INTEGER PRIMARY KEY AUTOINCREMENT,
    `name`          VARCHAR(255) UNIQUE NOT NULL)
ENDTXT
    $self->dbh()->do($query);
}

##@method void insertTown($name)
#@brief Inserts a new town code in the table "towns"
#@param string An town code, i.e. "FR- Sevran"
sub insertTown {
    my ( $self, $name ) = @_;
    my $query = q/
      INSERT INTO `towns`
        (`name`) 
        VALUES
        (?);
      /;
    $self->dbh()->do( $query, undef, $name );
}

##@method void insertISP($name)
#@brief Inserts a new ISP code in the table "towns"
#@param string An ISP code, i.e. "Free SAS"
sub insertISP {
    my ( $self, $name ) = @_;
    my $query = q/
      INSERT INTO `ISPs`
        (`name`) 
        VALUES
        (?);
      /;
    $self->dbh()->do( $query, undef, $name );
}

sub insertCode {
    my ( $self, $code ) = @_;
    my $query = q/
      INSERT INTO `codes`
        (`name`) 
        VALUES
        (?);
      /;
    $self->dbh()->do( $query, undef, $code );
}

1;

