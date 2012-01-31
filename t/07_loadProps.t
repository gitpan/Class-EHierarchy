# 07_loadProps.t
#
# Tests the various property types and scoping

use Test::More tests => 92;

use strict;
use warnings;

package Foo;

use vars qw(@ISA @_properties);
use Class::EHierarchy qw(:all);

@ISA = qw(Class::EHierarchy);
@_properties = (
    [ CEH_PRIV | CEH_SCALAR,  'PrivFoo', 'foo!' ],
    [ CEH_PRIV | CEH_ARRAY,   'PrivFooArray', [ qw(f1 f2 f3) ] ],
    [ CEH_PRIV | CEH_HASH,    'PrivFooHash', { 
                                f1  => 'one',
                                f2  => 'two',
                                f3  => 'three' } ],
    [ CEH_RESTR | CEH_SCALAR, 'RestrFoo', 'rfoo!' ],
    [ CEH_RESTR | CEH_ARRAY,  'RestrFooArray', [ qw(f11 f12 f13) ] ],
    [ CEH_PUB | CEH_SCALAR,   'PubFoo', 'pfoo!' ]
    );

sub _initialize ($@) {
    my $self = shift;
    my @args = @_;

    return 1;
}

sub call ($$$) {
    my $self = shift;
    my $obj  = shift;
    my $prop = shift;

    return $obj->property( $prop, @_ );
}

sub cpurge ($$) {
    my $self    = shift;
    my $prop    = shift;

    return $self->purge($prop);
}

1;

package Bar;

use vars qw(@ISA @_properties);
use Class::EHierarchy qw(:all);

@ISA = qw(Class::EHierarchy);

@_properties = (
    [ CEH_PRIV | CEH_SCALAR,  'PrivBar', 'bar!' ],
    [ CEH_PRIV | CEH_ARRAY,   'PrivBarArray', [ qw(b1 b2 b3 b4) ] ],
    [ CEH_PRIV | CEH_HASH,    'PrivBarHash', {
                                b1  => 'one',
                                b2  => 'two',
                                b3  => 'three',
                                } ],
    [ CEH_RESTR | CEH_SCALAR, 'RestrBar', 'rbar!' ],
    [ CEH_RESTR | CEH_ARRAY,  'RestrBarArray', [ qw(b11 b12 b13 b14) ] ],
    [ CEH_RESTR | CEH_HASH,   'RestrBarHash', {
                                b11 => 'one',
                                b12 => 'two',
                                b13 => 'three'
                                } ],
    [ CEH_PUB | CEH_CODE,     'PubBar', 'pbar!' ]
    );

sub _initialize ($@) {
    my $self = shift;
    my @args = @_;

    return 1;
}

sub call ($$$) {
    my $self = shift;
    my $obj  = shift;
    my $prop = shift;

    return $obj->property( $prop, @_ );
}

sub callNames ($$) {
    my $self = shift;
    my $obj  = shift;

    return $obj->propertyNames;
}

sub cpurge ($$) {
    my $self    = shift;
    my $prop    = shift;

    return $self->purge($prop);
}

1;

package Roo;

use vars qw(@ISA @_properties);
use Class::EHierarchy qw(:all);

@ISA = qw(Bar);
@_properties = (
    [ CEH_PRIV | CEH_SCALAR, 'PrivRoo', 'roo!' ],
    [ CEH_PRIV | CEH_SCALAR, 'PrivBar', 'roo-bar!' ],
    [ CEH_PRIV | CEH_ARRAY, 'PrivBarArray', [ qw(r1) ] ],
    [ CEH_RESTR | CEH_HASH, 'RestrRooHash', {
                            r11 => 'one',
                            r12 => 'two',
                            r13 => 'three',
                            } ],
    [ CEH_PUB | CEH_ARRAY, 'PubArray' ],
    [ CEH_PUB | CEH_HASH, 'PubHash' ],
    [ CEH_PUB | CEH_REF | CEH_NO_UNDEF, 'PubRef' ]
    );

sub call ($$$) {
    my $self = shift;
    my $obj  = shift;
    my $prop = shift;

    return $obj->property( $prop, @_ );
}

