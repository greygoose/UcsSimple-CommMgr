######################################################################
package UcsSimple::Session;
######################################################################

use strict;
use warnings;

use vars qw($VERSION);

use constant DEFAULT_TIME_OUT => 600;
use constant DEFAULT_REFRESH => 300;
use Carp qw (croak cluck confess);

$VERSION = "0.0001";


# Constructor -
# Parameters:
# a hashref for the key/value pairs
#  Mandatory:
#      userName => 
#      password => 
#      uri => 
#  Optional:
#      
#      
sub new
{
    my ($aInClass, $aInRefArgs) = @_;
    my $self = {};
    bless $self, $aInClass;

    if (!exists($aInRefArgs->{'userName'}))
    {
        confess "Missing userName";
    }
    $self->userName($aInRefArgs->{userName});

    confess "Missing password" if (!exists($aInRefArgs->{'password'}));
    $self->password($aInRefArgs->{'password'});

    confess "Missing uri" if (!exists($aInRefArgs->{'uri'}));
    my $lUriString = $aInRefArgs->{'uri'};
    $self->uri($lUriString);

    $self->timeout(
        defined($aInRefArgs->{'timeout'}) ? $aInRefArgs->{'timeout'} : DEFAULT_TIME_OUT
    );

    $self->refreshPeriod(
        defined($aInRefArgs->{'refreshPeriod'}) ?  $aInRefArgs->{'refreshPeriod'} : DEFAULT_REFRESH
    );

    $self->{lastCall} = undef;

    $self->cookie(undef);

    return $self;
}

sub userName
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{userName} if @_ == 1;

    $self->{userName} = $aInVal;
    return; 
}


sub password
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{password} if @_ ==1;

    $self->{password} = $aInVal;
    return; 
}



sub cookie
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{cookie} if @_ ==1;

    $self->{cookie} = $aInVal;
    return; 
}



sub uri
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{uri} if @_ ==1;

    # Set the server and port based on uri
    $self->{uri} = $aInVal;
    my $lUri = URI->new($aInVal);
    $self->{server} = $lUri->host();
    $self->{port} = $lUri->port();
    $self->{scheme} = $lUri->scheme;
    return; 
}



sub server
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{server};
}



sub scheme
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{scheme};
}



sub port
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{port};
}



sub lastCall
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{lastCall};
}



sub timeout
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{enforceTimout} if @_ ==1;

    $self->{enforceTimeout} = $aInVal;
}



sub enforceTimeout
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{enforceTimout} if @_ ==1;

    $self->{enforceTimeout} = $aInVal;
}



sub refreshPeriod
{
    my ($self, $aInVal) = @_;
    ref ($self) or confess "Instance required";

    return $self->{refreshPeriod};
}



sub toDebugString
{
    my $lDebugString = "";
    my ($self) = @_;
    ref ($self) or confess "Instance required";
   
    $lDebugString .= "userName: " . $self->userName();
    $lDebugString .= "\n";
    $lDebugString .= "cookie: " . $self->cookie();
    $lDebugString .= "\n";
    $lDebugString .= "uri: " . $self->uri();
    $lDebugString .= "\n";
    $lDebugString .= "userName: " . $self->userName();
    $lDebugString .= "\n";
    $lDebugString .= "cookie: " . $self->cookie();
    $lDebugString .= "\n";
    $lDebugString .= "server: " . $self->server();
    $lDebugString .= "\n";
    $lDebugString .= "scheme: " . $self->scheme();
    $lDebugString .= "\n";
    $lDebugString .= "port: " . $self->port();
    $lDebugString .= "\n";
    $lDebugString .= "enforceTimeout: " . $self->enforceTimeout();
    $lDebugString .= "\n";
    $lDebugString .= "refreshPeriod: " . $self->refreshPeriod();
    $lDebugString .= "\n";
    $lDebugString .= "timeout: " . $self->timeout();
    $lDebugString .= "\n";
    $lDebugString .= "lastCall: " . $self->lastCall();
    $lDebugString .= "\n";

    return $lDebugString;
}



# Returns undef if cookie is not valid
sub cookieValid
{
    my ($self, $aInTime) = @_;
    ref ($self) or confess "Instance required";

    my $lValid = undef;
   if (undef($aInTime))
   {
      $aInTime = getTime();
   }

   

}


1;


__END__


=head1 NAME

UcsSimple::Session - wrapper around a UCS communication session.

=head1 SYNOPSIS

Provides a wrapper around UCS session details.

    use UcsSimple::CommMgr;
    use UcsSimple::Session;

    my $lSession = UCS::Session->new(
        { userName => $lUname, password => $lPasswd, uri => $lUri }
    );

    $lCommMgr = UCS::CommMgr->new({session => $lSession});
    my $lCookie = $lCommMgr->doLogin();
    croak "Failed to get cookie" if (!defined $lCookie);


=head1 SUBROUTINES/METHODS

=head2 new

Constructor - a reference to a hash.
Mandatory arguments: username, password, uri.


=head2 toDebugString

Stringify the object's properties for debug purposes.


=head2 cookieValid

Return undef if the cookie is not valid (Do not use).


=head2 userName

Sets username if value passed.  Returns the username property value.


=head2 password

Sets password if value passed.  Returns the password property value.


=head2 cookie

Sets cookie if value passed.  Returns the cookie property value.


=head2 uri

Sets uri if value passed.  Returns the uri property value.


=head2 server

Get the server property value (from uri).


=head2 scheme

Get the scheme property value (from uri).


=head2 port

Get the port property value (from uri).


=head2 enforceTimeout

Sets enforceTimeout property if value passed otherwise returns the property value.



=head2 lastCall 

Gets lastCall property if value. 



=head2 timeout

Sets enforceTimeout property if value passed otherwise returns the property value.


=head2 refreshPeriod

Sets erefreshPeriod property if value passed otherwise returns the property value.



=head1 AUTHOR

Ike Kent, C<< <ikent at cisco.com> >>



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc UcsSimple::Session



=head1 LICENSE AND COPYRIGHT

Copyright 2013 Ike Kent.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut


