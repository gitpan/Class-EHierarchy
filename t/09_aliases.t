# 09_aliases.t
#
# Tests the tracking of object relationships

use Test::More tests => 28;

use strict;
use warnings;

use Class::EHierarchy;

my $obj1 = new Class::EHierarchy;
my $obj2 = new Class::EHierarchy;
my $obj3 = new Class::EHierarchy;
my $obj4 = new Class::EHierarchy;

# Aliases should all be the same at this time
ok( $obj1->alias eq 'Class::EHierarchy0', 'Default Alias 1' );
ok( $obj2->alias eq 'Class::EHierarchy0', 'Default Alias 2' );
ok( $obj3->alias eq 'Class::EHierarchy0', 'Default Alias 3' );
ok( $obj4->alias eq 'Class::EHierarchy0', 'Default Alias 4' );

# Test alias rename
ok( $obj1->alias('root'),   'Set Alias 1');
ok( $obj1->alias eq 'root', 'Check Set Alias 1');

# Start merging aliases
$obj1->adopt($obj2, $obj3);
$obj3->adopt($obj4);
ok( $obj1->alias eq 'root', 'Merge Alias 1');
ok( $obj2->alias eq 'Class::EHierarchy0', 'Merge Alias 2' );
ok( $obj3->alias eq 'Class::EHierarchy1', 'Merge Alias 3' );
ok( $obj4->alias eq 'Class::EHierarchy2', 'Merge Alias 4' );

# Test more alias renames
ok( $obj2->alias('joe'),   'Set Alias 2');
ok( $obj2->alias eq 'joe', 'Check Set Alias 2');
ok( $obj3->alias('fred'),   'Set Alias 3');
ok( $obj3->alias eq 'fred', 'Check Set Alias 3');

# Test Relative retrieval
ok( $obj2->relative('root') == $obj1, 'Relative 1');
ok( $obj3->relative('root') == $obj1, 'Relative 2');
ok( $obj4->relative('root') == $obj1, 'Relative 3');
ok( $obj4->relative('joe')  == $obj2, 'Relative 4');
ok( $obj4->relative('fred') == $obj3, 'Relative 5');

# Test relatives
my @objects = $obj1->relatives('Class');
ok( scalar @objects == 1, 'Relatives 1');
ok( $objects[0] == $obj4, 'Relatives 2');

# Test split
$obj1->disown($obj3);
ok( ! defined $obj1->relative('fred'), 'Split Alias 1');
ok(   defined $obj3->relative('fred'), 'Split Alias 2');
ok( ! defined $obj3->relative('root'), 'Split Alias 3');
ok(   defined $obj1->relative('root'), 'Split Alias 4');

# Test Merge
my $obj5 = new Class::EHierarchy;
my $obj6 = new Class::EHierarchy;
my $obj7 = new Class::EHierarchy;
$obj1->adopt($obj5);
$obj3->adopt($obj6);
$obj4->adopt($obj7);
$obj1->adopt($obj3);
ok( $obj5->alias eq 'Class::EHierarchy0', 'Merge Alias 5');
ok( $obj1->relative('fred') == $obj3,     'Merge Alias 6');
ok( $obj3->relative('joe')  == $obj2,     'Merge Alias 7');

# end 09_aliases.t