sub callNames ($$) {
    my $self = shift;
    my $obj  = shift;

    return $obj->propertyNames;
}

sub cpurge ($$) {
    my $self    = shift;
    my $prop    = shift;

    return $self->purge($prop);
}

1;

package main;

my $class1a = new Foo;
my $class1b = new Foo;
my $class2a = new Bar;
my $class2b = new Bar;
my $class3a = new Roo;
my $class3b = new Roo;

my $rv;

# Test subclass instantiation
ok( defined $class1a,                   'Created object for class Foo 1' );
ok( defined $class1b,                   'Created object for class Foo 2' );
ok( $class1a->isa('Foo'),               'Verify class Foo 1' );
ok( $class1a->isa('Class::EHierarchy'), 'Verify class Foo inheritance 1' );

ok( defined $class2a,                   'Created object for class Bar 1' );
ok( defined $class2b,                   'Created object for class Bar 2' );
ok( $class2a->isa('Bar'),               'Verify class Bar 1' );
ok( $class2a->isa('Class::EHierarchy'), 'Verify class Bar inheritance 1' );

ok( defined $class3a,                   'Created object for class Roo 1' );
ok( defined $class3b,                   'Created object for class Roo 2' );
ok( $class3a->isa('Roo'),               'Verify class Roo 1' );
ok( $class3a->isa('Class::EHierarchy'), 'Verify class Roo inheritance 1' );
ok( $class3a->isa('Bar'),               'Verify class Roo inheritance 2' );

# Set extra copies of objects to different property values
ok( $class1b->call( $class1b, qw(PrivFoo nope!) ),    'Foo prep 1' );
is( $class1b->call( $class1b, qw(PrivFoo) ), 'nope!', 'Foo prep validate 1' );
ok( $class1b->call( $class1b, qw(RestrFoo nope) ),    'Foo prep 2' );
is( $class1b->call( $class1b, qw(RestrFoo) ), 'nope', 'Foo prep validate 2' );
ok( $class2b->call( $class2b, qw(PrivBar nope!) ),    'Bar prep 1' );
is( $class2b->call( $class2b, qw(PrivBar) ), 'nope!', 'Bar prep validate 1' );
ok( $class2b->call( $class2b, qw(RestrBar nope) ),    'Bar prep 2' );
is( $class2b->call( $class2b, qw(RestrBar) ), 'nope', 'Bar prep validate 2' );
ok( $class3b->call( $class3b, qw(PrivRoo nope!) ),    'Roo prep 1' );
is( $class3b->call( $class3b, qw(PrivRoo) ), 'nope!', 'Roo prep validate 1' );
ok( $class3b->call( $class3b, qw(PrivBar nope!) ),    'Roo prep 2' );
is( $class3b->call( $class3b, qw(PrivBar) ), 'nope!', 'Roo prep validate 2' );

# Scalar Private Property tests
#
# Call from same class should succeed
is( $class1b->call( $class1a, qw(PrivFoo) ) , 'foo!', 
    'Foo Private Scalar Property Get 1' );
is( $class2b->call( $class2a, qw(PrivBar) ) , 'bar!', 
    'Bar Private Scalar Property Get 1' );
is( $class3b->call( $class3a, qw(PrivRoo) ) , 'roo!', 
    'Roo Private Scalar Property Get 1' );

# Call from different class shoud fail
$rv = eval '$class2a->call($class1a, qw(PrivFoo)); 1;';
ok( !$rv, 'Bar calling Foo Private Scalar 1' );
$rv = eval '$class1a->call($class2a, qw(PrivBar)); 1;';
ok( !$rv, 'Foo calling Bar Private Scalar 1' );
$rv = eval '$class3a->call($class2a, qw(PrivBar)); 1;';
ok( !$rv, 'Roo calling Bar Private Scalar 1' );

