######################################################################
package UcsSimple::Util;
######################################################################
use strict;
use warnings;

use vars qw($VERSION);

use Math::Int64 qw( uint64 hex_to_uint64 uint64_to_hex uint64_to_string);
use Carp qw(croak confess cluck);

$VERSION = "0.0001";


sub get_uint64
{
    my ($aInStr) = @_;
    return uint64($aInStr); 
}



sub macToLong
{
    my ($aInMacStr) = @_;
    $aInMacStr =~ s/://g;
    my $lBigInt = hex_to_uint64($aInMacStr);
    return $lBigInt;
}



sub longToMac
{
    my ($aInMacNum) = @_;

    my @lMacBytes = ();
    for my $i (1..6)
    {
        unshift(@lMacBytes, sprintf("%02X", $aInMacNum % (2**8)));
        $aInMacNum = int($aInMacNum / (2**8));
    }
    return join(':', @lMacBytes);
}



# Takes prefix or suffix (64 bits)
sub uuidToLong
{
    my ($aInUuidStr) = @_;
    $aInUuidStr =~ s/-//g;
    my $lBigInt = hex_to_uint64($aInUuidStr);

    #print "uuidToLong($aInUuidStr)($lBigInt)\n";
    return $lBigInt;
}



sub longToUuid
{
    my ($aInUuidBigInt) = @_;

    my $lTmpString = uint64_to_string($aInUuidBigInt, 16); 

    my $lLead = 16 - length $lTmpString; 
    my $lUuidString = ('0' x $lLead) . $lTmpString;
 
    $lUuidString = substr ($lUuidString, 0, 4) . "-" . substr ($lUuidString, 4, 12);

    #print "longToUuid($aInUuidBigInt)($lUuidString)\n";

    return $lUuidString;
}



# wwn to long
sub wwnToLong
{
    my ($aInWwnStr) = @_;
    $aInWwnStr =~ s/://g;
    my $lBigInt = hex_to_uint64($aInWwnStr);
    return $lBigInt;
}



# wwn to long
sub longToWwn
{
    my ($aInWwnBigInt) = @_;
    my $lTmpString = uint64_to_string($aInWwnBigInt, 16); 

    my $lLead = 16 - length $lTmpString; 
    $lTmpString = ('0' x $lLead) . $lTmpString;
    my $lWwnString = "";

    for my $i (0..7)
    {
        $lWwnString .= substr ($lTmpString, (2*$i), 2); 
	if ($i != 7)
	{
            $lWwnString .= ":";
        }
    }
    return $lWwnString;
}



sub ipToInt
{
    my $aInIpStr = shift;
    my $lIpNumber = 0;
    my @lOctets = split (/\./, $aInIpStr);
    foreach my $lOctet (@lOctets)
    {
        $lIpNumber <<=8;
        $lIpNumber |= $lOctet;
    }
    return $lIpNumber;
}

sub intToIp
{
    my ($aInIpInt) = @_;
    my $lIpString = "";

    for my $i (1..4)
    {
        my $lQuad = $aInIpInt % 256;
        $aInIpInt = $aInIpInt / 256;
        if ($i != 1)
	{
            $lIpString = '.' . $lIpString;
        }
        $lIpString = $lQuad . $lIpString;
    }
    return $lIpString;
}



sub getDate
{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    $year += 1900;
    $mon += 1;
    my $lDateTime = sprintf "%04d-%02d-%02d-%02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
    return $lDateTime
}



sub getIndent
{
    my $aInNum = shift; 
    return ' ' x $aInNum;
}



sub is_integer
{
    defined $_[0] && $_[0] =~ /^\d+$/;
}



sub getPad
{
    my ($aInStr, $aInLen) = @_;
    my $lPad = "";

    if (!defined($aInStr))
    {
         $aInStr = "";
    }

    if (defined($aInLen) &&
       (length($aInStr) < $aInLen))
    {
        my $lNumChars = $aInLen - length($aInStr);
        for my $i (0..($lNumChars - 1))
        {
            $lPad .= " ";
        }
    }
    #print qw([$aInStr][$aInLen]);
    return $aInStr . $lPad;
}



sub promptUser {

    my ($promptString, $echoOff, $defaultValue) = @_;

    if ($defaultValue) {
        print $promptString, "[", $defaultValue, "]: ";
    } 
    else 
    {
        print $promptString, ": ";
    }

    $| = 1;               # force a flush after our print

    if ($echoOff)
    {
        ReadMode('noecho');  # Don't echo
    }

    $_ = <STDIN>;         # get the input from STDIN (presumably the keyboard)

    if ($echoOff)
    {
        ReadMode(0);
        print "\n";
    }

    chomp;

    if ($defaultValue) 
    {
        return $_ ? $_ : $defaultValue;    # return $_ if it has a value
    } 
    else 
    {
        return $_;
    }
}


