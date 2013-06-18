# 02_relationships.t
#
# Tests the tracking of object relationships

use Test::More tests => 27;

use strict;
use warnings;

use Class::EHierarchy;

my $obj1 = new Class::EHierarchy;
my $obj2 = new Class::EHierarchy;
my $obj3 = new Class::EHierarchy;
my $obj4 = new Class::EHierarchy;

# Test basic adoption
ok( !$obj1->adopt($obj1), 'Adopt Self' );
ok( $obj1->adopt($obj2),  'Adopt Child 1' );
my @children = $obj2->children;
ok( !scalar @children, 'Children 1' );
@children = $obj1->children;
ok( scalar @children,     'Children 2' );
ok( @children == 1,       'Children 3' );
ok( !$obj2->adopt($obj1), 'Adopt Parent' );
ok( $obj2->adopt($obj3),  'Adopt Child 2' );
@children = $obj1->children;
ok( @children == 1, 'Children 4' );
@children = $obj2->children;
ok( @children == 1, 'Children 5' );

# Test parent
ok( !defined $obj1->parent, 'Parent 1' );
ok( $obj3->parent == $obj2,  'Parent 2' );

# Test root
ok( $obj3->root == $obj1, 'Root 1' );

# Test descendants
@children = $obj1->descendants;
ok( $children[0] == $obj2, 'Descendant 1');
ok( $children[1] == $obj3, 'Descendant 2');

# Test disowning
ok( $obj1->disown($obj2), 'Disown 1' );
@children = $obj1->children;
ok( @children == 0,            'Children 6' );
ok( !defined $obj2->parent,    'Parent 3' );
ok( $$obj1 == 0,               'Object ID 1' );

Class::EHierarchy::_dumpDiags();

# Test DESTROY routines
$obj1 = undef;
$obj4 = undef;
$obj4 = new Class::EHierarchy;
$obj1 = new Class::EHierarchy;
ok( $$obj4 == 0,         'Object ID 2' );
ok( $$obj1 == 3,         'Object ID 3' );
ok( $obj2->adopt($obj4), 'Adopt Child 3' );
@children = $obj2->children;
ok( $obj3->adopt($obj1),  'Adopt Child 4' );
ok( @children == 2,       'Children 7' );
ok( !$obj1->adopt($obj2), 'Adopt Child 5' );
$obj2 = undef;
$obj3 = new Class::EHierarchy;
ok( $$obj3 == 1, 'Object ID 4' );

# Test subclassed adoption
package Foo;

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;

    return $self;
}

1;

package Bar;

use vars qw(@ISA);

@ISA = qw(Class::EHierarchy);

1;

package main;

my $subobj1 = new Foo;
my $subobj2 = new Bar;

ok( !$obj3->adopt($subobj1), 'Adopt Child 7' );
ok( $obj3->adopt($subobj2),  'Adopt Child 8' );

$obj4 = $obj1 = undef;
Class::EHierarchy::_dumpDiags();

$obj1 = new Bar;
Class::EHierarchy::_dumpDiags();

# end 02_relationships.t
