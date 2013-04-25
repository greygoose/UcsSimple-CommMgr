######################################################################
package UcsSimple::XmlUtil;
######################################################################
use strict;
use warnings;

use Exporter;
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

$VERSION = "0.0001";

use Carp qw(croak confess cluck);
use XML::Simple;
use XML::Parser::PerlSAX;
use XML::Handler::YAWriter;
use UcsSimple::Util;

@ISA    = qw(Exporter);

@EXPORT_OK = qw(
    &prettyPrint
    &printResponse
    &checkUcsResponse
    &getLoginXml
    &getLogoutXml
    &getRefreshXml
    &getScopeXml
    &getResolveDnXml
    &getFindDepXml
    &getResolveClassXml
    &getResolveClassesXml
    &getResolveChildrenXml
    &getComputeLcXml
    &getConfMoXml
    &getDeleteXml
    &getDeleteManyXml
    &getSubscribeXml
    &getEstimateImpactXml
);



#
# Pretty print the xml to passed stream.
# If no stream passed, returns pretty printed document.
# Parameters:
# a hashref for the key/value pairs
#  Mandatory:
#      xmlDoc => reference to document to pretty print
#  Optional:
#      stream => file handle to print to
sub prettyPrint
{
    my ($aInArrayRef) = @_;
  
    if (!exists($aInArrayRef->{'xmlDoc'}))
    {
        print "Missing mandatory argument: xmlDoc";
    }
    my $lXmlRef = $aInArrayRef->{'xmlDoc'};

    my $lStream = 
       exists($aInArrayRef->{'stream'}) ?
           $aInArrayRef->{'stream'} : undef;

    my $lPrettyXml = undef;
    eval {
        my $ya = new XML::Handler::YAWriter(
            'Pretty' =>  {
                'PrettyWhiteIndent' => 1,
                'PrettyWhiteNewline' => 1,
            }
        );
        my $perlsax = new XML::Parser::PerlSAX( 'Handler' => $ya );
        $perlsax->parse($$lXmlRef);
        $lPrettyXml = join('', @{$ya->{Strings}});
    };
     cluck "Could not pretty print - perhaps ill-formed document?: " . $@ if ($@);

    if ($lStream)
    {
        if (defined($lPrettyXml))
        {
            print $lStream $lPrettyXml;
            return "true";
        }
        else
        {
            cluck "Could not pretty print - perhaps ill-formed document?";
            return undef;
        }
    }
    else
    {
        return $lPrettyXml;
    }
}



# Parameters:
# a hashref for the key/value pairs
#  Mandatory:
#      success => result of method
#      xmlDoc => reference to ucs xml response.
#  Optional:
#      errorHash => hash containing error info
#      stream => file handle to print to 
sub printResponse
{
    my ($aInArrayRef) = @_;

    if (!exists($aInArrayRef->{'success'}))
    {
        print "Missing mandatory argument: success";
    }
    if (!exists($aInArrayRef->{'xmlDoc'}))
    {
        confess "Missing mandatory argument: xmlDoc";
    }
    my $lSuccess = $aInArrayRef->{'success'};
    my $lXmlRef = $aInArrayRef->{'xmlDoc'};
    my $lErrorHash = $aInArrayRef->{'errorHash'};

    my $lStream = exists($aInArrayRef->{'stream'}) ?
        $aInArrayRef->{'stream'} : (*STDOUT);

    my $lPretty = $aInArrayRef->{'pretty'};

    my $lMaxLen = undef;
    if (defined($aInArrayRef->{'maxLength'}) and 
       UcsSimple::Util::is_integer($aInArrayRef->{'maxLength'}))
    {
        $lMaxLen = $aInArrayRef->{'maxLength'};
    }

    if ($lSuccess)
    {
        if ($lPretty)
        {
           UcsSimple::XmlUtil::prettyPrint({
               xmlDoc => $lXmlRef,
               stream => $lStream});
        }
        else
        {
           # No pretty print - but, may wish brief output (grab substring)
           my $lOutXml = undef;
           if (defined($lMaxLen))
           {
               $lOutXml = substr($$lXmlRef, 0, $lMaxLen);
           }
           print $lStream "\n" . 
               (defined($lOutXml) ? $lOutXml : $$lXmlRef) . "\n";
        }
    }
    else
    {
        # Response is an error, print error information
        print ($lStream, "\nError:\n");
        foreach my $lKey (%{$lErrorHash}) 
        { 
            print ($lStream, "\n" . $lKey . " = " . $lErrorHash->{$lKey} . "\n");
        }
        print ($lStream, "\n" . $$lXmlRef . "\n");
    }
}



sub checkUcsResponse
{
    my ($lResp) = @_;

    # We look at the response for error information;
    # Check if valid xml is returned and it is a response;
    # Check if the response is an error - error element;
    #
    # <configConfMos cookie="1355508269/9a2a9778-40a7-4f89-a91c-d6ea0ded4c11"
    #     response="yes" errorCode="150" invocationResult="unidentified-fail"
    #     errorDescr="block definition is too large. Size cannot exceed 1000.">
    # </configConfMos>
    #
    # <error cookie="" response="yes" errorCode="ERR-xml-parse-error"
    #     invocationResult="594"
    #     errorDescr="XML PARSING ERROR: unknown attribute &apos;dn&apos; in element &apos;pair&apos;"/>
    #
    my $lUcsError = undef;
    my $lValidXmlResp = undef;
    my $lErrorHashRef = {};

    eval {
            my $lParser = XML::Simple->new();
            my $lConfig = $lParser->XMLin($lResp);

            # XML Sanity check - make sure it has response="yes"
            my $lIsResp = $lConfig->{'response'};
            if (defined($lIsResp) and ($lIsResp eq "yes"))
            {
                $lValidXmlResp = "true";
            }
            # Grab any xml error information
            if ($lValidXmlResp)
            {
                if (exists($lConfig->{'errorDescr'}))
                {
                    $lErrorHashRef->{'errorDescr'} = $lConfig->{'errorDescr'};
                    $lUcsError = "true";
                }
                if (exists($lConfig->{'errorCode'}))
                {
                    $lErrorHashRef->{'errorCode'} = $lConfig->{'errorCode'};
                    $lUcsError = "true";
                }
                if (exists($lConfig->{'invocationResult'}))
                {
                    $lErrorHashRef->{'invocationResult'} = $lConfig->{'invocationResult'};
                    $lUcsError = "true";
                }
            }
    };
    my $lSuccess = $lValidXmlResp and undef($lUcsError);
    #print "Check ucs response returning : ($lValidXmlResp) ($lUcsError)(success=$lSuccess)";

    return ($lSuccess, $lErrorHashRef);
}


sub getLoginXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'name'}))
    {
        croak "Missing mandatory argument: name\n";
    }
    my $aInName = $aInRefArgs->{'name'};

    if (!exists($aInRefArgs->{'password'}))
    {
        croak "Missing mandatory argument: password\n";
    }
    my $aInPass = $aInRefArgs->{'password'};

    my $lXmlRequest = qq(<aaaLogin inName="$aInName" inPassword="$aInPass"/>);

    return $lXmlRequest;
}


sub getLogoutXml
{
    my ($aInRefArgs) = @_;
    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $lXmlRequest = qq(<aaaLogout inCookie="$aInCookie"/>);

    return $lXmlRequest;
}


sub getRefreshXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'name'}))
    {
        croak "Missing mandatory argument: name\n";
    }
    my $aInName = $aInRefArgs->{'name'};

    if (!exists($aInRefArgs->{'password'}))
    {
        croak "Missing mandatory argument: password\n";
    }
    my $aInPass = $aInRefArgs->{'password'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $lXmlRequest = qq(<aaaRefresh inName="$aInName" inPassword="$aInPass" inCookie="$aInCookie"/>);

    return $lXmlRequest;
}


sub getScopeXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'dn'}))
    {
        croak "Missing mandatory argument: dn\n";
    }
    my $aInDn = $aInRefArgs->{'dn'};

    if (!exists($aInRefArgs->{'class'}))
    {
        croak "Missing mandatory argument: class\n";
    }
    my $aInClass = $aInRefArgs->{'class'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $aInHier = "false";
    if (exists($aInRefArgs->{'hier'}) and
       ($aInRefArgs->{'hier'}))
    {
        $aInHier = "true";
    }

    my $lXmlRequest = qq(<configScope cookie="$aInCookie" dn="$aInDn" inClass="$aInClass" inHierarchical="$aInHier"/>);

    return $lXmlRequest;
}


sub getResolveDnXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'dn'}))
    {
        croak "Missing mandatory argument: dn\n";
    }
    my $aInDn = $aInRefArgs->{'dn'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $aInHier = "false";
    if (exists($aInRefArgs->{'hier'}) and
       ($aInRefArgs->{'hier'}))
    {
        $aInHier = "true";
    }

    my $lXmlRequest = qq(<configResolveDn cookie="$aInCookie" dn="$aInDn" inHierarchical="$aInHier"/>);

    return $lXmlRequest;
}



sub getFindDepXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'dn'}))
    {
        croak "Missing mandatory argument: dn\n";
    }
    my $aInDn = $aInRefArgs->{'dn'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $lXmlRequest = qq(<configFindDependencies cookie="$aInCookie" dn="$aInDn" inReturnConfigs="true"/>);

    return $lXmlRequest;
}



sub getResolveClassXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'class'}))
    {
        croak "Missing mandatory argument: class\n";
    }
    my $aInClass = $aInRefArgs->{'class'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $aInHier = "false";
    if (exists($aInRefArgs->{'hier'}) and
       ($aInRefArgs->{'hier'}))
    {
        $aInHier = "true";
    }

    my $lXmlRequest = qq(<configResolveClass cookie="$aInCookie" classId="$aInClass" inHierarchical="$aInHier"/>);

    return $lXmlRequest;
}



sub getResolveClassesXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'class'}))
    {
        croak "Missing mandatory argument: class\n";
    }
    my $aInClass = $aInRefArgs->{'class'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $aInHier = "false";
    if (exists($aInRefArgs->{'hier'}) and
       ($aInRefArgs->{'hier'}))
    {
        $aInHier = "true";
    }

    my $lXmlRequest = qq(<configResolveClasses cookie="$aInCookie" inHierarchical="$aInHier">);
    $lXmlRequest .= qq(<inIds>);
    for $lClass in (@{$aInClasses})
    {
        $lXmlRequest .= qq(<classId value="$lClass">);
    }
    $lXmlRequest .= qq(</inIds>);
    my $lXmlRequest = qq(</configResolveClasses>);

    return $lXmlRequest;
}



sub getResolveChildrenXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'dn'}))
    {
        croak "Missing mandatory argument: dn\n";
    }
    my $aInDn = $aInRefArgs->{'dn'};

    my $aInClass = undef;
    if (exists($aInRefArgs->{'class'}) and
       (defined($aInRefArgs->{'class'})))
    {
        $aInClass = $aInRefArgs->{'class'};
    }

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $aInHier = "false";
    if (exists($aInRefArgs->{'hier'}) and
       ($aInRefArgs->{'hier'}))
    {
        $aInHier = "true";
    }

    my $lXmlRequest = qq(<configResolveChildren cookie="$aInCookie" inDn="$aInDn" inHierarchical="$aInHier"/>);

    if (defined($aInClass))
    {
        my $lXmlRequest = qq(<configResolveChildren cookie="$aInCookie" classId="$aInClass" inDn="$aInDn" inHierarchical="$aInHier"/>);
    }

    return $lXmlRequest;
}

sub getComputeLcXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'dn'}))
    {
        croak "Missing mandatory argument: dn\n";
    }
    my $aInDn = $aInRefArgs->{'dn'};

    if (!exists($aInRefArgs->{'lc'}))
    {
        croak "Missing mandatory argument: lc\n";
    }
    my $aInLc = $aInRefArgs->{'lc'};

    if (!exists($aInRefArgs->{'class'}))
    {
        croak "Missing mandatory argument: class\n";
    }
    my $aInClass = $aInRefArgs->{'class'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $aInHier = "false";
    if (exists($aInRefArgs->{'hier'}) and
       ($aInRefArgs->{'hier'}))
    {
        $aInHier = "true";
    }

    my $lXmlRequest = 
        qq(<configConfMo cookie="$aInCookie" dn="$aInDn" inHierarchical="$aInHier">) .
        qq(<inConfig><$aInClass dn="$aInDn" lc="$aInLc"/></inConfig>) . 
        qq(</configConfMo>) .

    return $lXmlRequest;
}


sub getConfMoXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'dn'}))
    {
        croak "Missing mandatory argument: dn\n";
    }
    my $aInDn = $aInRefArgs->{'dn'};

    if (!exists($aInRefArgs->{'class'}))
    {
        croak "Missing mandatory argument: class\n";
    }
    my $aInClass = $aInRefArgs->{'class'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    if (!exists($aInRefArgs->{'attrMap'}))
    {
        croak "Missing mandatory argument: attribute map\n";
    }
    my $aInAttrRef = $aInRefArgs->{'attrMap'};

    my $lXmlRequest = <<END;
        <configConfMo
            cookie="$aInCookie" dn="$aInDn">
            <inConfig>
                <$aInClass
                    dn="$aInDn">
                REPLACE_ATTR
                </$aInClass>
            </inConfig>
        </configConfMo>
END

   my $lAttr = "";  
   for my $lKey (keys %{$aInAttrRef})
   {
       $lAttr .= $lKey . "=\"" . $aInAttrRef->{$lKey} .  "\" " ;
   }
 
    $lXmlRequest =~ s/REPLACE_ATTR/$lAttr/;
    return $lXmlRequest;
}

