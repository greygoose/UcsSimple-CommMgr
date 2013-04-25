#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 8;

BEGIN {
    use_ok( 'UcsSimple::CommMgr' ) || print "Bail out!\n";
    use_ok( 'UcsSimple::Session' ) || print "Bail out!\n";
    use_ok( 'UcsSimple::Util' ) || print "Bail out!\n";
    use_ok( 'UcsSimple::XmlUtil' ) || print "Bail out!\n";
    use_ok( 'UcsSimple::DomUtil' ) || print "Bail out!\n";
    use_ok( 'UcsSimple::EventUtil' ) || print "Bail out!\n";
    use_ok( 'UcsSimple::SchemaParser' ) || print "Bail out!\n";
    use_ok( 'UcsSimple::ClassMeta' ) || print "Bail out!\n";
}

diag( "Testing UcsSimple::CommMgr $UcsSimple::CommMgr::VERSION, Perl $], $^X" );
