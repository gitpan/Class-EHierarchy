# 05_hash_methods.t
#
# Tests the hash property methods

use Test::More tests => 25;

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
$rv = eval '$obj->exists(qw(PrivHash one)); 1;';
ok( !$rv, 'Private exists 1' );
$rv = eval '$obj->keys(qw(PrivHash)); 1;';
ok( !$rv, 'Private keys 1' );

# Test methods against a array property
$rv = eval '$obj->exists(qw(PubArray one)); 1;';
ok( !$rv, 'Array exists 1' );
$rv = eval '$obj->keys(qw(PubArray)); 1;';
ok( !$rv, 'Array keys 1' );

# Test hash methods against a public property
#
# Exists
$obj->property(qw(PubHash one 1 two 2 three 3));
$rv = $obj->exists(qw(PubHash two));
ok( $rv, 'Public exists 1' );
$rv = { $obj->property('PubHash') };
is( scalar keys %$rv, 3, 'Public exists verify 1' );
is( $$rv{two}, 2, 'Public exists verify 2' );
$rv = $obj->exists(qw(PubHash foo));
ok( !$rv, 'Public exists 2' );

# Keys
$rv = [ sort $obj->keys(qw(PubHash)) ];
is( scalar @$rv, 3, 'Public keys 1' );
is( $$rv[1], 'three', 'Public keys verify 1' );

# Test unified methods against a public property
#
# Store
$rv = $obj->store(qw(PubHash four 4 five 5));
ok( $rv, 'Public store 1' );
$rv = [ sort $obj->keys('PubHash') ];
is( scalar @$rv, 5, 'Public store verify 1' );
is( $$rv[3], 'three', 'Public store verify 2' );

# Retrieve
$rv = [ sort $obj->retrieve(qw(PubHash four two)) ];
is( scalar @$rv, 2, 'Public retrieve verify 1' );
is( $$rv[0], 2, 'Public retrieve verify 2' );
is( $$rv[1], 4, 'Public retrieve verify 3' );
$rv = [ sort $obj->retrieve(qw(PubHash three foo five)) ];
is( scalar @$rv, 3, 'Public retrieve verify 2' );
is( $$rv[0], undef, 'Public retrieve verify 4' );
is( $$rv[1], 3, 'Public retrieve verify 5' );

# Remove
$rv = $obj->remove(qw(PubHash two three));
ok( $rv, 'Public remove 1' );
$rv = [ sort $obj->keys('PubHash') ];
is( scalar @$rv, 3, 'Public remove verify 1' );
is( $$rv[0], 'five', 'Public remove verify 2' );
is( $$rv[1], 'four', 'Public remove verify 2' );

# Purge
$rv = $obj->purge(qw(PubHash));
ok( $rv, 'Public purge 1' );
$rv = [ $obj->keys('PubHash') ];
is( scalar @$rv, 0, 'Public purge verify 1' );

# end 05_hash_methods.t
