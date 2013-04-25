######################################################################
package UcsSimple::EventUtil;
######################################################################
use strict;
use warnings;


use Exporter;
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

use UcsSimple::Util;
use URI;
use Carp qw(croak cluck confess);

@ISA    = qw( Exporter );
@EXPORT_OK = qw( getEventHandler );
$VERSION = "0.0001";



# Get an event handler method.  
# It is useful for handling the http(s) chunked data details of UCS.
# Pass in a method to be called when a full event is received.
sub getEventHandler
{
    my ($aInCb) = @_;
    
    if (!defined($aInCb))
    {
        confess "Missing mandatory cb method"
    }

    my $lEventCount = 0;
    my $lCurrentEvent = "";
    my $lExpEventSize = 0;

    my $lCombineEventCb =
    sub
    {
        my ($aInResp, $aInUserAgent, $aInH, $aInData) = @_;
        $lEventCount += 1;
        if (defined($aInData))
        {
            # An integer by itself will be the event size
            my $lIsEvent = 1;
            my $lNumLength = length($aInData);
            if ($lNumLength < 20)
            {
                my $lData = $aInData;
                $lData =~ s/^\s+//;
                $lData =~ s/\s+$//;
                if (UcsSimple::Util::is_integer $lData )
                {
                    $lExpEventSize = $lData;
                    # print "got event size (" .  $lExpEventSize . ")\n";
                    $lCurrentEvent = "";
                    $lIsEvent = 0;
                 }
            }
            if ($lIsEvent)
            {
                 $lCurrentEvent .= $aInData;
                 my $lEventLength = length($lCurrentEvent);
                 my $lFull = ($lEventLength >= $lExpEventSize) ? 1 : 0;
                 # print "(exp=" . $lExpEventSize . ")(" . $lEventLength . ")(full=" . $lFull . ")\n";

                 if ($lFull)
                 {
                     & $aInCb($lCurrentEvent);
                     # print $lCurrentEvent  . "\n\n";
                     $lCurrentEvent = "";
                     # We have a full event, combine it
                 }
                 else
                 {
                     # print $aInData;
                 }
            }
        }
        return 1;
    };
    return $lCombineEventCb;
}


1; # package return code


__END__


=head1 NAME

UcsSimple::EventUtil - simple event handler to register for UCS events.


=head1 SYNOPSIS

A simple event handler to register for UCS events. Call-backs will occur
once all chunks of a UCS message have been assembled.


    use UcsSimple::EventUtil;

    my $lSession = UcsSimple::Session->new(
        {userName => $lUname, password => $lPasswd, uri => $lUri });

    $lCommMgr = UcsSimple::CommMgr->new({session => $lSession});

    my $lCookie = $lCommMgr->doLogin();
    croak "Failed to get cookie" if (!defined $lCookie);

    $lCommMgr->doSubscribe({eventCb => UcsSimple::EventUtil::getEventHandler(\&printCb)});

    ...


=head1 SEE ALSO
See UcsSimple::CommMgr for how to get chunk call-backs.


=head1 SUBROUTINES/METHODS

=head2 getEventHandler($aInCb)

Get an event handleri that will call the passed function reference.


=head1 AUTHOR

Ike Kent, C<< <ikent at cisco.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc UcsSimple::EventUtil


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Ike Kent.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut




