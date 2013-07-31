######################################################################
package UcsSimple::DomUtil;
######################################################################
use strict;
use warnings;

use Exporter;
use vars qw($VERSION @EXPORT @EXPORT_OK @ISA);

use Carp qw(croak cluck confess);
use XML::LibXML;
use UcsSimple::ClassMeta;
use UcsSimple::Util;
use Data::Dumper;

@ISA    = qw( Exporter );
@EXPORT_OK = qw( &pruneDomTree &getUcsAttrs &getConfigConfMo &getConfigConfMos 
                 &populateDn &getEstimateImpact &getFieldWidthCb &getElementByClassCb 
                 &getElementByDnCb &getElementByClass &getElementByDn &isStat &printTables);

$VERSION = "0.0001";

use constant ELEMENT_NODE => 1;
use constant DOCUMENT_NODE => 9;


sub getLevel
{
    my ($aInNode) = @_;
    my $lLevel = 0;

    if ($aInNode->nodeType() != DOCUMENT_NODE)
    {   
        my $lCurrent = $aInNode;
        do {
            if (defined($lCurrent))
            {
                if ($lCurrent->nodeType() != DOCUMENT_NODE)
                {
                    $lLevel++;
                }
                $lCurrent = $lCurrent->getParentNode();
            }
        } while defined($lCurrent);
    }

    return $lLevel;
}



sub isStat
{
    my ($aInElement) = @_;

    my $lClass = $aInElement->localname();
    if (($lClass =~ /Stats$/) && 
       $aInElement->hasAttribute('timeCollected'))
    {
        return 1;
    }
    return 0;
}



#
# Trim the passed dom tree
# node => DOM node 
# keepAttrMap => - map keyed by class of attributes to keep 
#                - other attributes are removed from DOM element.
# delClassMap => - map of classes (elements) to deleted.
# delUnknown => -  flag - to delete unknown classes (i.e. have 'rn' field)
sub pruneDomTree
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'node'}))
    {
        confess "Missing mandator argument: node";
    }
    my $aInNode = $aInRefArgs->{'node'};

    my $aInKeepAttrMap = {};
    if (exists($aInRefArgs->{'keepAttrMap'}))
    {
        $aInKeepAttrMap = $aInRefArgs->{'keepAttrMap'};
    }

    my $aInDelClassMap = {};
    if (exists($aInRefArgs->{'delClassMap'}))
    {
        $aInDelClassMap = $aInRefArgs->{'delClassMap'};
    }

    my $lDelUnknownClasses = undef;
    if (exists($aInRefArgs->{'delUnknown'}))
    {
        $lDelUnknownClasses = $aInRefArgs->{'delUnknown'};
    }

    if ($aInNode->nodeType() == DOCUMENT_NODE)
    {
        # Handle passed in document gracefully
        pruneDomTree ({
            node => $aInNode->getDocumentElement(), 
            delClassMap => $aInDelClassMap, 
            keepAttrMap => $aInKeepAttrMap,
            delUnknown => $lDelUnknownClasses,
        });
    }
    elsif ($aInNode->nodeType() == ELEMENT_NODE)
    {
        # Handle the base case where passed in node should be deleted
        my $lClass = $aInNode->localname();
        #print "Current element class : ($lClass)\n";
        my $lParent = $aInNode->getParentNode();
          
        if ((exists $aInDelClassMap->{$lClass}) ||
            (($lDelUnknownClasses) &&
             (!(exists $aInKeepAttrMap->{$lClass})) &&
             $aInNode->hasAttribute("rn")))
        {
            #print "Deleting element since class is ($lClass)\n";
            $lParent->removeChild($aInNode);
        } 
        else
        {
            #print "Keeping element since class is ($lClass)\n";
            if (exists $aInKeepAttrMap->{$lClass})
            {
                #print "Triming class ($lClass)\n";
                # Delete unwanted attributes from the node
                my @lAttrs = $aInNode->attributes(); 
                foreach my $lAttr (@lAttrs)
                {
                    my $lAttrName = $lAttr->nodeName();
                    #print "Current attribute : ($lClass)($lAttrName)\n";
                    # Do not delete dn and rn
                    if ((!(exists $aInKeepAttrMap->{$lClass}->{$lAttrName})) && 
                       ($lAttrName ne 'dn') &&
                       ($lAttrName ne 'rn'))
                    {
                        #print "Deleting attribute : ($lClass)($lAttrName)\n";
                        $aInNode->removeAttribute($lAttrName);
                    }
                }
            }

            my @lChildren =  $aInNode->getChildNodes;
            for my $lChild (@lChildren)
            {
                pruneDomTree ({
                    node => $lChild,
                    delClassMap => $aInDelClassMap, 
                    keepAttrMap => $aInKeepAttrMap,
                    delUnknown => $lDelUnknownClasses,
                });
            }
        }
    }
}



#
# Visit each node of the DOM tree calling the passed function on each element.
# 
sub visit
{
    my ($aInNode, $aInFnOrArrayRef) = @_;

    if (!defined($aInNode))
    {
        confess "Passed undefined node";
    }
    elsif ($aInNode->nodeType() == DOCUMENT_NODE)
    {
        visit($aInNode->getDocumentElement(), $aInFnOrArrayRef);
    }
    elsif ($aInNode->nodeType() == ELEMENT_NODE)
    {
        my $lClass = $aInNode->localname();
        my $lParent = $aInNode->getParentNode();

        if (ref($aInFnOrArrayRef) eq 'ARRAY')
        {
            foreach my $lFn (@{$aInFnOrArrayRef})
            {
                & {$lFn} ($aInNode);
            }
        }
        else
        {
            & {$aInFnOrArrayRef} ($aInNode);
        }
 
        my @lChildren =  $aInNode->getChildNodes;
        for my $lChild (@lChildren)
        {
            visit($lChild, $aInFnOrArrayRef);
        }
    }
}



sub getElementByDnCb
{
    my ($aInDnElementMap) = @_;

    my $lCb = sub
    {
        my $aInElement = shift;
        if ($aInElement->hasAttribute("dn"))
        {
            my $lDn = $aInElement->getAttribute("dn");
            $aInDnElementMap->{$lDn} = $aInElement;
        }
    };
    return $lCb;
}



sub getElementsOfClass
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'node'}))
    {
        confess "Missing mandator argument: node";
    }
    my $aInNode = $aInRefArgs->{'node'};

    if (!exists($aInRefArgs->{'class'}))
    {
        confess "Missing mandator argument: class";
    }
    my $aInClass = $aInRefArgs->{'class'};

    if (!exists($aInRefArgs->{'hier'}))
    {
        confess "Missing mandator argument: hier";
    }
    my $aInHier = $aInRefArgs->{'hier'};

    my $lResultArray = [];
    if (exists($aInRefArgs->{'resultArray'}))
    {
        $lResultArray = $aInRefArgs->{'resultArray'};
    }

    my $lClass = $aInNode->localname;
    if (($aInNode->nodeType() == ELEMENT_NODE) &&
        ($lClass eq $aInClass))
    {
        push @{$lResultArray}, $aInNode;
    }

    my @lChildren =  $aInNode->getChildNodes;
    for my $lChild (@lChildren)
    {
        if ($aInHier)
        {
            getElementsOfClass({node => $lChild, class => $aInClass, hier => $aInHier, resultArray => $lResultArray});
        }
    }

    return $lResultArray;
}



sub getElementByClassCb
{
    my ($aInOutClassElementMap) = @_;

    my $lCb = sub
    {
        my $aInElement = shift;

        my $lClass = $aInElement->localname;
        if (!exists($aInOutClassElementMap->{$lClass}))
        {
            $aInOutClassElementMap->{$lClass} = []
        }
        push @{$aInOutClassElementMap->{$lClass}}, $aInElement;
    };
    return $lCb;
}



sub getElementByDn
{
    my ($aInElement) = @_;
    my $lDnElMap = {};
    UcsSimple::DomUtil::visit(
        $aInElement,
        [ UcsSimple::DomUtil::getElementByDnCb($lDnElMap) ]
    );
    return $lDnElMap;
}



sub getElementsByClass
{
    my ($aInElement) = @_;
    my $lClassElMap = {};
    UcsSimple::DomUtil::visit(
        $aInElement,
        [ UcsSimple::DomUtil::getElementByClassCb($lClassElMap) ]
    );
    return $lClassElMap;
}



sub getFieldWidthCb
{
    my ($aInOutClassAttrLengthMap) = @_;

    my $lCb = sub 
    {
        my $aInElement = shift;

        my $lClass = $aInElement->localname;
        if (!exists($aInOutClassAttrLengthMap->{$lClass}))
        {
            $aInOutClassAttrLengthMap->{$lClass} = {}
        }

        my @lAttrs = $aInElement->attributes();
        foreach my $lAttr (@lAttrs)
        {
            my $lAttrName = $lAttr->nodeName();
            # print "Current attribute : ($lClass)($lAttrName)\n";
            # Do not delete dn and rn
            my $lMaxLength =  0;

            if ((exists $aInOutClassAttrLengthMap->{$lClass}) &&
                (exists $aInOutClassAttrLengthMap->{$lClass}->{$lAttrName}))
            {
                $lMaxLength = $aInOutClassAttrLengthMap->{$lClass}->{$lAttrName};
            }

            my $lValue = $lAttr->getValue();
            my $lCurrLength = length ($lValue);
            if ($lCurrLength >= $lMaxLength)
            {
                $aInOutClassAttrLengthMap->{$lClass}->{$lAttrName} = $lCurrLength;
            }
        }
    };
    return $lCb;
}


# Get the property in the child of DOM element - example "child:name"
sub getSpecialPropValue
{
    my ($aInElement, $aInPropName) = @_;

    my $lValue = undef;
    my ($lPre, $lChildClass, $lChildProp) = split(/:/, $aInPropName);
    my @lChildren =  $aInElement->getElementsByTagName($lChildClass);

    for my $lChild (@lChildren)
    {
        if ($lChild->nodeType() eq ELEMENT_NODE)
        {
            $lValue = $lChild->getAttribute($lChildProp);
            last;
        }
    }
    return $lValue;
}


# Is this a "special" property - really just look for "child" at start.
sub isSpecialProp
{
    my $aInPropName = shift;
    return ($aInPropName =~ "^child:");
}



# Print some tables of information from organizaed UCS xml content and
# an xml file that describes the table.
# classElementMap - ref to a map indexed by class and items are xml entities
# props - reference to array xml attribute names (properties) we will print
# props - (parallel) reference to array table headings
sub printTables
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'classElementMap'}))
    {
        confess "Missing mandator argument: classElementMap";
    }
    my $aInClassElementMap = $aInRefArgs->{'classElementMap'};

    if (!exists($aInRefArgs->{'moAttrPrintCfg'}))
    {
        confess "Missing mandator argument: moAttrPrintCfg";
    }
    my $aInMoAttrPrintCfg = $aInRefArgs->{'moAttrPrintCfg'};

    my $aInClassMap = undef;
    if (exists($aInRefArgs->{'classes'}))
    {
        $aInClassMap = $aInRefArgs->{'classes'};
    }

    # We print a table for each class that has elements provided:
    # - we have format information for it
    # - it is in out list of classes to print (or list is empty..print all)
    foreach my $lClass (sort keys %{$aInClassElementMap})
    {
        if (((!defined($aInClassMap)) || (exists $aInClassMap->{$lClass})) &&
          (exists $aInMoAttrPrintCfg->{'table'}->{$lClass}))
        {
            my $lRows = [];
            my $lHeadings  = [];
            my $lElementNum = 0;
            foreach my $lElement (@{$aInClassElementMap->{$lClass}})
            {
                # Print table row
                my $lRow = [];
                foreach my $lPropRef (@{$aInMoAttrPrintCfg->{table}->{$lClass}->{'property'}})
                {
                    my $lPropName = $lPropRef->{'propName'};
                    if ($lElementNum == 0)
                    {
                        my $lHeading = exists $lPropRef->{'label'} ?
                            $lPropRef->{'label'} : $lPropName;
                        push @{$lHeadings}, $lHeading;
                    }

                    my $lValue = "";
                    if (!isSpecialProp($lPropName))
                    {
                        $lValue = $lElement->getAttribute($lPropName);
                    }
                    else
                    {
                        $lValue = getSpecialPropValue($lElement, $lPropName);
                    }
                    push @{$lRow}, $lValue;
                }
                push @{$lRows}, $lRow;
                $lElementNum++;
            }
            if ($lElementNum > 0)
            {
                print "\n[" . $lClass . "]\n";
                UcsSimple::Util::printTable({
                    rows => $lRows,
                    headings => $lHeadings,
                });
            }
        }
    }
}



sub getSimplePrintVisitor
{
    my ($aInRefArgs) = @_;

    my $lPrintDn = exists $aInRefArgs->{'dn'} && 
        defined($aInRefArgs->{'dn'});

    my $lPrintRn = exists $aInRefArgs->{'rn'} &&
        defined($aInRefArgs->{'rn'});

    my $lAllAttrs = exists $aInRefArgs->{'allattrs'} &&
        defined($aInRefArgs->{'allattrs'});

    my $lPrintClassName = exists $aInRefArgs->{'cname'} &&
        defined($aInRefArgs->{'cname'});

    my $lTree = exists $aInRefArgs->{'tree'} &&
        defined($aInRefArgs->{'tree'});

    my $lElFn = (exists $aInRefArgs->{'elfn'}) ?
        $aInRefArgs->{'elfn'} : undef;

    my $lAttrFn = (exists $aInRefArgs->{'attrfn'}) ?
        $aInRefArgs->{'attrfn'} : undef;

    my $lClassMap = (exists $aInRefArgs->{'classes'} && 
           (scalar keys %{$aInRefArgs->{'classes'}} > 0)) ?
           ($aInRefArgs->{'classes'}) : undef;

    my $lClassAttrMap = $aInRefArgs->{'classAttrMap'};

    my $cb = sub {
        my $aInNode = shift;

        my $lClass = $aInNode->localname();
        my $lDn = undef;
        $lDn = $aInNode->hasAttribute("dn") ? 
               $aInNode->getAttribute("dn") : undef;

        if ((!defined($lClassMap)) ||
            (defined($lClassMap) && (exists $lClassMap->{$lClass})))
        {
            if ($lPrintClassName)
            {
                if (defined($lElFn))
                {
                    & {$lElFn} ($lClass, $lDn);
                }
                else 
                {
                    if ($lTree)
                    {
                        print UcsSimple::Util::getIndent(getLevel($aInNode) * 2);
                    }
                    print $lClass . "\n";
                }
            }
      
            my @lAttrs = $aInNode->attributes(); 
            foreach my $lAttr (@lAttrs)
            {
                my $lName = $lAttr->localname(); 
                if (($lAllAttrs) ||
                    ($lName eq "dn" && $lPrintDn) ||
                    ($lName eq "rn" && $lPrintRn) ||
                    (defined($lClassAttrMap) && (exists $lClassAttrMap->{$lName})))
                {
                    my $lVal = $lAttr->getValue();
                    if (defined($lAttrFn))
                    {
                        & {$lAttrFn} ($lClass, $lDn, $lAttr->localname(), $lVal); 
                    }
                    else    
                    {
                        if ($lTree)
                        {
                            print UcsSimple::Util::getIndent((getLevel($aInNode)) * 2);
                        }
                        print("  " . $lAttr->localname() . "=" . "\"" . $lVal . "\"\n");
                    }
                }
            }
        }
    };
    return $cb;
}




#
# populate the dn field of each element that is ucs class
# based on rn - since dn not always set in queries
sub populateDn
{
    my ($aInNode, $aInSetDnIfHasRn, $aInClassHashRef) = @_;

    if ($aInNode->nodeType() == DOCUMENT_NODE)
    {
        # Handle passed in document gracefully
        populateDn ($aInNode->getDocumentElement(), $aInSetDnIfHasRn, $aInClassHashRef);
    }
    elsif ($aInNode->nodeType() == ELEMENT_NODE)
    {
        # Handle the base case where passed in node should be deleted
        my $lClass = $aInNode->localname();
        # print "Current element class : ($lClass)\n";
        if ($lClass eq "topRoot")
        {
            $aInNode->setAttribute("dn", "");
        }
        else
        { 
            my $lParent = $aInNode->getParentNode();
            if ((defined($aInSetDnIfHasRn) && $aInNode->hasAttribute("rn")) ||
                (defined($aInClassHashRef) && (exists $aInClassHashRef->{$lClass})))
            {
                # print "Checking dn on ($lClass)\n";

                my $lDn = $aInNode->getAttribute("dn");
                my $lRn = $aInNode->getAttribute("rn");
                # print "Determining the dn ($lDn)($lRn)\n";
                if (!defined($lDn))
                {
                    my $lParentDn = $lParent->getAttribute("dn");
                    if (defined($lParentDn))
                    {
                        if (length($lParentDn) > 0)
                        {
                            $lDn = $lParentDn . "/"; 
                        }
                        $lDn .= $lRn;
                        # print "Parent dn is $lParentDn \n";
                        # print "Setting dn to: $lDn\n";
                        $aInNode->setAttribute("dn", $lDn);
                    }
                }
            }
        }

        my @lChildren =  $aInNode->getChildNodes;
        for my $lChild (@lChildren)
        {
            populateDn ($lChild, $aInSetDnIfHasRn, $aInClassHashRef);
        }
    }
}



sub diffElement
{
    my ($aInNodeOne, $aInNodeTwo, $aInAttrNameOnly) = @_;
    my $lProcAttrMap = {};
    my $lDiffMap = {};
    
    # Compare a to b then b to a (since each may have additional attrs).
    my $lNodeOne = $aInNodeOne;
    my $lNodeTwo = $aInNodeTwo;
    my $lNumTimes = defined($aInNodeTwo) ? 1 : 0; 
    foreach my $i (0,$lNumTimes)
    {
        # print "DiffElement ($i)\n";
        my $lArrow = ($i==0) ? ">\t" : "<\t";
        my $lOppArrow = ($i==0) ? ">\t" : "<\t";
        if ($i)
        {
            $lNodeOne = $aInNodeTwo;
            $lNodeTwo = $aInNodeOne;
        }
        my $lClass = $lNodeOne->localname();
        my @lAttrs = $lNodeOne->attributes(); 
        foreach my $lAttr (@lAttrs)
        {
            my $lName = $lAttr->localname(); 
            if (!exists $lProcAttrMap->{$lName})
            {
                $lProcAttrMap->{$lName} = 1;
                # print "\tCurrent attribute : ($lClass)($lName)\n";
                if ((!defined($lNodeTwo)) ||
                    (!$lNodeTwo->hasAttribute($lName)))
                {
                    my $lVal = $lNodeOne->getAttribute($lName);
                    $lDiffMap->{$lName} = $lArrow . $lName . "=\"" . $lVal . "\" [missing]";
                    # print  "DIFF: " . $lArrow . $lName . "=\"" . $lVal . "\"". "\n";
                }
                elsif (!$aInAttrNameOnly)
                {
                    my $lVal = $lNodeOne->getAttribute($lName);
                    my $lOtherVal = $lNodeTwo->getAttribute($lName);
                    # print "\t\tComparing : (" . $lVal . ")(" . $lOtherVal . ")\n";
                    if ($lVal ne $lOtherVal)
                    {
                         $lDiffMap->{$lName} = $lArrow . $lName . " = \"" .  $lVal . "\"  [different]\n";
                         $lDiffMap->{$lName} .= $lOppArrow . $lName . " = \"" .  $lOtherVal . "\"  [CHANGED]";
                         # print "DIFF: (" . $lVal . ")(" . $lOtherVal . ")" . "\n";
                    }
                }
            }
        }
    }
    return $lDiffMap;
}



sub doDiffDoc
{
    my ($aInNodeOne, $aInNodeTwo, $aInAttrNameOnly, $aInOutDiffAttr, $aInProcDnMap, $aInFirst) = @_;

    if ($aInNodeOne->nodeType() == DOCUMENT_NODE)
    {
        # Handle passed in document gracefully
        doDiffDoc (
             $aInNodeOne->getDocumentElement(), 
             $aInNodeTwo->getDocumentElement(),
             $aInAttrNameOnly,
             $aInOutDiffAttr, $aInProcDnMap, $aInFirst); 
    }
    elsif ($aInNodeOne->nodeType() == ELEMENT_NODE)
    {
        my $lArrow = $aInFirst ? ">\t" : "<\t";
        # Handle the base case where passed in node should be deleted
        my $lClass = $aInNodeOne->localname();
        # print "Current element class : ($lClass)\n";

        if ($aInNodeOne->hasAttribute("dn"))
        {
            my $lDn = $aInNodeOne->getAttribute("dn");
            # print "Checking dn on ($lClass)($lDn)\n";
            my $lIndx = $lClass . '||' . $lDn;

            if (defined($lDn))
            {
                if (!exists $aInProcDnMap->{$lIndx})
                {
                    # print "Checking dn on ($lClass)($lDn)\n";

                    # If it has a dn and rn, we assume it is a MO
                    # and don't want to process twice.
                    $aInProcDnMap->{$lIndx} = 1;
                    # Check if this dn exists in the other DOM
                    my $lExpr = '//' . $lClass . '[@dn="' . $lDn . '"]';
                    # print "Expression is : " . $lExpr . "\n"; 
                    my @lNodes = $aInNodeTwo->findnodes($lExpr);
                    my $lOtherNode = undef;
                    if ((scalar @lNodes) == 1)
                    {
                        $lOtherNode = $lNodes[0];
                    }

                    # Find attributes that differ in each node
                    $aInOutDiffAttr->{$lIndx} = diffElement($aInNodeOne,$lOtherNode,$aInAttrNameOnly);
                }
            }
        }

        my @lChildren =  $aInNodeOne->getChildNodes;
        for my $lChild (@lChildren)
        {
            doDiffDoc ($lChild, $aInNodeTwo, $aInAttrNameOnly, $aInOutDiffAttr, $aInProcDnMap, $aInFirst);
        }
    }
}



sub diffDoc 
{
    my ($aInNodeOne, $aInNodeTwo, $aInAttrNameOnly, $aInOutDiffAttr) = @_;

    my $lProcDnMap = {}; 
    doDiffDoc ($aInNodeOne, $aInNodeTwo, $aInAttrNameOnly, $aInOutDiffAttr, $lProcDnMap, 1);
    doDiffDoc ($aInNodeTwo, $aInNodeOne, $aInAttrNameOnly, $aInOutDiffAttr, $lProcDnMap, 0);
}



# Find element with passed dn
sub resolveDn
{
    my ($aInDoc, $aInDn) = @_;

    # DN QUERY 
    # my $lExpr = '//*[@dn="' . $aInDn . '"]';

     # DN AND CLASS QUERY
     my $lClass = "lsServer";
     my $lExpr = '//' . $lClass . '[@dn="' . $aInDn . '"]';
     print "Expression is : " . $lExpr . "\n";
     my @lNodes = $aInDoc->findnodes($lExpr);
     print $_->localname(), "\n" foreach (@lNodes);
}



# Returns a hashtable with UCS class names as keys and hashtables as values.
# The hashtable values contain attribute names as keys and 1 as the value 
sub getUcsAttrs
{
    my ($aInNode, $aInOutAttrMap, $aInClassMeta) = @_;

    if ($aInNode->nodeType() == DOCUMENT_NODE)
    {
        # Handle passed in document gracefully
        &getUcsAttrs ($aInNode->getDocumentElement(), $aInOutAttrMap, $aInClassMeta);
    }
    elsif ($aInNode->nodeType() eq ELEMENT_NODE)
    {
        my $lClass = $aInNode->localname();
        #print "Current element class : ($lClass)\n";
        if ($aInClassMeta->isUcsClass($lClass))
        {
            if (!exists $aInOutAttrMap->{$lClass})
            {
                $aInOutAttrMap->{$lClass} = {};
            }
            # Add attributes to result set.
            my @lAttrs = $aInNode->attributes(); 
            foreach my $lAttr (@lAttrs)
            {
                #print "Current attribute : ($lAttr)\n";
                if (defined($lAttr))
                {
                    # print "Defined attribute : ($lClass)($lAttr)\n";
                    $aInOutAttrMap->{$lClass}->{$lAttr} = 1;
                }
            }
        }

        my @lChildren =  $aInNode->getChildNodes;
        for my $lChild (@lChildren)
        {
            getUcsAttrs ($lChild, $aInOutAttrMap, $aInClassMeta);
        }
    }
}


# Given UCS query result, create a config method from it for posting
sub getConfigConfMo
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'doc'}))
    {
        confess "Missing mandator argument: doc";
    }
    my $aInDoc = $aInRefArgs->{'doc'};

    if (!exists($aInRefArgs->{'classMeta'}))
    {
        confess "Missing mandator argument: classMeta";
    }
    my $aInClassMeta = $aInRefArgs->{'classMeta'};

    # Now create a document with the 'outConfigs' or 'outConfig' of the query
    my $lConfMoDoc = XML::LibXML::Document->createDocument("1.0");
    my $lMethod = $lConfMoDoc->createElement("configConfMo");
    my $lAttr = $lConfMoDoc->createAttribute("cookie", "REPLACE_COOKIE"); 
    $lMethod->addChild($lAttr);

    $lConfMoDoc->setDocumentElement($lMethod);

    my $lTargetInConfigs = $lConfMoDoc->createElement("inConfig");
    $lMethod->addChild($lTargetInConfigs);

    # See if the source has 'inConfig' in it
    my @lInOutConfig =  $aInDoc->getElementsByTagName('outConfig');
    my @lInOutConfigs =  $aInDoc->getElementsByTagName('outConfigs');

    if ((scalar @lInOutConfig) == 1)
    {
        my $lInOutCfg = $lInOutConfig[0];
        my @lConfChild = $lInOutCfg->childNodes();
        foreach my $lConfChild (@lConfChild)
        {
            if ($lConfChild->nodeType() eq ELEMENT_NODE)
            {
                my $lDn = $lConfChild->getAttribute("dn");
                my $lNewNode = $lConfChild->cloneNode(1);

                # Remove non-configurable classes and attributes
                # Pass in elements to delete and elements/attributes to keep;
                pruneDomTree ({
                    node => $lNewNode,
                    delClassMap => $aInClassMeta->getNonConfigClasses(),
                    keepAttrMap => $aInClassMeta->getConfigAttrs(),
                    delUnknown => 1
                });

                $lTargetInConfigs->addChild($lNewNode);

                my $lDnAttr = $lConfMoDoc->createAttribute("dn", $lDn);
                $lMethod->addChild($lDnAttr);
            }
        }
    }
    elsif ((scalar @lInOutConfigs) == 1)
    {
        my $lInOutCfg = $lInOutConfigs[0];

        my @lConfChild = $lInOutCfg->childNodes();
        foreach my $lConfChild (@lConfChild)
        {
            if ($lConfChild->nodeType() eq ELEMENT_NODE)
            {
                my $lDn = $lConfChild->getAttribute("dn");
                my $lNewNode = $lConfChild->cloneNode(1);

                # Remove non-configurable classes and attributes
                # Pass in elements to delete and elements/attributes to keep;
                pruneDomTree ({
                    node => $lNewNode,
                    delClassMap => $aInClassMeta->getNonConfigClasses(),
                    keepAttrMap => $aInClassMeta->getConfigAttrs(),
                    delUnknown => 1
                });

                $lTargetInConfigs->addChild($lNewNode);
                my $lDnAttr = $lConfMoDoc->createAttribute("dn", $lDn);
                $lMethod->addChild($lDnAttr);
                last;
            }
        }
    }
    else
    {
        # Assume we are passed the raw xml
        my $lDn = $aInDoc->getAttribute("dn");
        my $lNewNode = $aInDoc->cloneNode(1);

        # Remove non-configurable classes and attributes
        # Pass in elements to delete and elements/attributes to keep;
        pruneDomTree ({
            node => $lNewNode,
            delClassMap => $aInClassMeta->getNonConfigClasses(),
            keepAttrMap => $aInClassMeta->getConfigAttrs(),
            delUnknown => 1
        });

        $lTargetInConfigs->addChild($lNewNode);

        my $lDnAttr = $lConfMoDoc->createAttribute("dn", $lDn);
        $lMethod->addChild($lDnAttr);
    }

    return $lConfMoDoc;
}



# Given UCS query result, create a config method from it for posting
sub getConfigConfMos
{
    my ($aInRefArgs) = @_;

    if (!exists($aInRefArgs->{'doc'}))
    {
        confess "Missing mandator argument: doc";
    }
    my $aInDoc = $aInRefArgs->{'doc'};

    if (!exists($aInRefArgs->{'classMeta'}))
    {
        confess "Missing mandator argument: classMeta";
    }
    my $aInClassMeta = $aInRefArgs->{'classMeta'};

    # Take the current UCS configuration and remove non-configurable classes and attributes
    # Pass in elements to delete and elements/attributes to keep;
    pruneDomTree ({
        node => $aInDoc,
        delClassMap => $aInClassMeta->getNonConfigClasses(),
        keepAttrMap => $aInClassMeta->getConfigAttrs(),
        delUnknown => 1
    });

    # Now create a document with the 'outConfigs' or 'outConfig' of the query
    my $lConfMosDoc = XML::LibXML::Document->createDocument("1.0");
    my $lMethod = $lConfMosDoc->createElement("configConfMos");
    my $lAttr = $lConfMosDoc->createAttribute("cookie", "REPLACE_COOKIE"); 
    $lMethod->addChild($lAttr);
    $lConfMosDoc->setDocumentElement($lMethod);

    my $lTargetInConfigs = $lConfMosDoc->createElement("inConfigs");
    $lMethod->addChild($lTargetInConfigs);

    # See if the source has 'inConfig' in it
    my @lInOutConfig =  $aInDoc->getElementsByTagName('outConfig');
    my @lInOutConfigs =  $aInDoc->getElementsByTagName('outConfigs');

    if ((scalar @lInOutConfig) == 1)
    {
        my $lInOutCfg = $lInOutConfig[0];

        my @lConfChild = $lInOutCfg->childNodes();
        foreach my $lConfChild (@lConfChild)
        {
            if ($lConfChild->nodeType() eq ELEMENT_NODE)
            {
                my $lDn = $lConfChild->getAttribute("dn");
                my $lNewNode = $lConfChild->cloneNode(1);
                my $lAttr = $lConfMosDoc->createAttribute("key", $lDn); 

                my $lPair = $lConfMosDoc->createElement("pair");
                $lPair->addChild($lNewNode);
                $lPair->addChild($lAttr);
                $lTargetInConfigs->addChild($lPair);
            }
        } 
    }
    elsif ((scalar @lInOutConfigs) == 1)
    {
        my $lInOutCfg = $lInOutConfigs[0];

        my @lConfChild = $lInOutCfg->childNodes();
        foreach my $lConfChild (@lConfChild)
        {
            if ($lConfChild->nodeType() eq ELEMENT_NODE)
            {
                my $lDn = $lConfChild->getAttribute("dn");
                my $lNewNode = $lConfChild->cloneNode(1);
                my $lAttr = $lConfMosDoc->createAttribute("key", $lDn); 

                my $lPair = $lConfMosDoc->createElement("pair");
                $lPair->addChild($lNewNode);
                $lPair->addChild($lAttr);
                $lTargetInConfigs->addChild($lPair);
            }
        } 
    }
    return $lConfMosDoc;
}



#
# Get a new DOM document that contains 'config' sub-tree
#
sub extractCfg
{
    my ($aInDoc) = @_;
  
    my $lOutDoc = $aInDoc;
    my $lRoot = $aInDoc->getDocumentElement();

    my $lCfgNode = undef;
    print $lRoot->localname() . "\n";

    my $lCfgElem = undef;
    my @lChildren =  $lRoot->getElementsByTagName('inConfig');
    confess "There should only be one inConfig element" if ((scalar @lChildren) > 1);
    
    if ((scalar @lChildren) == 1)
    {
        my $lCfgElem = $lChildren[0]->clone(1);
        my $lParent = $lCfgElem->getParentNode();
        $lOutDoc = XML::LibXML::Document->createDocument("1.0");
        $lOutDoc->setDocumentElement($lCfgElem);

        print "Making changes\n";
    }

    return $lOutDoc;
}



# Utility method for creating/augmenting an analyze impact from the passed method.
# $aInDoc - reference to xml for a 'configConfMo' or 'configConfMos' method
sub getEstimateImpact
{
    my ($aInXmlRef) = @_;

    my $lParser = XML::LibXML->new();
    my $lInXmlDoc = $lParser->parse_string(${$aInXmlRef});

    my $lEstimateDoc = XML::LibXML::Document->createDocument("1.0");
    my $lMethod = $lEstimateDoc->createElement("configEstimateImpact");

    my $lAttr = $lEstimateDoc->createAttribute("cookie", "REPLACE_COOKIE"); 
    $lMethod->addChild($lAttr);

    $lEstimateDoc->setDocumentElement($lMethod);

    my $lTargetInConfigs = $lEstimateDoc->createElement("inConfigs");
    $lMethod->addChild($lTargetInConfigs);

    # See if the source has 'inConfig' in it
    my @lConfMo =  $lInXmlDoc->getElementsByTagName('configConfMo');
    my @lConfMos =  $lInXmlDoc->getElementsByTagName('configConfMos');

    if ((scalar @lConfMo) == 1)
    {
        # Assume it is a configConfMo
        my $lInMethod = $lConfMo[0];
        my $lDn = $lInMethod->getAttribute("dn");

        my @lInConfig =  $lInXmlDoc->getElementsByTagName('inConfig');
        foreach my $lInConfig (@lInConfig)
        {
            my @lConfChild = $lInConfig->childNodes();
            foreach my $lConfChild (@lConfChild)
            { 
                if ($lConfChild->nodeType() eq ELEMENT_NODE)
                {
                    my $lNewNode = $lConfChild->cloneNode(1);
                    my $lAttr = $lEstimateDoc->createAttribute("key", $lDn); 

                    my $lPair = $lEstimateDoc->createElement("pair");
                    $lPair->addChild($lNewNode);
                    $lPair->addChild($lAttr);
                    $lTargetInConfigs->addChild($lPair);
                }
            }
        } 
    }
    elsif ((scalar @lConfMos) == 1)
    {
        # Copy the inConfig children elements to our doc
        my @lInPair =  $lConfMos[0]->getElementsByTagName('pair');
        foreach my $lInPair (@lInPair)
        {
            my $lPair = $lInPair->cloneNode(1);
            $lTargetInConfigs->addChild($lPair);
        }
    }
    return $lEstimateDoc;
}


1; 



__END__



=head1 NAME

UcsSimple::DomUtil - some handly utility methods for working with UCS xml documents.
It leverages the power of XML::LibXML for searching, modifying and manipulating DOM documents.
Consult the various applications in UcsSimple::DemoApp 
(eg. UcsSimple::DemoApp::Scope) for concrete examples of their use


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use UcsSimple::DomUtil;

=head1 EXPORT

=item * getLevel
=item * pruneDomTree
=item * visit
=item * getSimplePrintVisitor
=item * populateDn
=item * diffElement
=item * doDiffDoc
=item * diffDoc 
=item * resolveDn
=item * getUcsAttrs
=item * getConfigConfMo
=item * getConfigConfMos
=item * extractCfg
=item * getEstimateImpact
=item * getFieldWidthCb
=item * getElementByClassCb
=item * getElementByDnCb
=item * isStat


=head1 SUBROUTINES/METHODS

=head2 getLevel

Get the level of passed DOM element in the DOM.


=head2 isStat

Check if a passed xml element is a statistic

=head2 getLevel

Get the level of passed DOM element in the DOM.


=head2 pruneDomTree

Prune the passed DOM tree.


=head2 visit



=head2 getSimplePrintVisitor



=head2 populateDn



=head2 diffElement


=head2 doDiffDoc


=head2 diffDoc


=head2 resolveDn


=head2 getUcsAttrs


=head2 getConfigConfMo


=head2 getConfigConfMos


=head2 getEstimateImpact




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

