######################################################################
package UcsSimple::CommMgr;
######################################################################
use strict;
use warnings;

use vars qw ($VERSION);
$VERSION = "0.0001"; 


use LWP;
use Carp qw(cluck croak confess);
use Data::Dumper;
use XML::Simple;
use XML::Handler::YAWriter;
use Log::Log4perl qw (get_logger);
use Mozilla::CA qw(SSL_ca_file SSL_ca_path);

use UcsSimple::DomUtil;
use UcsSimple::XmlUtil;



# Constructor -
# Parameters:
# a hashref for the key/value pairs
#  Mandatory:
#      session =>
sub new
{
    my ($aInClass, $aInRefArgs) = @_;
    my $self = {};
    bless $self, $aInClass;
    if (!exists($aInRefArgs->{'session'}))
    {
        confess "Missing session";
    }
    $self->session($aInRefArgs->{session});

    if (!exists($aInRefArgs->{'ssl_opts'}))
    {
        confess "You must provide ssl opts (you can pass no_verify for no certificate validation)";
    }

    # Simple processing of ssl options
    my $lSslOptsRef = $aInRefArgs->{'ssl_opts'};

    if (exists($lSslOptsRef->{'no_verify'})  && 
       ($lSslOptsRef->{'no_verify'}))
    {
        $self->{userAgent} = LWP::UserAgent->new(SSL_verify_mode => 0x00);
        $self->{userAgent}->ssl_opts( SSL_verify_mode => 0x00 );
        $self->{userAgent}->ssl_opts( verify_hostname => 0 );
    }
    else
    {
        $self->{userAgent} = LWP::UserAgent->new();
        foreach my $lKey (keys %{$lSslOptsRef})
        {        
            $self->{userAgent}->ssl_opts( $lKey => $lSslOptsRef->{$lKey});

            get_logger(__PACKAGE__)->info(
                qq(Setting ssl option  "$lKey" to  "$lSslOptsRef->{$lKey}" ));
        }
    }

    $self->{userAgent}->timeout(6000);

    return $self;
}



sub userAgent
{
    my ($self, $aInSession) = @_;
    ref($self) or confess "Instance required";
    return $self->{'userAgent'}
}



sub session
{
    my ($self, $aInSession) = @_;
    ref($self) or confess "Instance required";
    if (defined($aInSession))
    {
        $self->{'session'} = $aInSession;
    }
    return $self->{'session'}
}



sub resolveDn
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveDnXml($aInRefArgs);

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



sub resolveClass
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveClassXml($aInRefArgs);

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



sub resolveClasses
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveClassesXml($aInRefArgs);

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



sub resolveDns
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveDnsXml($aInRefArgs);

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



sub estimateImpact
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    if (!exists($aInRefArgs->{'xmlDoc'}))
    {
        print "Missing mandatory argument: xmlDoc";
    }
    my $lDocRef= $aInRefArgs->{'xmlDoc'};

    my $lEstimateDoc = UcsSimple::DomUtil::getEstimateImpact($lDocRef);
    my $lXmlRequest = $lEstimateDoc->toString();

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



sub findDependencies
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    my $lXmlRequest = UcsSimple::XmlUtil::getFindDepXml($aInRefArgs);

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



sub resolveChildren
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveChildrenXml($aInRefArgs);

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



sub scope
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    my $lXmlRequest = UcsSimple::XmlUtil::getScopeXml($aInRefArgs);

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



sub deleteMo
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    my $lDelXml = UcsSimple::XmlUtil::getDeleteXml($aInRefArgs);

    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lDelXml});

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return ($lSuccess ? $lContent : undef);
}



# Returns undef if login fails
sub doLogin
{
    my ($self) = @_;
    ref($self) or confess "Instance required";

    my $lXmlRequest = UcsSimple::XmlUtil::getLoginXml(
    {
        name => $self->session()->userName(), 
        password => $self->session()->password(),
        cookie => $self->session()->cookie()
    });

    my $lCookie = undef;
    my ($lSuccess, $lContent, $lErrHashRef) =
        $self->doPostXML({postData => $lXmlRequest});

    if ($lSuccess)
    {
        eval {
            my $lParser = XML::Simple->new();
            my $lConfig = $lParser->XMLin($lContent);
            $lCookie = $lConfig->{'outCookie'};
            $lCookie = undef if ($lCookie && $lCookie eq "");
        };
    }

    get_logger(__PACKAGE__)->info(
        (defined($lCookie) ? 
            "Cookie: $lCookie" : 
            "Failed to get cookie!")
    );

    if (defined($lCookie))
    {   
        $self->session()->cookie($lCookie);
    }

    return $lCookie;
}



# Returns undef if it fails.
sub doRefresh
{
    my ($self) = @_;
    my $lXmlRequest = UcsSimple::XmlUtil::getLoginXml(
    { 
        name => $self->session()->userName(), 
        password => $self->session()->password(),
        cookie => $self->session()->cookie()
    });

    my $lCookie = undef;
    my ($lSuccess, $lContent, $lErrHashRef) =
        doPostXML({postData => $lXmlRequest});

    if ($lSuccess)
    {
        eval {
            my $lParser = XML::Simple->new();
            my $lConfig = $lParser->XMLin($lContent);
            $lCookie = $lConfig->{'outCookie'};
            $lCookie = undef if ($lCookie && $lCookie eq "");
        };
    }

    get_logger(__PACKAGE__)->info(
        (defined($lCookie) ? 
            "Cookie: $lCookie" : 
            "Failed to get cookie!")
    );

   return $lCookie;
}



# Returns undef if it fails.
sub doLogout
{
    my ($self) = @_;

    my $lCookie = $self->session()->cookie();
    my $lXmlRequest = UcsSimple::XmlUtil::getLogoutXml(
        { cookie => $self->session()->cookie() }
    );

    my $lSuccess = undef;
    my $lContent = undef;
    my $lErrHashRef = undef;
    my $lResult = undef;

    if (defined($lCookie))
    {
        my ($lSuccess, $lContent, $lErrHashRef) =
            $self->doPostXML({ postData => $lXmlRequest});

        $lResult = $lSuccess ? 1 : undef;

        get_logger(__PACKAGE__)->warn(
            (($lResult) ? 
                "Logout success : $lCookie" :
                "Logout failed  : $lCookie")
        );
    }
    else
    {
        get_logger(__PACKAGE__)->warn("Skipping logout - no cookie");
    }

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return $lResult;
}



# You should take the array of results as follows:
#   ($lSuccess, $lResp->content, $lErrHashRef, $lResp->status_line)
# Else
#   the xml on success or undef on failure
#
# Parameters:
# a hashref for the key/value pairs
#  Mandatory:
#      postData => data to post 
#  Optional:
#
sub doPostXML
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";
   
    if (!exists($aInRefArgs->{'postData'})) 
    {
        confess "No data to post";
    }

    my $aInPostData = $aInRefArgs->{'postData'};
    my $lCookie = $self->session()->cookie();
    if (defined($lCookie))
    {
        $aInPostData =~ s/cookie=\"(.*?)\"/cookie=\"$lCookie\"/;
    }

    my $lRequest = HTTP::Request->new(POST => $self->session()->uri());
    $lRequest->content_type("application/x-www-form-urlencoded");
    $lRequest->content($aInPostData);

    get_logger(__PACKAGE__)->trace(
        "Request Headers : \n" .
         Dumper($lRequest->headers()));

    my $lNoPass = $lRequest->as_string();
    $lNoPass =~ s/inPassword\s*=\s*\"(.*?)\"/inPassword=""/gi; 

    get_logger(__PACKAGE__)->debug(
        "Request : \n" .
        $lNoPass);

    # HTTP:: Our response object
    my $lResp = $self->userAgent->request($lRequest);
    my $lUcsRespValid = undef;
    my $lErrHashRef = undef;

    if ($lResp->is_success)
    {
        ($lUcsRespValid, $lErrHashRef) = 
            UcsSimple::XmlUtil::checkUcsResponse($lResp->content);
    }

    get_logger(__PACKAGE__)->trace(
        "Response Headers: \n" . 
         Dumper($lResp->headers()));

    get_logger(__PACKAGE__)->debug(
         "Response : \n" . 
         $lResp->content());

    return ($lUcsRespValid, $lResp->content, $lErrHashRef, $lResp->status_line) if wantarray;

    if (defined($lUcsRespValid))
    {
        return $lResp->content; 
    }
    return $lUcsRespValid;
}



# You should take the array of results as follows:
# blocking
#
sub doSubscribe
{
    my ($self, $aInRefArgs) = @_;
    ref($self) or confess "Instance required";

    if (!exists($aInRefArgs->{'eventCb'})) 
    {
        confess "No event call-back method";
    }
    my $lEventCb = $aInRefArgs->{'eventCb'}; 
    my $aInPostData = $aInRefArgs->{'postData'};

    my $lSubXml = UcsSimple::XmlUtil::getSubscribeXml(
        {'cookie' => $self->session()->cookie()});
  
    my $lRequest = HTTP::Request->new(POST => $self->session()->uri());
    $lRequest->content_type("application/x-www-form-urlencoded");
    $lRequest->content($lSubXml);

    $self->userAgent()->add_handler(
        response_data => $lEventCb,
    );

    get_logger(__PACKAGE__)->trace(
        "Request Headers : \n" .
         Dumper($lRequest->headers()));

    get_logger(__PACKAGE__)->debug(
        "Request : \n" .
        $lRequest->as_string());

    my $lResp = $self->userAgent->request($lRequest);

    $self->userAgent()->remove_handler(
        response_data => $lEventCb,
    );

    get_logger(__PACKAGE__)->debug(
         "Event channel done: \n" . 
         $lResp->content());

    return;
}

1;


__END__



=head1 NAME

UcsSimple::CommMgr - simplify, encapsulate and abstract UCS communication details.

=head1 SYNOPSIS

A simple module to handle communication with UCS. 
For example, to login and get a list of all instances of lsServer:


    use UcsSimple::CommMgr;
    use UcsSimple::Session;

    my $lSession = UcsSimple::Session->new(
        { userName => $lUname, password => $lPasswd, uri => $lUri }
    );

    $lCommMgr = UcsSimple::CommMgr->new({session => $lSession});
    my $lCookie = $lCommMgr->doLogin();
    croak "Failed to get cookie" if (!defined $lCookie);

    ($lSuccess, $lXmlResp, $lErrHashRef) =
        $lCommMgr->resolveClass({ class => "lsServer", hier => 1 });

    ...

    $lCommMgr->doLogout();


=head1 SUBROUTINES/METHODS

=head2 new 

Constructor - a reference to a hash.
Mandatory arguments: session - a UcsSimple::Session

=head2 userAgent

return the contained LWP::UserAgent.

=head2 resolveDn

Call UCS to resolve the passed dn 

    my $lDn = "org-root";
    my $lHier = 1;
    my ($lSuccess, $lXmlResp, $lErrHashRef) =
        $lCommMgr->resolveDn({ dn => $lDn, hier => $lHier });



=head2 resolveClass

Call UCS to get all instances of the passed class

    my $lClass = "lsServer";
    my $lHier = 1;
    ($lSuccess, $lXmlResp, $lErrHashRef) =
        $lCommMgr->resolveClass({ class => $lClass, hier => $lHier });

=head2 findDependencies

Call UCS to get all policies dependent on the identified policy


=head2 scope

A scope (search subtree for instances of named class) query.

    my $lClass = "faultInst";
    my $lDn = "sys/chassis-1/blade-4";
    my $lHier = 1;
    my ($lSuccess, $lXmlResp, $lErrHashRef) =
        $lCommMgr->scope({ dn => $lDn, class => $lClass, hier => $lHier });


=head2 doLogin

Login to the UCS system


=head2 doRefresh

Refresh the UCS token


=head2 doLogout

Logout from the UCS system


=head2 doPostXML

Post XML to UCS system


=head2 doSubscribe

Subscribe to UCS event channel.

    # Have method printCb called when events received
    $lCommMgr->doSubscribe({eventCb => UcsSimple::EventUtil::getEventHandler(\&printCb)});


=head1 AUTHOR

Ike Kent, C<< <ikent at cisco.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc UcsSimple::CommMgr


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Ike Kent.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut




