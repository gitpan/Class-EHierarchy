use ExtUtils::MakeMaker;
use 5.006;

WriteMakefile(
  NAME          => 'Class::EHierarchy',
  AUTHOR        => 'Arthur Corliss <corliss@digitalmages.com>',
  ABSTRACT      => 'Base class for handling hierarchally ordered objects',
  VERSION_FROM  => 'lib/Class/EHierarchy.pm',
  PREREQ_PM     => {},
  ($ExtUtils::MakeMaker::VERSION ge '6.30_00'? (
    LICENSE => 'perl' ) : () ),
);

exit 0;