# Check class protection of private name collisions
is( $class2b->call( $class3a, qw(PrivBar)), 'bar!',     'Class Collision 1' );
is( $class3b->call( $class3a, qw(PrivBar)), 'roo-bar!', 'Class Collision 2' );
ok( $class3b->call( $class3a, qw(PrivBar nrp-bar!) ),   'Class Collision 3' );
ok( $class2b->call( $class3a, qw(PrivBar nbp-bar!) ),   'Class Collision 4' );
is( $class2b->call( $class3a, qw(PrivBar)), 'nbp-bar!', 'Class Collision 5' );
is( $class3b->call( $class3a, qw(PrivBar)), 'nrp-bar!', 'Class Collision 6' );

# Scalar Restricted Property tests
#
# Calls from same class should succeed
is( $class1b->call( $class1a, qw(RestrFoo) ) , 'rfoo!', 
    'Foo Restricted Scalar Property Get 1' );
is( $class2b->call( $class2a, qw(RestrBar) ) , 'rbar!', 
    'Bar Restricted Scalar Property Get 1' );

# Calls from subclasses should succeed
is( $class3b->call( $class2a, qw(RestrBar) ) , 'rbar!', 
    'Bar Restricted Property Get 2' );
is( $class3b->call( $class3a, qw(RestrBar) ) , 'rbar!', 
    'Bar Restricted Property Get 3' );

# Calls from elsewhere should fail
$rv = eval '$class1a->call($class2a, qw(RestrBar)); 1;';
ok( !$rv, 'Foo calling Bar Restricted Scalar 1' );
$rv = eval '$class2a->property(qw(RestrBar)); 1;';
ok( !$rv, 'Main calling Bar Restricted Scalar 1' );

# Set extra copies of objects to different property values
ok( $class1b->cpurge( qw(PrivFooArray)),  'Foo prep 3' );
$rv = [ $class1b->call( $class1b, qw(PrivFooArray)) ];
is( scalar @$rv, 0,                          'Foo prep validate 3' );
ok( $class2b->cpurge( qw(PrivBarArray)),  'Bar prep 3' );
$rv = [ $class2b->call( $class2b, qw(PrivBarArray)) ];
is( scalar @$rv, 0,                          'Bar prep validate 3' );
ok( $class3b->cpurge( qw(PrivBarArray)),  'Roo prep 3' );
$rv = [ $class3b->call( $class3b, qw(PrivBarArray)) ];
is( scalar @$rv, 0,                          'Roo prep validate 3' );

# Array Private Property tests
#
# Call from same class should succeed
$rv = [ $class1b->call( $class1a, qw(PrivFooArray)) ];
is( scalar @$rv, 3, 'Foo Private Array Property Get 1' );
is( $$rv[1], 'f2',  'Foo Private Array Property Get 2' );
$rv = [ $class2b->call( $class2a, qw(PrivBarArray)) ];
is( scalar @$rv, 4, 'Bar Private Array Property Get 1' );
is( $$rv[1], 'b2',  'Bar Private Array Property Get 2' );
$rv = [ $class3b->call( $class3a, qw(PrivBarArray)) ];
is( scalar @$rv, 1, 'Roo Private Array Property Get 1' );
is( $$rv[0], 'r1',  'Roo Private Array Property Get 2' );

# Call from different class shoud fail
$rv = eval '$class2a->call($class1a, qw(PrivFooArray)); 1;';
ok( !$rv, 'Bar calling Foo Private Array 1' );
$rv = eval '$class1a->call($class2a, qw(PrivBarArray)); 1;';
ok( !$rv, 'Foo calling Bar Private Array 1' );
$rv = eval '$class3a->call($class2a, qw(PrivBarArray)); 1;';
ok( !$rv, 'Roo calling Bar Private Array 1' );

# Array Restricted Property tests
#
# Calls from same class should succeed
$rv = [ $class1b->call( $class1a, qw(RestrFooArray)) ];
is( scalar @$rv, 3, 'Foo Restricted Array Property Get 1' );
is( $$rv[1], 'f12', 'Foo Restricted Array Property Get 2' );
$rv = [ $class2b->call( $class2a, qw(RestrBarArray)) ];
is( scalar @$rv, 4, 'Bar Restricted Array Property Get 1' );
is( $$rv[1], 'b12', 'Bar Restricted Array Property Get 2' );

