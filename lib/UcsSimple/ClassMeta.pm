######################################################################
package UcsSimple::ClassMeta;
######################################################################

use 5.006;
use strict;
use warnings FATAL => 'all';

use vars qw ($VERSION);
$VERSION = "0.0001"; 

use Carp qw(croak cluck confess);


sub new
{
    my ($aInClass, $aInRefArgs) = @_;
    my $self = {};
    bless $self, $aInClass;

    if (!exists($aInRefArgs->{'classAttrMap'}))
    {
        confess "Missing configurable class/attribute";
    }

    if (!exists($aInRefArgs->{'nonConfigClassMap'}))
    {
        confess "Missing non-configurable classes";
    }

    $self->{'cfg'} = $aInRefArgs->{'classAttrMap'};
    $self->{'noncfg'} = $aInRefArgs->{'nonConfigClassMap'};

    $self->{'all'} = {};
    foreach my $lKey (keys %{$self->{'cfg'}})
    {
        $self->{'all'}->{$lKey} = 1;
    }
    foreach my $lKey (keys %{$self->{'noncfg'}})
    {
        $self->{'all'}->{$lKey} = 1;
    }

    return $self;
}



sub applyTypicalUcsMods
{
    my ($self) = @_;
    $self->changeToNonConfig(["lsServerAssocCtx"]);
}



sub changeToNonConfig
{
    my ($self, $aInClasses, $aInForce) = @_;

    foreach my $lClass (@{$aInClasses})
    {
        if ($aInForce || (exists $self->{'all'}->{$lClass}))
        {
            if (exists $self->{'cfg'}->{$lClass})
            {
                delete $self->{'cfg'}->{$lClass};
            }
            $self->{'noncfg'}->{$lClass} = 1;
            $self->{'all'}->{$lClass} = 1;
        }
    }
}



sub getUcsClasses
{
    my ($self, $aInClass) = @_;
    ref ($self) or confess "Instance required";
    return $self->{'all'};
}



sub getConfigClasses
{
    my ($self, $aInClass) = @_;
    ref ($self) or confess "Instance required";
    return $self->{'cfg'};
}



sub getNonConfigClasses
{
    my ($self, $aInClass) = @_;
    ref ($self) or confess "Instance required";
    return $self->{'noncfg'}; 
}



sub getConfigAttrs
{
    my ($self, $aInClass) = @_;
    ref ($self) or confess "Instance required";
    my $lAttr = undef;
    if (!defined($aInClass))
    {
        return $self->{'cfg'}; 
    }
    if (exists $self->{'cfg'}->{$aInClass})
    {
        $lAttr = $self->{'cfg'}->{$aInClass};
    }
    return $lAttr;
}



sub isUcsClass
{
    my ($self, $aInClass) = @_;
    ref ($self) or confess "Instance required";
    return (exists $self->{'all'}->{$aInClass});
}



sub isConfigClass
{
    my ($self, $aInClass) = @_;
    ref ($self) or confess "Instance required";
    return (exists $self->{'cfg'}->{$aInClass});
}



sub isConfigAttr
{
    my ($self, $aInClass, $aInAttr) = @_;
    ref ($self) or confess "Instance required";

    my $lResult = 0;
    if (isConfigClass($aInClass))
    {
        $lResult = (exists $self->{'cfg'}->{$aInClass}->{$aInAttr});
    }
    return $lResult;
}



sub debugPrint
{
    my ($self) = @_;
    ref ($self) or confess "Instance required";

    print "Here are our configurable classes/attributes\n";
    $self->{'all'} = {};
    foreach my $lClass (keys %{$self->{'cfg'}})
    {
        foreach my $lAttr (keys %{$self->{'cfg'}->{$lClass}})
        {
            print "(" . $lClass . ")(" . $lAttr . ")\n";
        }
    }

    print "Here are our non-configurable classes\n";
    foreach my $lKey (keys %{$self->{'noncfg'}})
    {
        print $lKey . "\n";
    }

}

1;


__END__


=head1 NAME

UcsSimple::ClassMeta - Wrapper for UCS Class meta information

=head1 SYNOPSIS

Typically, this class would be instantiated and returned by a meta data aware class.
For example, the schema parser UCS::SchemaParser

    my $lSchemaParser = UCS::SchemaParser->new({schema => "USCM-IN.XSD" });
    my $lClassMeta = $lSchemaParser->getClassMeta();
    $lClassMeta->applyTypicalUcsMods();
    my $lCfgDoc = UCS::DomUtil::getConfigMo({doc=>$lXmlDoc, classMeta=>$lClassMeta});
    print  $lCfgDoc->toString();


=head1 DESCRIPTION

This module provides a wrapper around collections that describe UCS meta data.
It can be used to programmatically query whether a string is a UCS class and 
whether it is programmatically configurable.   It also provides access to 
information on class attributes.

A typical use of this module is in UcsSimple::SchemaParser::getClassMeta
The schema parser prepares the meta data that is passed to our constructor.

    use UcsSimple::ClassMeta;

    my $lClassArgRef = { lsServer => {"name", "dn" } };
    my $lNonCfgClassMapRef = { computeBlade => 1 };

    my $lClassMeta = 
        UcsSimple::ClassMeta->new({classAttrMap => $lClassArgRef, nonConfigClassMap => $lNonCfgClassMapRef});

    my $lClassMeta->isConfigClass("computeBlade");


=head1 SUBROUTINES/METHODS

=head2 new

Constructor expects meta data parsed from schema.


=head2 applyTypicalUcsMods

Call to change certain UCS MOs to non-configurable (ones that are not typically configured programmatically)
Only example is lsServerAssocCtx.


=head2 changeToNonConfig

Array of classes to change to non-configurable


=head2 getUcsClasses

Get a hash reference to UCS classes.


=head2 getConfigClasses

Get a hash reference to configurable UCS classes.


=head2 getNonConfigClasses

Get a hash reference to non-configurable UCS classes.



=head2 getNonConfigClasses

Get a hash reference to map of configurable attributes.


=head2 isUcsClass

Return boolean indicating if passed string is UCS class.


=head2 isConfigClass

Return boolean indicating if passed string is a configurable UCS class.


=head2 isConfigClass

Return boolean indicating if passed string is the passed attribute is configurable.


=head2 isConfigClass

Print out our meta data for debug purposes.


=head1 AUTHOR

Ike Kent, C<< <ikent at cisco.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc post


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Ike Kent.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut



