#!/usr/bin/perl

use strict;
use warnings;

use Config::Std;
use Getopt::Long;
use Carp qw(croak cluck confess);

use UcsSimple::Session;
use UcsSimple::CommMgr;
use UcsSimple::XmlUtil;
use Data::Dumper;
use DateTime;

# Signal handler (assure 1 logout per login)
$SIG{'INT'} = \&sigIntHandler;
my $lCommMgr = undef;

my $lUname = "admin";
my $lUri = undef;
my $lPasswd = undef;
my $lDn= "";
my $lCfgFile = undef;
my $lRetCode = 1;
my $lBackupHome = undef;
my $lMaxBackups = undef;


# Specify the command line options and process the command line
my $options_okay = GetOptions (
        # Application specific options
	'uri=s' 	=> \$lUri,   	    # Server uri
	'uname=s'       => \$lUname,        # User name.
	'passwd=s'      => \$lPasswd,       # Password.
	'cfg=s'         => \$lCfgFile,      # a cfg file with application settings.
        'backupHome'    => \$lBackupHome,   # Backup directory
        'maxBackups'    => \$lMaxBackups,   # Maximum backup files

	# Standard meta-options
	'usage'		=> sub { usage(); },
);

usage() if !$options_okay;

if (defined($lCfgFile))
{
    read_config $lCfgFile => my %lConfig;

    # Command line arguments take precendence.
    $lUri = $lConfig{'UCS'}{'URI'} if (!$lUri);
    $lUname = $lConfig{'UCS'}{'UNAME'} if (!$lUname);
    $lPasswd = $lConfig{'UCS'}{'PASSWORD'} if (!$lPasswd);
    $lBackupHome = $lConfig{'APP'}{'BACKUP_HOME'} if (!$lBackupHome);
    $lMaxBackups = $lConfig{'APP'}{'MAX_BACKUP_FILES'} if (!$lMaxBackups);
}

usage() if ((!$lUname) || (!$lPasswd) || (!$lUri) || (!$lBackupHome) || ((!defined($lMaxBackups)) || ($lMaxBackups < 1)));

my $UserAgent = LWP::UserAgent->new(SSL_verify_mode => 0x00);
$UserAgent->ssl_opts( SSL_verify_mode => 0x00 );
$UserAgent->ssl_opts( verify_hostname => 0 );

my $lCookie =  doLogin({ uri => $lUri, name => $lUname, password => $lPasswd}); 
croak "Failed to get cookie" if (!defined $lCookie);

my $lBackupFileName = getBackupFileName({ backupHome => $lBackupHome });
print "MIT snapshot : " . $lBackupFileName . "\n";

my $lSuccess = queryMit({uri => $lUri, cookie => $lCookie, cbFileName => $lBackupFileName });

doLogout({ uri => $lUri, cookie => $lCookie }); 

$lRetCode = $lSuccess ? 0 : 1;

exit $lRetCode;



# Call like this :
# doLogin({ uri => $lUri, name => $lName, password => $lPassword}); 
sub doLogin 
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'uri'}))
    {
        confess "Missing mandatory argument: uri ";
    }
    my $aInUri = $aInRefArgs->{'uri'};

    if (!exists($aInRefArgs->{'name'}))
    {
        confess "Missing mandatory argument: name";
    }
    my $aInName = $aInRefArgs->{'name'};

    if (!exists($aInRefArgs->{'password'}))
    {
        confess "Missing mandatory argument: password";
    }
    my $aInPassword = $aInRefArgs->{'password'};

    my $lXmlRequest = getLoginXml({ name => $aInName, password => $aInPassword});

    my ($lSuccess, $lContent, $lErrHashRef) = 
        doPostXML({postData => $lXmlRequest, uri => $aInUri});

    my $lCookie = undef;
    if ($lSuccess)
    {
        eval {
            my $lParser = XML::Simple->new();
            my $lConfig = $lParser->XMLin($lContent);
            $lCookie = $lConfig->{'outCookie'};
            $lCookie = undef if ($lCookie && $lCookie eq "");
        };
    }
    if (!defined($lCookie))
    {
       print "Failed to get cookie " . $lContent . "\n"; 
    }
 
    return $lCookie;  
}



# Call like this :
# doLogout({ uri => $lUri, cookie => $lCookie }); 
# returns undef on failure
sub doLogout
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'uri'}))
    {
        confess "Missing mandatory argument: uri ";
    }
    my $aInUri = $aInRefArgs->{'uri'};

    if (!exists($aInRefArgs->{'cookie'}))
    {
        confess "Missing mandatory argument: cookie ";
    }
    my $aInCookie = $aInRefArgs->{'cookie'};

    my $lXmlRequest = getLogoutXml({ cookie => $aInCookie });

    my $lSuccess = undef;
    my $lContent = undef;
    my $lErrHashRef = undef;
    my $lResult = undef;

    if (defined($lCookie))
    {
        my ($lSuccess, $lContent, $lErrHashRef) =
            doPostXML({ postData => $lXmlRequest, uri => $aInUri });

        $lResult = $lSuccess ? 1 : undef;

        if (!defined($lResult))
        {
            print "Logout failed\n";
        }
    }
    else
    {
        print "Skipping logout - no cookie\n";
    }

    return ($lSuccess, $lContent, $lErrHashRef) if wantarray;
    return $lResult;
}



# Call like this:
# my $lSuccess = queryMit({uri => $lUri, cookie => $lCookie, cbFileName => $lFileName });
sub queryMit
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'uri'}))
    {
        confess "Missing mandatory argument: uri ";
    }
    my $aInUri = $aInRefArgs->{'uri'};

    if (!exists($aInRefArgs->{'cookie'}))
    {
        confess "Missing mandatory argument: cookie ";
    }
    my $aInCookie = $aInRefArgs->{'cookie'};

    my $aInCbFile = undef;
    if (exists($aInRefArgs->{'cbFileName'}))
    {
        $aInCbFile = $aInRefArgs->{'cbFileName'};
    }
    $aInCbFile = $aInRefArgs->{'cbFileName'};

    my $lXmlRequest = getResolveDnXml({dn => "", cookie => $aInCookie, hier =>  1});

    my ($lSuccess) =
        doPostXML({postData => $lXmlRequest, uri => $aInUri, cbFileName => $aInCbFile});

    return $lSuccess;
}



sub getBackupFileName
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'backupHome'}))
    {
        confess "Missing mandatory argument: backupHome";
    }  
    my $aInBackupHome = $aInRefArgs->{'backupHome'};

    my $lDt = DateTime->now();
    my $lDtString = $lDt->strftime("%F-%H_%M_%S");
    my $lBackupFilename = 'ucs-snapshot-' . $lDtString . '.xml';
    my $lQualBackupFile = File::Spec->catfile( $aInBackupHome, $lBackupFilename);
    return $lQualBackupFile;
}



# Remove old log files beyond a max
# cleanup({ dir => /home/joe/backup, prefix ="ucs-snapshot", maxFiles => 5 });
sub cleanup
{
    my ($aInRefArgs) = @_; 

    if (!exists($aInRefArgs->{'dir'}))
    {
        confess "Missing mandatory argument: dir";
    }  
    my $lDir = $aInRefArgs->{'dir'};

    if (!exists($aInRefArgs->{'prefix'}))
    {
        confess "Missing mandatory argument: prefix";
    }  
    my $lPrefix = $aInRefArgs->{'prefix'};

    my $lSuffix = '.xml';
    if (!exists($aInRefArgs->{'maxFiles'}))
    {
        confess "Missing mandatory argument: maxFiles";
    }  
    my $lMaxFiles = $aInRefArgs->{'maxFiles'};

    my $lGlob = File::Spec->catfile( $lDir, $lPrefix) . '*' . $lSuffix;

    my @lCurrentFiles = glob($lGlob);
    # Check if we need to delete a file
    if (@lCurrentFiles >= $lMaxFiles)
    {
        # Create a map indexed by a DateTime object for sorting.
        my $lTimeFileMap = {};
        foreach my $lFilename (@lCurrentFiles)
        {
            my $lDtString = $lFilename;
            my ($lYear, $lMonth, $lDay, $lHour, $lMin, $lSec) = 
                ($lDtString =~ m/(\d{4})-(\d{2})-(\d{2})-(\d{2})_(\d{2})_(\d{2})/);
            my $lDt = DateTime->new( year => $lYear, month => $lMonth, day => $lDay, 
                hour => $lHour, minute => $lMin, second => $lSec);
            $lTimeFileMap->{$lDt} = $lFilename;
        }

        my $lCount = 0;
        foreach my $lDt (reverse sort keys %{$lTimeFileMap})
        {
            $lCount++; 
            if ($lCount >= $lMaxFiles)
            {
                my $lFilename =  $lTimeFileMap->{$lDt};
                #print "Deleting: " . $lCount . ")" . $lFilename . "\n";
                unlink $lFilename or die "Could not delete file : $lFilename";
            }
        }
    }
}