sub getDeleteXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'dn'}))
    {
        croak "Missing mandatory argument: dn\n";
    }
    my $aInDn = $aInRefArgs->{'dn'};

    if (!exists($aInRefArgs->{'class'}))
    {
        croak "Missing mandatory argument: class\n";
    }
    my $aInClass = $aInRefArgs->{'class'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $lXmlRequest = 
        qq(<configConfMo cookie="$aInCookie" dn="$aInDn">) .
        qq(<inConfig> <$aInClass dn="$aInDn" status="deleted"> </$aInClass> </inConfig>) .
        qq(</configConfMo>);

    return $lXmlRequest;
}



sub getDeleteManyXml
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'dnArray'}))
    {
        croak "Missing mandatory argument: dnArray\n";
    }
    my $aInDnArray = $aInRefArgs->{'dnArray'};

    if (!exists($aInRefArgs->{'class'}))
    {
        croak "Missing mandatory argument: class\n";
    }
    my $aInClass = $aInRefArgs->{'class'};

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $lXmlRequest = qq( <configConfMos cookie="$aInCookie"> <inConfigs>);

    foreach my $lDn (@$aInDnArray)
    {
        $lXmlRequest .= qq(<pair key="$lDn">) .
                        qq(<$aInClass dn="$lDn" status="deleted"> </$aInClass>) . 
                        qq(</pair>);
    }

    $lXmlRequest .= qq(</inConfigs> </configConfMos>);

    return $lXmlRequest;
}



sub getSubscribeXml
{
    my ($aInRefArgs) = @_;

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $lXmlRequest = qq(<eventSubscribe cookie="$aInCookie"> </eventSubscribe>);

    return $lXmlRequest;
}



sub getEstimateImpactXml
{
    my ($aInRefArgs) = @_;

    my $aInCookie = "";
    if (exists($aInRefArgs->{'cookie'}) and
       (defined($aInRefArgs->{'cookie'})))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    if (!exists($aInRefArgs->{'xmlConfig'}))
    {
        croak "Missing mandatory argument: xmlConfig\n";
    }
    my $aInXmlCfg = $aInRefArgs->{'xmlConfig'};

    my $lXmlRequest = 
        qq(<configEstimateImpact cookie="$aInCookie">) .
        $aInXmlCfg . 
        qq(</configEstimateImpact>);

    return $lXmlRequest;
}



1; 



__END__



=head1 NAME

UcsSimple::XmlUtil - a grab bag of useful xml utilities for UCS development.
Many of these utilities are lower level primitives and a higher-level richer
abstraction may be available.  It would be worth-while to check 
other modules in UcsSimple such as UcsSimple::CommMgr for more powerful operations.


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use UcsSimple::XmlUtil;


    my ($lSuccess, $lXmlResp, $lErrHashRef) =
        $lCommMgr->doPostXML({postData => $lXmlRequest});

    UcsSimple::XmlUtil->printResponse(
        success => $lSuccess, 
        xmlDoc => \$lXmlResp,
        maxLength => (defined($lBriefBytes) ? $lBriefBytes : undef),
        pretty => $lPretty, 
        stream => $lStream, 
        errorHash => $lErrHashRef,
   );
    ...

=head1 EXPORT

=item * prettyPrint
=item * printResponse
=item * checkUcsResponse
=item * getLoginXml
=item * getLogoutXml
=item * getRefreshXml
=item * getScopeXml
=item * getResolveDnXml
=item * getFindDepXml
=item * getResolveClassXml
=item * getResolveChildrenXml
=item * getComputeLcXml
=item * getConfMoXml
=item * getDeleteXml
=item * getDeleteManyXml
=item * getSubscribeXml
=item * getEstimateImpactXml

=head1 SUBROUTINES/METHODS

=head2 prettyPrint

Pretty print the passed xml document.  If no stream is passed, it returns 
the pretty printed document as a string.  Mandatory arguments is xmlDoc.

    my $lXmlString = '<html><head></head><body></body></html>';
    print UcsSimple::XmlUtil::prettyPrint({xmlDoc=>\$lXmlString});


=head2 printResponse

Print the UCS XML response.  If no stream is passed, it returns the pretty printed document as a string.
Mandatory arguments are xmlDoc and success which are returned from various UcsSimple::CommMgr operations.

    my $foo = UcsSimple::XmlUtil->printResponse(
        success => $lSuccess, 
        xmlDoc => \$lXmlResp,
        maxLength => (defined($lBriefBytes) ? $lBriefBytes : undef),
        pretty => $lPretty, 
        stream => $lStream, 
        errorHash => $lErrHashRef,
   );
    ...



