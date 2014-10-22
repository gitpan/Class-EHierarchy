# 06_methods.t
#
# Tests the method scoping

use Test::More tests => 20;

use strict;
use warnings;

package Foo;

use vars qw(@ISA);
use Class::EHierarchy qw(:all);

@ISA = qw(Class::EHierarchy);

sub _initialize ($@) {
    my $self = shift;
    my @args = @_;

    _declMethod( $self, CEH_PRIV,  qw(mpriv) );
    _declMethod( $self, CEH_RESTR, qw(mrestr) );
    _declMethod( $self, CEH_PUB,   qw(mpub) );

    return 1;
}

sub mpriv {
    my $self = shift;

    return 2;
}

sub mrestr {
    my $self = shift;

    return 4;
}

sub mpub {
    my $self = shift;

    return 8;
}

sub callpriv {
    my $self = shift;
    my $obj  = shift;

    return $obj->mpriv;
}

sub callrestr {
    my $self = shift;
    my $obj  = shift;

    return $obj->mrestr;
}

1;

package Bar;

use vars qw(@ISA);
use Class::EHierarchy qw(:all);

@ISA = qw(Foo);

sub _initialize ($@) {
    my $self = shift;
    my @args = @_;

    _declMethod( $self, CEH_PRIV,  qw(mpriv) );
    _declMethod( $self, CEH_RESTR, qw(mrestr) );
    _declMethod( $self, CEH_PUB,   qw(mpub) );
    return 1;
}

sub mpriv ($) {
    my $self = shift;

    return 4;
}

sub mrestr {
    my $self = shift;

    return 8;
}

sub mpub {
    my $self = shift;

    return 16;
}

sub callpriv {
    my $self = shift;
    my $obj  = shift;

    return $obj->mpriv;
}

sub callrestr {
    my $self = shift;
    my $obj  = shift;

    return $obj->mrestr;
}

1;

package main;

my $class1a = new Foo;
my $class1b = new Foo;
my $class2a = new Bar;
my $class2b = new Bar;

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
ok( $class2a->isa('Foo'),               'Verify class Bar inheritance 2' );

# Private method tests
#
# Call from same class should succeed
is( $class1a->callpriv($class1b), 2, 'Foo calling Foo Private Method 1' );
is( $class2a->callpriv($class2b), 4, 'Bar calling Bar Private Method 1' );

# Call from different class shoud fail
$rv = eval '$class2a->callpriv($class1a); 1;';
ok( !$rv, 'Bar calling Foo Private Method 1' );
$rv = eval '$class1a->callpriv($class2a); 1;';
ok( !$rv, 'Foo calling Bar Private Method 1' );

# Restricted method tests
#
# Call from same class should succeed
is( $class1a->callrestr($class1b), 4, 'Foo calling Foo Restricted Method 1' );
is( $class2a->callrestr($class2b), 8, 'Bar calling Bar Restricted Method 1' );

# Call from subclass should succeed
is( $class2a->callrestr($class1a), 4, 'Bar calling Foo Restricted Method 1' );

# Call from non-subclass should fail
$rv = eval '$class1a->callrestr($class2a); 1;';
ok( !$rv, 'Foo calling Bar Restricted Method 1' );
$rv = eval '$class1a->mrestr(); 1;';
ok( !$rv, 'Main calling Foo Restricted Method 1' );

# Public method tests
#
# Calls should succeed
is( $class1a->mpub, 8,  'Foo Public Method 1' );
is( $class2a->mpub, 16, 'Bar Public Method 1' );

# end 06_methods.t
