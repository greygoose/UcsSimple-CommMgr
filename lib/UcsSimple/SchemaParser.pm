######################################################################
package UcsSimple::SchemaParser;
######################################################################

use strict;
use warnings;

use vars qw($VERSION);

$VERSION = "0.0001";

use XML::LibXML;
use UcsSimple::ClassMeta;
use Carp qw(croak cluck confess);



# Pass in the name of the schema file as argument
# Constructor expects meta data parsed from schema.
sub new
{
    my ($aInClass, $aInRefArgs) = @_;
    my $self = {};
    bless $self, $aInClass;

    if (!exists($aInRefArgs->{'schema'}))
    {
        confess "Missing schema filename ";
    }

    $self->{'schema'} = $aInRefArgs->{'schema'};

    return $self;
}


sub getSchemaFile
{
    my ($self) = @_;
    ref($self) or confess "Instance required";
    return $self->{'schema'}; 
}


sub setSchemaFile
{
    my ($self,$aInFileName) = @_;
    ref($self) or confess "Instance required";
    $self->{'schema'} = $aInFileName;
}


sub getClassMeta
{
    my ($self) = @_;
    ref($self) or confess "Instance required";
    my $parser = XML::LibXML->new();
    my $lDoc = $parser->parse_file($self->getSchemaFile());
    my $lClassArgRef = {};
    my $lNonCfgClassMapRef = {};
    getCfgMoAttr($lDoc, $lClassArgRef, $lNonCfgClassMapRef);
    return UcsSimple::ClassMeta->new({classAttrMap => $lClassArgRef, nonConfigClassMap => $lNonCfgClassMapRef});
}



# Get a list of all classes supported in the schema
# Stored in the passes map with value of "undef"
sub getMoClasses
{
    my ($aInDoc) = @_;
    my $lOutClassMapRef = {};

    my @lSimpleElements = $aInDoc->getElementsByTagName("xs:simpleType");
    foreach my $lSimpleEl (@lSimpleElements)
    {
        my $lName = $lSimpleEl->getAttribute("name");
        if (defined($lName) && ("namingClassId" eq $lName))
        { 
            my @lAttrNodes = $lSimpleEl->getElementsByTagName("xs:enumeration");
            foreach my $lAttrNode (@lAttrNodes)
            {
                my $lClassName = $lAttrNode->getAttribute("value");
                $lOutClassMapRef->{$lClassName} = 1;
            }
        }
    }
    return $lOutClassMapRef;
}



# Get a list of all classes supported in the schema
sub getCfgMoAttr
{
    my ($aInDoc, $aInOutCfgMoAttr, $aInOutNonCfgClassMapRef) = @_;

    my $lAllClassMapRef = getMoClasses($aInDoc);

    # <xs:element name="lsServer" type="lsServer" substitutionGroup="managedObject"/>
    my @lElements = $aInDoc->getElementsByTagName("xs:element");
    foreach my $lElement (@lElements)
    {
        my $lSubgroup = $lElement->getAttribute("substitutionGroup");
        if (defined($lSubgroup) && ("managedObject" eq $lSubgroup))
        {
            my $lName = $lElement->getAttribute("name");
            my $lType = $lElement->getAttribute("type");

            # IF IT IS A UCS CLASS
            if (exists $lAllClassMapRef->{$lName})
            {
                $aInOutCfgMoAttr->{$lName} = {};
            }
        }
    }

    @lElements = $aInDoc->getElementsByTagName("xs:complexType");
    foreach my $lElement (@lElements)
    {
        my $lName = $lElement->getAttribute("name");
        if (defined($lName) && (exists $aInOutCfgMoAttr->{$lName}))
        {
            my @lAttrEls = $lElement->getElementsByTagName("xs:attribute");
            foreach my $lAttrEl (@lAttrEls)
            {
                my $lAttrName = $lAttrEl->getAttribute("name");
                if (defined($lName))
                {
                    $aInOutCfgMoAttr->{$lName}->{$lAttrName} = 1;
                }
            }
        }
    }

    foreach my $lClass (keys %{$lAllClassMapRef})
    {
        if (!exists $aInOutCfgMoAttr->{$lClass})
        {
            $aInOutNonCfgClassMapRef->{$lClass} = 1;
        }
    }
}


1; 


__END__



=head1 NAME

UcsSimple::SchemaParser - This module is used to parse UCS schema's in order to extract
some basic class, attribute and configurability information.  



=head1 SYNOPSIS

The schema parser will parse a schema document to extract class, attribute and configurability
information.  It provides an interface to get a UcsSimple::ClassMeta object from it.
This is useful for programmatically manipulating UCS xml objects.

    use UcsSimple::SchemaParser;
    use UcsSimple::ClassMeta;

    my $lSchemaParser = UcsSimple::SchemaParser->new({schema => $lSchemaFile});
    my $lClassMeta = $lSchemaParser->getClassMeta();

    ...

=head1 SEE ALSO
A sample application that uses this module is UcsSimple::DemoApp::ConvertToConfig.


=head1 SUBROUTINES/METHODS

=head2 new(schemaFileName)

Construct a SchemaParser for the passed file name.



=head2 getClassMeta()

Get class meta from the schema parser.


=head1 AUTHOR

Ike Kent, C<< <ikent at cisco.com> >>



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc UcsSimple::SchemaParser



=head1 LICENSE AND COPYRIGHT

Copyright 2013 Ike Kent.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut


