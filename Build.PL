use Module::Build;

Module::Build->new(
    module_name => 'UcsSimple::CommMgr',
    license => 'perl',
    configure_requires => {'Module::Build' =>  '>= 0.4'},
    requires => 
    {
        'Carp' =>  '>= 1.11',
        'Class::MethodMaker' =>  '>= 2.18',
        'Config::Std' =>  '>= 0.90',
        'Data::Dumper' => '>= 2.124',
        'DateTime' => '>= 1.03',
        'Exporter' => '>= 5.63',
        'File::Spec' => '>= 3.4',
        'File::Copy::Recursive' => '>= 0.38',
        'Getopt::Long' => '>= 2.38',
        'LWP' => '>= 6.04',
        'LWP::Protocol::https' => '6.03',
        'Log::Log4perl' => '>= 1.40',
        'Math::Int64' => '>= 0.29',
        'Mozilla::CA' => '>= 20130114',
        'Perl6::Slurp' => '>= 0.051001',
        'URI' => '>= 1.52',
        'XML::Handler::YAWriter' => '>= 0.23',
        'XML::LibXML' => '>= 2.0014',
        'XML::Parser::PerlSAX' => '>= 0.08',
        'XML::Simple' => '>= 2.20',
        'version' => '>= 0.77',
    },
    script_files => 
    [ 
       'bin/monitor-sp',
       'bin/fault-reader',
       'bin/convert-to-config',
       'bin/count-elements',
       'bin/delete-class',
       'bin/delete-mo',
       'bin/estimate-impact',
       'bin/event-reader',
       'bin/find-dependencies',
       'bin/meta-gen', 
       'bin/mo-print', 
       'bin/pretty-print', 
       'bin/resolve-class',
       'bin/resolve-classes',
       'bin/resolve-dn',
       'bin/resolve-dns',
       'bin/ucs-snapshot-mit',
       'bin/ucs-snapshot-report',
       'bin/post',
       'bin/scope',
       'bin/ucs-diff',
       'bin/xml-to-html',
       'bin/show-identity',
       'bin/find-sp',
    ]
)->create_build_script;