=head2 checkUcsResponse

Check if the passed xml represents a successful UCS operation.  It checks for error codes
and the response field.  It returns an array with the result and a hash ref to error codes.

    my $lResp = "xml from post to ucs";
    ($lUcsRespValid, $lErrHashRef) =
        UcsSimple::XmlUtil::checkUcsResponse($lResp);
     if ($lUcsRespValid)
     {
        ...
     } 



=head2 getLoginXml

Get xml to post to UCS for aaaLogin method.  Mandatory arguments are name and  password. 

    my $lXmlRequest = UcsSimple::XmlUtil::getLoginXml(
    {
        name => "admin",
        password => "password",
    });
    ...



=head2 getLogoutXml

Get xml to post to UCS for aaaLogout method.  Mandatory arguments are cookie

    my $lXmlRequest = UcsSimple::XmlUtil::getLogoutXml(
        { cookie => $lCookie }
    );
    ...



=head2 getRefreshXml
Get xml to post to UCS for aaaRefresh method.  Mandatory arguments are name and password.
The cookie is an optional argument.

    my $lXmlRequest = UcsSimple::XmlUtil::getScopeXml(
    {
        name => "admin",
        password => "password",
        cookie => $lCookie
    });
    ...



=head2 getScopeXml

Get xml to post to UCS for configScope query.  Mandatory arguments are dn and class.
Optional arguments are hier and cookie.

    my $lXmlRequest = UcsSimple::XmlUtil::getScopeXml(
    {
        dn => "org-root/org-it",
        class => "lsServer",
        hier=> 1,
        cookie => $lCookie
    });
    ...



=head2 getResolveDnXml

Get xml to post to UCS for resolve dn query.  Mandatory argument is dn. 
Optional arguments are hier and cookie.

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveDnXml(
    {
        dn => "org-root/org-it",
        hier=> 1,
        cookie => $lCookie
    });
    ...



=head2 getFindDepXml



=head2 getResolveClassXml

Get xml to post to UCS for resolve class query.  Mandatory argument is class. 
Optional arguments are hier and cookie.

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveClassXml(
    {
        class => "lsServer",
        hier=> 1,
        cookie => $lCookie
    });
    ...



=head2 getResolveChildrenXml

Get xml to post to UCS for resolve children query.  Mandatory argument is class.
Optional arguments are hier and cookie.

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveChildrenXml(
    {
        class => "lsServer",
        hier=> 1,
        cookie => $lCookie
    });
    ...


=head2 getComputeLcXml

Get the xml to set the compute lc field on a server.
Mandatory arguments are dn, lc, and class.  Optional arguments are cookie and hier.



=head2 getConfMoXml

Get the xml to do a UCS configConfMo lc field on a server.
Mandatory arguments are dn, attrMap, and class  Optional arguments are cookie.



=head2 getDeleteXml

Get xml to post to UCS for delete operation.  Mandatory arguments are class and dn.
Optional argument is cookie.

    my $lXmlRequest = UcsSimple::XmlUtil::getResolveClassXml(
    {
        class => "lsServer",
        dn=> "org-root/ls-MyVm",
        cookie => $lCookie
    });
    ...



=head2 getDeleteManyXml

Get xml to post to UCS for delete many operation.  Mandatory arguments are class and dnArray.
Optional argument is cookie.

    my $lXmlRequest = UcsSimple::XmlUtil::getDeleManyXml(
    {
        class => "lsServer",
        dnArray=> ["org-root/ls-MyVm", "org-root/ls-FastVm" ],
        cookie => $lCookie
    });
    ...




=head2 getSubscribeXml

Get xml to post to subscribe to the event channel.  
Optional argument is cookie.

    my $lXmlRequest = UcsSimple::XmlUtil::getSubscribeXml(
    {
        class => "lsServer",
        dnArray=> ["org-root/ls-MyVm", "org-root/ls-FastVm" ],
        cookie => $lCookie
    });
    ...




=head2 getEstimateImpactXml

Get xml to post to estimate the impact of a configuration.
A better alternative may be to use UcsSimple::DomUtil::getEstimateImpact().




=head1 SEE ALSO

Many of these methods are used by higher level (more functionality rich) modules like UcsSimple::CommMgr.
It is recommended to consult these first.


=head1 AUTHOR

Ike Kent, C<< <ikent at cisco.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc UcsSimple::XmlUtil


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Ike Kent.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