# Get field widths for a table based on largest entry for each column.
# rows - ref to array of maps.  One map for each row with property name as key
# headings - (parallel) reference to array property headings
sub getFieldWidths
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'rows'}))
    {
        confess "Missing mandator argument: rows";
    }
    my $aInRows = $aInRefArgs->{'rows'};

    if (!exists($aInRefArgs->{'headings'}))
    {
        confess "Missing mandator argument: headings";
    }
    my $aInHeadings = $aInRefArgs->{'headings'};

    my $lFieldWidths = [];

    # Go through every attribute of each class that we have to print out and determine its fieldwidth
    my $lRowNum = 0;

    # Get width of headings (even if no rows of data)
    for my $lIdx (0..(@{$aInHeadings} -1))
    {
        my $lHeading = $aInHeadings->[$lIdx];
        $lFieldWidths->[$lIdx] = length($lHeading);
    }

    # Get width of longest field entry
    foreach my $lRow (@{$aInRows})
    {
        if (@{$lRow} != (@{$aInHeadings}))
        {
            confess "Number of columns not equal to number of headings";
        }
        for my $lIdx (0..(@{$lRow} -1))
        {
            my $lValue = $lRow->[$lIdx];
            my $lCurrLength = (defined($lValue)) ? length ($lValue) : 0;
            my $lMaxLength = $lFieldWidths->[$lIdx];
            $lFieldWidths->[$lIdx] = ($lCurrLength > $lMaxLength) ?
                $lCurrLength : $lMaxLength;
        }
    }

    return $lFieldWidths;
}


# Print a table
# rows - ref to array of maps.  One map for each row with property name as key.
# headings - (parallel) reference to array property headings.
# fieldWidths - (optional) ref to a map indexed by property name with values the width of the field.
sub printTable
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'rows'}))
    {
        confess "Missing mandator argument: rows";
    }
    my $aInRows = $aInRefArgs->{'rows'};

    if (!exists($aInRefArgs->{'headings'}))
    {
        confess "Missing mandator argument: headings";
    }
    my $aInHeadings = $aInRefArgs->{'headings'};

    my $lFw;
    if (!exists($aInRefArgs->{'fieldWidths'}))
    {
        $lFw = getFieldWidths({
            rows => $aInRows,
            headings => $aInHeadings,
        });
    }
    else
    {
        $lFw = $aInRefArgs->{'fieldWidths'};
    }

    for my $lIdx (0..(@{$aInHeadings} -1))
    {
        print UcsSimple::Util::getPad($aInHeadings->[$lIdx], $lFw->[$lIdx]);
        print "   ";
    }
    print "\n";

    # Print out table row by row
    my $lRowNum = 0;
    foreach my $lRow (@{$aInRows})
    {
        if (@{$lRow} != (@{$aInHeadings}))
        {
            confess "Number of columns not equal to number of headings";
        }

        for my $lIdx (0..(@{$lRow} -1))
        {
            my $lValue = $lRow->[$lIdx];
            print UcsSimple::Util::getPad($lRow->[$lIdx], $lFw->[$lIdx]);
            print "   ";
         }
         print "\n";
    }
}



1; 


__END__


=head1 NAME

UcsSimple::Util - The great new UcsSimple::Util!

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use UcsSimple::Util;

    my $foo = UcsSimple::Util->new();
    ...


=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.


=head1 SUBROUTINES/METHODS


=head2 is_integer

Return true if passed string is an integer.



=head2 get_uint64

Get a 64 bit int for the passed string. Simple wrapper around Math::Int64 method.



=head2 macToLong

Convert mac address to a 64 bit long.



=head2 longToMac

Convert 64 bit long to a string mac address.



=head2 uuidToLong

Convert uuid to a 64 bit long.



=head2 longToUuid

Convert 64 bit long to a string uuid address.




=head2 wwnToLong

Convert wwn to a 64 bit long.



=head2 longToWwn

Convert 64 bit long to a string wwn address.




=head2 ipToInt

Convert ip to an int.



=head2 intToIp

Convert an int to a string ip (dotted quad).




=head2 getDate

Get a string version of a date.




=head2 getIndent

Get n ' ' characters 

    getIndent(5);




=head2 getPad

Get ' ' characters required to pad a string to the passed length.
The following code would return a string of 5 spaces.

    getPad("Hello", 10);



=head2 promptUser

Prompt the user with the passed string.  For example, prompt user with echo off and 
default value of "y".

    prompUser("Enter y to continue", 1, "y");




=head2 uuidToLong

Convert uuid to a 64 bit long.



=head2 longToUuid

Convert 64 bit long to a string uuid address.



=head2 getFieldWidths

Get field widths for a table based on largest entry for each column.
The rows parameter is a reference to an array of arrays (one for each row).
The headings parameter is a parallel references to the headings.

    getFieldWidths({
        rows => [ [0030], [0045] ],
        headings => ["Fault Codes"]
    });


=head2 printTable

Print a table with the passed arguments.  
The rows parameter is a reference to an array of arrays (one for each row).
The parameter is a parallel references to the headings.
The fieldwidths is an (optional) parallel reference to the width of each column.  

    UcsSimple::Util::printTable(
    {
        rows => [ [0030], [0045] ],
        headings => ["Fault Codes"]
    });


=head1 AUTHOR

Ike Kent, C<< <ikent at cisco.com> >>



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc UcsSimple::Util



=head1 LICENSE AND COPYRIGHT

Copyright 2013 Ike Kent.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.



=cut