# Calls from subclasses should succeed
$rv = [ $class3b->call( $class2a, qw(RestrBarArray)) ];
is( scalar @$rv, 4, 'Bar from Roo Restricted Array Property Get 1' );
is( $$rv[1], 'b12', 'Bar from Roo Restricted Array Property Get 2' );

# Calls from elsewhere should fail
$rv = eval '$class1b->call( $class2a, qw(RestrBarArray)); 1;';
ok( !$rv, 'Foo calling Bar Restricted Array 1' );
$rv = eval '$class3a->property(qw(RestrBarArray)); 1;';
ok( !$rv, 'Main calling Roo Restricted Array 1' );

# Set extra copies of objects to different property values
ok( $class1b->cpurge( qw(PrivFooHash)),   'Foo prep 4' );
$rv = [ $class1b->call( $class1b, qw(PrivFooHash)) ];
is( scalar @$rv, 0,                          'Foo prep validate 4' );
ok( $class2b->cpurge( qw(PrivBarHash)),  'Bar prep 4' );
$rv = [ $class2b->call( $class2b, qw(PrivBarHash)) ];
is( scalar @$rv, 0,                          'Bar prep validate 4' );

# Hash Private Property tests
#
# Calls from same class should succeed
$rv = { $class1b->call( $class1a, qw(PrivFooHash)) };
is( $$rv{f1}, 'one',  'Foo Private Hash Property Get 1' );
$rv = { $class2b->call( $class2a, qw(PrivBarHash)) };
is( $$rv{b3}, 'three',  'Bar Private Hash Property Get 1' );

# Call from different class shoud fail
$rv = eval '$class2a->call($class1a, qw(PrivFooHash)); 1;';
ok( !$rv, 'Bar calling Foo Private Hash 1' );
$rv = eval '$class3a->call($class2a, qw(PrivBarHash)); 1;';
ok( !$rv, 'Roo calling Bar Private Hash 1' );

# Hash Restricted Property tests
#
# Calls from same class should succeed
$rv = { $class3b->call( $class2a, qw(RestrBarHash)) };
is( $$rv{b12}, 'two',  'Bar Restricted Hash Property Get 1' );

# Calls from elsewhere should fail
$rv = eval '$class1b->call( $class2a, qw(RestrBarHash)); 1;';
ok( !$rv, 'Foo calling Bar Restricted Hash 1' );
$rv = eval '$class2b->call( $class3a, qw(RestrRooHash)); 1;';
ok( !$rv, 'Bar calling Roo Restricted Hash 1' );

# Public array tests
$rv = [ $class3a->property('PubArray') ];
is( scalar @$rv, 0, 'Public Array Get 1' );
$rv = $class3a->property( 'PubArray', qw(three two one) );
ok( $rv, 'Public Array Set 1' );
$rv = [ $class3a->property('PubArray') ];
is( $$rv[0], 'three', 'Public Array Get 2' );

# Public hash tests
$rv = { $class3a->property('PubHash') };
is( scalar keys %$rv, 0, 'Public Hash Get 1' );
$rv = $class3a->property( 'PubHash', foo => 'bar' );
ok( $rv, 'Public Hash Set 1' );
$rv = { $class3a->property('PubHash') };
is( scalar keys %$rv, 1,     'Public Hash Get 2' );
is( $$rv{foo},        'bar', 'Public Hash Get 3' );

# Public ref tests
$rv = $class3a->property('PubRef');
is( $rv, undef, 'Public Ref Get 1' );
$rv = $class3a->property( 'PubRef', qr/foo/ );
ok( $rv, 'Public Ref Set 1' );
$rv = $class3a->property('PubRef');
is( $rv, qr/foo/, 'Public Ref Get 2' );
$rv = $class3a->property( 'PubRef', undef );
ok( !$rv, 'Public Ref Set 2' );
$rv = $class3a->property('PubRef');
is( $rv, qr/foo/, 'Public Ref Get 3' );

# Test propertyNames
my @names = $class1a->propertyNames;
is( scalar @names, 1, 'Public Property Names 1' );
@names = $class3b->callNames($class2a);
is( scalar @names, 4, 'Restricted Property Names 1' );
@names = $class2b->callNames($class2a);
is( scalar @names, 7, 'Private Property Names 1' );

# end 07_loadProps.t
