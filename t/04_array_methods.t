# 04_array_methods.t
#
# Tests the array property methods

use Test::More tests => 41;

use strict;
use warnings;

package Foo;

use vars qw(@ISA);
use Class::EHierarchy qw(:all);

@ISA = qw(Class::EHierarchy);

sub _initialize ($@) {
    my $self = shift;
    my @args = @_;

    _declProp( $self, CEH_PRIV | CEH_ARRAY, qw(PrivArray) );
    _declProp( $self, CEH_PUB  | CEH_ARRAY, qw(PubArray) );
    _declProp( $self, CEH_PRIV | CEH_HASH,  qw(PrivHash) );
    _declProp( $self, CEH_PUB  | CEH_HASH,  qw(PubHash) );

    return 1;
}

1;

package main;

my $obj = new Foo;
my $rv;

# Test methods against a private property
$rv = eval '$obj->push(qw(PrivArray one two three)); 1;';
ok( !$rv, 'Private push 1' );
$rv = eval '$obj->pop(qw(PrivArray)); 1;';
ok( !$rv, 'Private pop 1' );
$rv = eval '$obj->unshift(qw(PrivArray one two three)); 1;';
ok( !$rv, 'Private unshift 1' );
$rv = eval '$obj->shift(qw(PrivArray)); 1;';
ok( !$rv, 'Private shift 1' );

# Test methods against a hash property
$rv = eval '$obj->push(qw(PubHash one two three)); 1;';
ok( !$rv, 'Hash push 1' );
$rv = eval '$obj->pop(qw(PubHash)); 1;';
ok( !$rv, 'Hash pop 1' );
$rv = eval '$obj->unshift(qw(PubHash one two three)); 1;';
ok( !$rv, 'Hash unshift 1' );
$rv = eval '$obj->shift(qw(PubHash)); 1;';
ok( !$rv, 'Hash shift 1' );

# Test array methods against a public property
#
# Push
$rv = $obj->push(qw(PubArray one two three));
ok( $rv, 'Public push 1' );
$rv = [ $obj->property('PubArray') ];
is( scalar @$rv, 3, 'Public push verify 1' );
is( $$rv[1], 'two', 'Public push verify 2' );

# Pop
$rv = $obj->pop(qw(PubArray));
is( $rv, 'three', 'Public pop 1' );
$rv = [ $obj->property('PubArray') ];
is( scalar @$rv, 2, 'Public pop verify 1' );
is( $$rv[1], 'two', 'Public pop verify 2' );

# Unshift
$rv = $obj->unshift(qw(PubArray a b c));
ok( $rv, 'Public unshift 1' );
$rv = [ $obj->property('PubArray') ];
is( scalar @$rv, 5, 'Public unshift verify 1' );
is( $$rv[1], 'b',   'Public unshift verify 2' );
is( $$rv[3], 'one', 'Public unshift verify 3' );

# Shift
$rv = $obj->shift(qw(PubArray));
is( $rv, 'a', 'Public shift 1' );
$rv = [ $obj->property('PubArray') ];
is( scalar @$rv, 4, 'Public shift verify 1' );
is( $$rv[1], 'c', 'Public shift verify 2' );

# Test unified methods against a public property
#
# Store
$rv = $obj->store(qw(PubArray 5 foo 6 bar));
ok( $rv, 'Public store 1' );
$rv = [ $obj->property('PubArray') ];
is( scalar @$rv, 7, 'Public store verify 1' );
is( $$rv[4], undef, 'Public store verify 2' );
is( $$rv[5], 'foo', 'Public store verify 3' );
$rv = $obj->store(qw(PubArray foo 5 bar 6));
ok( $rv, 'Public store 2' );
$rv = [ $obj->property('PubArray') ];
is( scalar @$rv, 7, 'Public store verify 4' );
is( $$rv[0], 6,     'Public store verify 5' );

# Retrieve
$rv = [ $obj->retrieve('PubArray', 3 .. 5) ];
is( scalar @$rv, 3, 'Public retrieve verify 1' );
is( $$rv[1], undef, 'Public retrieve verify 2' );
is( $$rv[2], 'foo', 'Public retrieve verify 3' );
$rv = [ $obj->retrieve('PubArray', 3 .. 8) ];
is( scalar @$rv, 6, 'Public retrieve verify 4' );
is( $$rv[5], undef, 'Public retrieve verify 5' );
$rv = [ $obj->retrieve('PubArray', 3 ) ];
is( scalar @$rv, 1, 'Public retrieve verify 6' );
is( $$rv[0], 'two', 'Public retrieve verify 7' );

# Remove
$rv = $obj->remove(qw(PubArray 4 5));
ok( $rv, 'Public remove 1' );
$rv = [ $obj->property('PubArray') ];
is( scalar @$rv, 5, 'Public remove verify 1' );
is( $$rv[4], 'bar', 'Public remove verify 2' );
is( $$rv[3], 'two', 'Public remove verify 2' );

# Purge
$rv = $obj->purge(qw(PubArray));
ok( $rv, 'Public purge 1' );
$rv = [ $obj->property('PubArray') ];
is( scalar @$rv, 0, 'Public purge verify 1' );

# end 04_array_methods.t