#
# Parameters:
# a hashref for the key/value pairs
#  Mandatory:
#      postData => data to post
#  Optional:
#      file => to store response
#
#     my ($lSuccess, $lContent, $lErrHashRef) = 
#        doPostXML({postData => $lXmlRequest, uri => $aInUri});
#    OR 
#    my ($lSuccess, $lContent, $lErrHashRef) = 
#        doPostXML({postData => $lXmlRequest, uri => $aInUri, cbFileName => $aInFile });
sub doPostXML
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'postData'}))
    {
        confess "Missing mandatory argument: post";
    }
    my $aInPostData = $aInRefArgs->{'postData'};

    if (!exists($aInRefArgs->{'uri'}))
    {
        confess "Missing mandatory argument: uri ";
    }
    my $aInUri = $aInRefArgs->{'uri'};

    my $aInCookie = undef;
    if (exists($aInRefArgs->{'cookie'}))
    {
        $aInCookie = $aInRefArgs->{'cookie'};
    }

    my $aInCbFile = undef;
    if (exists($aInRefArgs->{'cbFileName'}))
    {
        $aInCbFile = $aInRefArgs->{'cbFileName'};
    }

    # Set the cookie
    if (defined($aInCookie))
    {
        $aInPostData =~ s/cookie=\"(.*?)\"/cookie=\"$lCookie\"/;
    }

    my $lRequest = HTTP::Request->new(POST => $aInUri);
    $lRequest->content_type("application/x-www-form-urlencoded");
    $lRequest->content($aInPostData);

    # print "Request : \n" .  $aInPostData;

    my $lRespContent = "";
    my $lResp = undef;
    my $lUcsRespValid = undef;
    my $lErrHashRef = undef;

    if (defined($aInCbFile))
    {
        print "Using call-back file to store response";
        $lResp = $UserAgent->request($lRequest, $aInCbFile);
    }
    else
    {
        # print "Posting request";
        $lResp = $UserAgent->request($lRequest);
        $lRespContent = $lResp->content();

        if ($lResp->is_success)
        {
            ($lUcsRespValid, $lErrHashRef) =
                UcsSimple::XmlUtil::checkUcsResponse(\$lRespContent);
        }
    }

    # print "Got a response\n";

    return ($lUcsRespValid, $lRespContent, $lErrHashRef, $lResp->status_line) if wantarray;

    if (defined($lUcsRespValid))
    {
        return $lResp->content;
    }
    return $lUcsRespValid;
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



# getLoginXml({ name => $aInName, password => $aInPassword});
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



# Print usage message.
sub usage 
{
    print "For usage information:\n";
    print "\n\tperldoc ucs-snapshot-mit\n\n";
    exit;
}



sub sigIntHandler
{
    print "Caught signal - will cleanup and exit \n";
    doLogout({ uri => $lUri, cookie => $lCookie }); 

    print "Terminated by signal\n";
    exit 1;
}


__END__


=head1 NAME

snapshot-mit - a simple script that snapshots the MIT and stores it in an xml file.
               It limits the number of snapshot files based on user configuration. 


=head1 USAGE

snapshot-mit [options]

    snapshot-mit --uname=admin --passwd=pass --uri=https://ucs-vip-ip/nuova --backupHome=/home/joe/ucs-backup/ --maxBackups=7

    snapshot-mit --cfg=./config/demo.conf 


=head1 REQUIRED ARGUMENTS

    --uri=<ucs-vip>           The UCS VIP uri.
    --uname=<ucs-user>        The UCS user name.
    --passwd=<ucs-pass>       The UCS password.
    --backupHome=<directory>  The directory to store the backups in.
    --maxBackups=<num>        The maximum number of backups.


UCS connection arguments may be provided in a L<"CONFIGURATION FILE">

=head1 OPTIONS

    --dn=<dn>                 Identifies the UCS subtree. Defaults to "".
    --hier                    Return hierarchy of found managed objects. 
    --cfg=<config-file>       Specify a configuration file. 
    --usage                   Print a usage message.


=head1 CONFIGURATION FILE

A configuration file is used to store UCS connection information.  
The command line options can be read from a configuration file.
Example configuration file:

    [UCS]
    URI     = http://ucs-vip/nuova
    UNAME = admin
    PASSWORD = Nbv12345

    [APP]
    BACKUP_HOME = /home/ikent/backup
    MAX_BACKUP_FILES = 7

=head1 SEE ALSO

L<LOG4PERL> for log4perl configuration file.
L<UcsSimple::Session>
L<UcsSimple::CommMgr>
L<UcsSimple::XmlUtil>

=head1 AUTHOR

Ike Kent, C<< <ikent at cisco.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc snapshot-mit

You can also look for information at:

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Ike Kent.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut


