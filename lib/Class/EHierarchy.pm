# Class::EHierarchy -- Base class for hierarchally ordered objects
#
# (c) 2009, Arthur Corliss <corliss@digitalmages.com>
#
# $Id: EHierarchy.pm,v 0.92 2013/06/18 23:13:22 acorliss Exp $
#
#    This software is licensed under the same terms as Perl, itself.
#    Please see http://dev.perl.org/licenses/ for more information.
#
#####################################################################

#####################################################################
#
# Environment definitions
#
#####################################################################

package Class::EHierarchy;

use 5.008003;

use strict;
use warnings;
use vars qw($VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS);
use base qw(Exporter);
use Carp;
use Scalar::Util qw(weaken);

($VERSION) = ( q$Revision: 0.92 $ =~ /(\d+(?:\.(\d+))+)/sm );

# Ordinal indexes for the @objects element records
use constant CEH_OREF  => 0;
use constant CEH_PREF  => 1;
use constant CEH_PKG   => 2;
use constant CEH_SUPER => 3;
use constant CEH_CREF  => 4;
use constant CEH_CNAME => 5;
use constant CEH_ALIAS => 6;

# Ordinal indexes for the @properties element records
use constant CEH_ATTR => 0;
use constant CEH_PPKG => 1;
use constant CEH_PVAL => 2;

# Property attribute masks
use constant CEH_ATTR_SCOPE => 7;
use constant CEH_ATTR_TYPE  => 504;

# Property attribute scopes
use constant CEH_PUB   => 1;
use constant CEH_RESTR => 2;
use constant CEH_PRIV  => 4;

# Property attribute types
use constant CEH_SCALAR => 8;
use constant CEH_ARRAY  => 16;
use constant CEH_HASH   => 32;
use constant CEH_CODE   => 64;
use constant CEH_REF    => 128;
use constant CEH_GLOB   => 256;

# Property flags
use constant CEH_NO_UNDEF => 512;

@EXPORT    = qw();
@EXPORT_OK = qw(CEH_PUB CEH_RESTR CEH_PRIV CEH_SCALAR CEH_ARRAY
    CEH_HASH CEH_CODE CEH_REF CEH_GLOB CEH_NO_UNDEF _declProp
    _declMethod );
%EXPORT_TAGS = ( all => [@EXPORT_OK] );

#####################################################################
#
# Module code follows
#
#####################################################################

{

    # Object list
    #   @objects = ( [ ref:parent_obj, [ ref:child_obj, ... ] ] );
    my @objects;

    # Available IDs
    my @available;

    # Properties
    #   @properties = ( { propName => [ int:attr, value ] } );
    my @properties;

    # Methods
    #   %methods = ( '__PACKAGE__::method' => 1 );
    my %methods;

    # Object aliases
    #   %aliases = ( alias => ref:obj );

    sub _dumpDiags () {

        # Purpose:  Dumps some diagnostic information from class structures
        # Returns:  Boolean
        # Usage:    _dumpDiags();

        my ( $obj, @rec, $i );

        warn "\nCEH Objects: @{[ scalar @objects ]}\n";

        $i = 0;
        foreach $obj (@objects) {
            if ( defined $obj and @rec = @$obj ) {
                foreach (@rec) {
                    $_ = 'undef' unless defined $_;
                }
                warn "CEH Obj #$i: @rec\n";
            } else {
                warn "CEH Obj #$i: unused\n";
            }
            $i++;
        }

        return 1;
    }

    # INTERNAL FUNCTIONS

    sub _ident () {

        # Purpose:  Returns next available ID
        # Returns:  Integer
        # Usage:    $id = _ident();

        return scalar @available ? CORE::shift @available : $#objects + 1;
    }

    sub _regObj (@) {

        # Purpose:  Registers the object for tracking
        # Returns:  Boolean
        # Usage:    $rv = _regObj($oref);

        my $obj = CORE::shift;

        # Initialize internal tracking
        $objects[$$obj]            = [];
        $objects[$$obj][CEH_PREF]  = undef;
        $objects[$$obj][CEH_PKG]   = ref $obj;
        $objects[$$obj][CEH_SUPER] = [];
        $objects[$$obj][CEH_CREF]  = [];
        $objects[$$obj][CEH_CNAME] = __PACKAGE__ . '0';
        $objects[$$obj][CEH_ALIAS] = {};
        $properties[$$obj]         = {};

        return 1;
    }

    sub _deregObj (@) {

        # Purpose:  Removes the object from tracking
        # Returns:  Boolean
        # Usage:    $rv = _deregObj($oref);

        my $obj = CORE::shift;

        # Remove structures and make ID available
        $objects[$$obj] = $properties[$$obj] = undef;
        CORE::push @available, $$obj;

        return 1;
    }

    sub _mergeAliases ($$) {

        # Purpose:  Merges child aliases into parent aliases
        # Returns:  Boolean
        # Usage:    _mergeAliases($parent, $child);

        my $parent = CORE::shift;
        my $child  = CORE::shift;
        my ( @aliases, $alias, $class, $i );

        # Preserve aliases if possible
        @aliases = CORE::keys %{ $objects[$$child][CEH_ALIAS] };
        foreach $alias (@aliases) {
            if ( exists $objects[$$parent][CEH_ALIAS]{$alias} ) {

                # generate new alias
                $i     = 0;
                $class = ref $child;
                while ( exists $objects[$$parent][CEH_ALIAS]{"$class$i"} ) {
                    $i++;
                }
                $objects[$$parent][CEH_ALIAS]{"$class$i"} =
                    $objects[$$child][CEH_ALIAS]{$alias};
                weaken $objects[$$parent][CEH_ALIAS]{"$class$i"};
                $objects[$$child][CEH_CNAME] = "$class$i";

            } else {

                # transfer alias intact
                $objects[$$parent][CEH_ALIAS]{$alias} =
                    $objects[$$child][CEH_ALIAS]{$alias};
                weaken $objects[$$parent][CEH_ALIAS]{$alias};
            }
        }

        # Sync alias hashes
        $objects[$$child][CEH_ALIAS] = $objects[$$parent][CEH_ALIAS];

        return 1;
    }

    sub _spliceAliases ($$) {

        # Purpose:  Splits the aliase tree
        # Returns:  Boolean
        # Usage:    _spliceAliases($parent, $child);

        my $parent   = CORE::shift;
        my $child    = CORE::shift;
        my @children = ( $child, $child->descendants );
        my ( $pref, $cref, $cname );

        $pref = $objects[$$parent][CEH_ALIAS];
        $cref = $objects[$$child][CEH_ALIAS] = {};

        foreach $child (@children) {
            $cname = $objects[$$child][CEH_CNAME];
            delete $$pref{$cname};
            $$cref{$cname} = $child;
            weaken $$cref{$cname};
        }

        return 1;
    }

    sub _assocObj ($@) {

        # Purpose:  Associates objects as children of the parent
        # Returns:  Boolean
        # Usage:    $rv = _assocObj( $parent, $child1, $child2 );

        my $parent  = CORE::shift;
        my @orphans = @_;
        my $rv      = 1;
        my ( $orphan, @descendants, $n, $i, $irv, $class );

        foreach $orphan (@orphans) {
            if ( !defined $orphan ) {

                # Filter out undefined references
                $@  = 'undefined value passed as an object reference';
                $rv = 0;

            } elsif ( !$orphan->isa('Class::EHierarchy') ) {

                # You can only adopt objects derived from this class
                $@ = 'child object isn\'t derived from '
                    . "Class::EHierarchy: $orphan";
                $rv = 0;

            } elsif ( $$parent == $$orphan ) {

                # Really?  You want to adopt yourself?  I'm sensing a chicken
                # and the egg problem...
                $@  = "attempted to adopt one's self: $parent";
                $rv = 0;

            } elsif ( defined $objects[$$orphan][CEH_PREF] ) {

                # We don't allow kidnapping...
                $@  = "attempted kidnapping of a parented child: $orphan";
                $rv = 0;

            } else {

                # Objects are currently orphans...
                #
                # Now, make sure no (grand)?children of the orphan will create
                # a circular reference
                @descendants = $orphan->descendants;
                $irv         = 1;

                # Stop if our proposed parent is in this list
                if ( grep { $$_ == $$parent } @descendants ) {
                    $@ = "circular reference detected between $parent "
                        . "& $orphan";
                    $irv = $rv = 0;
                }

                if ($irv) {

                    # No circular references, so now let's update the records
                    $objects[$$orphan][CEH_PREF] = $parent;
                    weaken( $objects[$$orphan][CEH_PREF] );
                    CORE::push @{ $objects[$$parent][CEH_CREF] }, $orphan;

                    # Merge aliasas
                    _mergeAliases( $parent, $orphan );
                }
            }
        }

        return $rv;
    }

    sub _disassocObj ($@) {

        # Purpose:  Removes the child/parent relationship
        # Returns:  Boolean
        # Usage:    $rv = _disassocObj($parent, $child1, $child2):

        my $parent   = CORE::shift;
        my @children = CORE::shift;
        my $child;

        foreach $child (@children) {

            # Make sure the child actually belongs to the parent
            if ( $objects[$$child][CEH_PREF] == $parent ) {

                # Remove the child objref from the parent's list
                @{ $objects[$$parent][CEH_CREF] } =
                    grep { $_ != $child } @{ $objects[$$parent][CEH_CREF] };

                # Update the child's record
                $objects[$$child][CEH_PREF] = undef;

                # Split aliases
                _spliceAliases( $parent, $child );
            }
        }

        return 1;
    }

    sub _cscope ($$) {

        # Purpose:  Determines the caller's scope in relation to the object
        #           being acted upon
        # Returns:  CEH_PRIV, CEH_RESTR, or CEH_PUB
        # Usage:    $cscope = _cscope($caller, $obj);
        # Usage:    $cscope = _cscope($caller, $pkg);

        my $caller = CORE::shift;
        my $pkg    = CORE::shift;

        # Set $pkg to either the resolved package name (if it's an object
        # reference) or leave it as a plain string package name
        $pkg = $objects[$$pkg][CEH_PKG] unless ref $pkg eq '';

        return
              $caller eq $pkg ? CEH_PRIV
            : "$caller"->isa($pkg) ? CEH_RESTR
            :                        CEH_PUB;
    }

    sub _chkAccess ($$$) {

        # Purpose:  Checks to see if the caller is allowed access to the
        #           requested property.  If the caller is granted access it
        #           will return the name of the property (which may be
        #           adjusted for privately scoped properties), otherwise it
        #           croaks.
        # Returns:  name of property
        # Usage:    $prop = _chkAccess($caller, $prop);

        my $self   = CORE::shift;
        my $caller = CORE::shift;
        my $prop   = CORE::shift;
        my ( $opkg, $cscope, $pscope );

        # Modify the property name for to check for private properties
        $prop = "${caller}::$prop"
            if defined $prop and !exists ${ $properties[$$self] }{$prop};

        if ( defined $prop and CORE::exists ${ $properties[$$self] }{$prop} )
        {

            # Get the object package
            $opkg = $objects[$$self][CEH_PKG];

            # Property CORE::exists, check the caller & property scopes
            $cscope =
                _cscope( $caller, $properties[$$self]{$prop}[CEH_PPKG] );
            $pscope =
                ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_SCOPE;

            unless ( $cscope >= $pscope ) {

                # Caller is not authorized
                $pscope =
                      $pscope == CEH_PRIV  ? 'private'
                    : $pscope == CEH_RESTR ? 'restricted'
                    :                        'public';
                croak "Attempted access of $pscope property $prop by $caller";
            }

        } else {

            # Undefined or nonexistent property
            $prop = '\'undef\'' unless defined $prop;
            croak "Attempted access of nonexistent property $prop";
        }

        return $prop;
    }

    sub __declProp {

        # Purpose:  Registers list of properties as known
        # Returns:  Boolean
        # Usage:    $rv = __declProp($caller, $obj, $attr, @propNames);

        my $caller = CORE::shift;
        my $obj    = CORE::shift;
        my $attr   = CORE::shift;
        my @names  = splice @_;
        my $rv     = 0;
        my $prop;

        if ( defined $attr ) {
            $rv = 1;
            @names = grep {defined} @names;

            # Preprocess private properties to avoid naming conflicts
            if ( $attr & CEH_PRIV ) {

                # Prepend the caller's package to the property names to avoid
                # naming conflicts with subclasses
                foreach (@names) { $_ = "${caller}::$_" }
            }

            foreach $prop (@names) {
                croak "property '$prop' already defined"
                    if CORE::exists ${ $properties[$$obj] }{$prop};

                # Apply default attributes
                $attr |= CEH_SCALAR
                    unless ( $attr ^ CEH_ATTR_TYPE ) > 0;
                $attr |= CEH_PUB
                    unless ( $attr ^ CEH_ATTR_SCOPE ) > 0;

                # Save the properties
                ${ $properties[$$obj] }{$prop}           = [];
                ${ $properties[$$obj] }{$prop}[CEH_ATTR] = $attr;
                ${ $properties[$$obj] }{$prop}[CEH_PPKG] = $caller;
                ${ $properties[$$obj] }{$prop}[CEH_PVAL] =
                      $attr & CEH_ARRAY ? []
                    : $attr & CEH_HASH  ? {}
                    :                     undef;
            }
        }

        return $rv;
    }

    sub _declProp {

        # Purpose:  Wrapper for __declProp, this is the public interface
        # Returns:  RV of __declProp
        # Usage:    $rv = __declProp($obj, $attr, @propNames);

        my $caller = caller;
        my @args   = splice @_;

        return __declProp( $caller, @args );
    }

    sub _loadProps($$) {

        # Purpose:  Loads properties from @_properties
        # Returns:  Boolean
        # Usage:    $rv = _loadProps();

        my $class = CORE::shift;
        my $obj   = CORE::shift;
        my $rv    = 1;
        my ( @_properties, $prop, $pname, $pattr, $pscope );

        # Get the contents of the class array
        {
            no strict 'refs';

            @_properties = @{ *{"${class}::_properties"}{ARRAY} }
                if defined *{"${class}::_properties"};
        }

        # Process the list
        foreach $prop (@_properties) {
            next unless defined $prop;

            unless (
                __declProp( $class, $obj, @$prop[ CEH_ATTR, CEH_PPKG ] ) ) {
                $rv = 0;
                last;
            }

            # Set the default values
            if ( $rv and defined $$prop[CEH_PVAL] ) {

                # Get the attribute type, scope, and internal prop name
                $pattr  = $$prop[CEH_ATTR] & CEH_ATTR_TYPE;
                $pscope = $$prop[CEH_ATTR] & CEH_ATTR_SCOPE;
                $pname =
                    $pscope == CEH_PRIV
                    ? "${class}::$$prop[CEH_PPKG]"
                    : $$prop[CEH_PPKG];

                # Store the default values
                $obj->_setProp( $pname,
                      $pattr == CEH_ARRAY ? @{ $$prop[CEH_PVAL] }
                    : $pattr == CEH_HASH  ? %{ $$prop[CEH_PVAL] }
                    :                       $$prop[CEH_PVAL] );
            }
        }

        return $rv;
    }

    sub _setProp ($$@) {

        # Purpose:  Sets the designated property to the passed value(s).
        #           Does some rough validation according to attributes
        # Returns:  Boolean
        # Usage:    $rv = _setProp($obj, 'foo', qw(one two three));

        my $obj  = CORE::shift;
        my $prop = CORE::shift;
        my @val  = splice @_;
        my $rv   = 0;
        my ( $pattr, $pundef, $pval, $pref );

        # NOTE: since we're screening for valid properties and access
        # rights in the property method we won't be doing any validation
        # here
        $pattr  = ${ $properties[$$obj] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        $pundef = ${ $properties[$$obj] }{$prop}[CEH_ATTR] & CEH_NO_UNDEF;

        # Do some quick validation of references (not necessary for
        # hash/array types)
        if ( $pattr != CEH_ARRAY and $pattr != CEH_HASH ) {
            $pref = ref $val[0];

            if ( not defined $val[0] ) {

                # Only allow undef values if the properties allow
                # undef values
                $rv = 1 if not $pundef;

            } else {

                # Check defined values
                if ( $pattr == CEH_SCALAR ) {
                    $rv = 1 if $pref eq '';
                } elsif ( $pattr == CEH_CODE ) {
                    $rv = 1 if $pref eq 'CODE';
                } elsif ( $pattr == CEH_GLOB ) {
                    $rv = 1 if $pref eq 'GLOB';
                } elsif ( $pattr == CEH_REF ) {
                    $rv = 1 if $pref ne '';
                } else {
                    croak 'something\'s wrong with property attribute '
                        . "type for $prop";
                }
            }
        } else {
            $rv = 1;
        }

        # In this context only hashes and arrays need special handling
        if ($rv) {
            if ( $pattr == CEH_ARRAY ) {
                ${ $properties[$$obj] }{$prop}[CEH_PVAL] = [@val];
            } elsif ( $pattr == CEH_HASH ) {
                ${ $properties[$$obj] }{$prop}[CEH_PVAL] = {@val};
            } else {
                ${ $properties[$$obj] }{$prop}[CEH_PVAL] = $val[0];
            }
        }

        return $rv;
    }

    sub _getProp ($$) {

        # Purpose:  Returns the requested property value, dereferencing
        #           appropriately, depending on property type
        # Returns:  n/a
        # Usage:    $val = _getProp($obj, 'foo');
        # Usage:    @val = _getProp($obj, 'bar');
        # Usage:    %val = _getProp($obj, 'foo');

        my ( $obj, $prop ) = @_;
        my ( $pattr, $pval );

        # NOTE: since we're screening for valid properties and access
        # rights in the property method we won't be doing any validation
        # here
        $pattr = ${ $properties[$$obj] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        $pval  = ${ $properties[$$obj] }{$prop}[CEH_PVAL];

        # In this context only hashes and arrays need special handling
        return
              $pattr == CEH_ARRAY ? @$pval
            : $pattr == CEH_HASH  ? %$pval
            :                       $pval;
    }

    sub __declMethod {

        # Purpose:  Registers a list of methods as scoped
        # Returns:  Boolean
        # Usage:    $rv = __declMethod($class, $attr, @methods);

        my $pkg   = CORE::shift;
        my $attr  = CORE::shift;
        my @names = splice @_;
        my ( $code, $method, $mfqn );

        if ( defined $attr ) {

            # Quiet some warnings
            no warnings qw(redefine prototype);
            no strict 'refs';

            foreach $method (@names) {

                # Get the fully qualified method name and associated code
                # block
                $mfqn = "${pkg}::${method}";
                $code = *{$mfqn}{CODE};

                # Quick check to see if we've done this already -- if so
                # we skip to the next
                next if $methods{$mfqn};

                if ( defined $code ) {

                    # Repackage
                    if ( $attr == CEH_PRIV ) {

                        # Private methods
                        *{$mfqn} = sub {
                            my $caller = caller;
                            goto &{$code} if $caller eq $pkg;
                            croak 'Attempted to call private method '
                                . "$method from $caller";
                        };

                    } elsif ( $attr == CEH_RESTR ) {

                        # Restricted methods
                        *{$mfqn} = sub {
                            my $caller = caller;
                            goto &{$code} if "$caller"->isa($pkg);
                            croak 'Attempted to call restricted method '
                                . "$method from $caller";
                        };
                    }

                } else {
                    croak "Method $method declared but not defined";
                }

                # Record our handling of this method
                $methods{$mfqn} = 1;
            }
        }

        return 1;
    }

    sub _declMethod {

        # Purpose:  Wrapper for __declMethod, this is the public interface
        # Returns:  RV of __declMethod
        # Usage:    $rv = _declMethod($attr, @propNames);

        my $caller = caller;
        my @args   = splice @_;

        return __declMethod( $caller, @args );
    }

    sub _loadMethods {

        # Purpose:  Loads methods from @_methods
        # Returns:  Boolean
        # Usage:    $rv = _loadMethods();

        my $class = CORE::shift;
        my $rv    = 1;
        my ( @_methods, $method );

        # Get the contents of the class array
        {
            no strict 'refs';

            @_methods = @{ *{"${class}::_methods"}{ARRAY} }
                if defined *{"${class}::_methods"};
        }

        # Process the list
        foreach $method (@_methods) {
            next unless defined $method;
            unless ( __declMethod( $class, @$method[ CEH_ATTR, CEH_PPKG ] ) )
            {
                $rv = 0;
                last;
            }
        }

        return $rv;
    }

    # PUBLISHED METHODS

    sub new ($;@) {

        # Purpose:  Object constructor
        # Returns:  Object reference
        # Usage:    $obj = Class->new(@args);

        my $class = CORE::shift;
        my @args  = @_;
        my $self  = bless \do { my $anon_scalar }, $class;
        my ( $rv, @classes, $tclass, $nclass, $l, $n, $isaref );
        my ( %super, $alias );

        # Set the id and register
        $$self = _ident();
        _regObj($self);

        # Assemble a list of superclasses derived from this class that
        # will need initialization
        no strict 'refs';
        $isaref = *{"${class}::ISA"}{ARRAY};
        $isaref = [] unless defined $isaref;
        foreach $tclass (@$isaref) {
            CORE::push @classes, $tclass
                if $tclass ne __PACKAGE__
                    and "$tclass"->isa(__PACKAGE__);
        }
        $n = 0;
        $l = scalar @classes;
        while ( $n < $l ) {
            foreach $tclass ( @classes[ $n .. ( $l - 1 ) ] ) {
                $isaref = *{"${tclass}::ISA"}{ARRAY};
                $isaref = [] unless defined $isaref;
                foreach $nclass (@$isaref) {
                    CORE::push @classes, $nclass
                        if $nclass ne __PACKAGE__
                            and "$nclass"->isa(__PACKAGE__);
                }
            }
            $n = scalar @classes - $l + 1;
            $l = scalar @classes;
        }

        # uniq the superclass list and save it
        %super = map { $_ => 0 } @classes;
        @{ $objects[$$self][CEH_SUPER] } = keys %super;

        # Add our current package to the list
        CORE::unshift @classes, $class;

        # Begin initialization from the top down
        foreach $tclass ( reverse @classes ) {
            unless ( $super{$tclass} ) {

                # First autoload @_properties & @_methods
                $rv = _loadProps( $tclass, $self ) && _loadMethods($tclass);
                unless ($rv) {
                    _deregObj($self);
                    $self = undef;
                    last;
                }

                # Last, call _initialize()
                $rv =
                    defined *{"${tclass}::_initialize"}
                    ? &{"${tclass}::_initialize"}( $self, @args )
                    : 1;

                # Track each super class initialization so we only do
                # it once
                $super{$tclass}++;
            }

            unless ($rv) {
                _deregObj($self);
                $self = undef;
                last;
            }
        }

        # Generate alias
        if ($self) {
            $alias = $objects[$$self][CEH_CNAME];
            $objects[$$self][CEH_ALIAS]{$alias} = $self;
            weaken $objects[$$self][CEH_ALIAS]{$alias};
        }

        return $self;
    }

    sub parent ($) {

        # Purpose:  Returns a reference to the parent object
        # Returns:  Object reference
        # Usage:    $pref = $obj->parent;

        my $self = CORE::shift;

        return $objects[$$self][CEH_PREF];
    }

    sub root ($) {

        # Purpose:  Returns a reference to the ancestral root of the object
        #           tree
        # Returns:  Object reference
        # Usage:    $pref = $obj->root;

        my $self = CORE::shift;
        my ( $obj, $parent );

        $obj = $self;
        while ( defined( $parent = $obj->parent ) ) {
            $obj = $parent;
        }

        return $obj;
    }

    sub children ($) {

        # Purpose:  Returns a list of object references to this object's
        #           children
        # Returns:  Array
        # Usage:    @crefs = $obj->children;

        my $self = CORE::shift;

        return @{ $objects[$$self][CEH_CREF] };
    }

    sub descendants ($) {

        # Purpose:  Returns a list of object references to all
        #           (grand)children of this object
        # Returns:  Array
        # Usage:    @descendants = $obj->descendants;

        my $self     = CORE::shift;
        my @children = @{ $objects[$$self][CEH_CREF] };
        my @rv       = @children;

        foreach (@children) {
            push @rv, $_->descendants;
        }

        return @rv;
    }

    sub siblings ($) {

        # Purpose:  Returns a list of object references to this object's
        #           siblings
        # Returns:  Array
        # Usage:    @crefs = $obj->siblings;

        my $self = CORE::shift;
        my $pref = $objects[$$self][CEH_PREF];
        my @rv;

        @rv = grep { $_ != $self } @{ $objects[$$pref][CEH_CREF] }
            if defined $pref;

        return @rv;
    }

    sub relative ($$) {

        # Purpose:  Returns an object reference for an exact match on
        #           an alias
        # Returns:  Object reference
        # Usage:    $oref = $obj->relative('foo');

        my $self  = CORE::shift;
        my $alias = CORE::shift;
        my $rv;

        if ( defined $alias ) {
            $rv = $objects[$$self][CEH_ALIAS]{$alias}
                if exists $objects[$$self][CEH_ALIAS]{$alias};
        }

        return $rv;
    }

    sub relatives ($$) {

        # Purpose:  Returns an object reference for an regex match on
        #           an alias
        # Returns:  Array
        # Usage:    $oref = $obj->relatives('foo');

        my $self  = CORE::shift;
        my $alias = CORE::shift;
        my ( @aliases, @rv );

        if ( defined $alias ) {
            @aliases = grep m#^\Q$alias\E#sm,
                keys %{ $objects[$$self][CEH_ALIAS] };
            foreach $alias (@aliases) {
                push @rv, $objects[$$self][CEH_ALIAS]{$alias};
            }
        }

        return @rv;
    }

    sub alias ($;$) {

        # Purpose:  Get/Set object alias
        # Returns:  String/Boolean
        # Usage:    $rv = $obj->alias;

        my $self  = CORE::shift;
        my $alias = CORE::shift;
        my $rv;

        if ( defined $alias ) {

            # Set alias
            if ( exists $objects[$$self][CEH_ALIAS]{$alias} ) {

                # Alias already in use -- fail
                $rv = 0;

            } else {

                # Move to new alias
                delete $objects[$$self][CEH_ALIAS]
                    { $objects[$$self][CEH_CNAME] };
                $objects[$$self][CEH_ALIAS]{$alias} = $self;
                $objects[$$self][CEH_CNAME] = $alias;
                weaken $objects[$$self][CEH_ALIAS]{$alias};
                $rv = 1;
            }

        } else {

            # Get alias
            $rv = $objects[$$self][CEH_CNAME];
        }

        return $rv;
    }

    sub adopt ($@) {

        # Purpose:  Adopts the passed object references as children
        # Returns:  Boolean
        # Usage:    $rv = $obj->adopt($cobj1, $cobj2);

        my $self     = CORE::shift;
        my @children = @_;
        my $rv       = 0;

        $rv = _assocObj( $self, @children ) if @children;

        return $rv;
    }

    sub disown ($@) {

        # Purpose:  Disowns the passed object references as children
        # Returns:  Boolean
        # Usage:    $rv = $obj->disown($cobj1, $cobj2);

        my $self     = CORE::shift;
        my @children = @_;

        return _disassocObj( $self, @children );
    }

    sub property ($$;$) {

        # Purpose:  Gets/sets the requested property
        # Returns:  Boolean on value sets, value on gets
        # Usage:    @numbers = $obj->property('numbers');
        # Usage:    $rv = $obj->property('numbers',
        #                 qw(555-1212 999-1111));

        my $self   = CORE::shift;
        my $prop   = CORE::shift;
        my @values = @_;
        my $caller = caller;
        my ($rv);

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Caller is authorized, determine the mode
        if (@values) {

            # set mode
            return _setProp( $self, $prop, @values );

        } else {

            # get mode
            return _getProp( $self, $prop );
        }

        return 1;
    }

    sub propertyNames ($) {

        # Purpose:  Returns a list of all property names
        # Returns:  Array
        # Usage:    @names = $obj->propertyNames;

        my $self   = CORE::shift;
        my $caller = caller;
        my ( $opkg, $cscope, $pscope, @rv );

        # Get the object package
        $opkg = $objects[$$self][CEH_PKG];

        # Property CORE::exists, check the caller & property scopes
        $cscope = _cscope( $caller, $opkg );

        # Iterate over all properties get the ones accessible to the caller
        foreach ( keys %{ $properties[$$self] } ) {
            $pscope = ${ $properties[$$self] }{$_}[CEH_ATTR] & CEH_ATTR_SCOPE;
            next
                if $pscope == CEH_PRIV
                    and ${ $properties[$$self] }{$_}[CEH_PPKG] ne $opkg;
            CORE::push @rv, $_ if $cscope >= $pscope;
        }

        return @rv;
    }

    # Array-specific methods

    sub push ($$@) {

        # Purpose:  pushes values onto the requested array property,
        # Returns:  The return value of the CORE::push
        # Usage:    $rv = $obj->push($prop, @values);

        my $self   = CORE::shift;
        my $prop   = CORE::shift;
        my @values = splice @_;
        my $caller = caller;
        my $pattr;

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's an array
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't push values onto a non-array like $prop"
            unless $pattr == CEH_ARRAY;

        # push the values
        return CORE::push @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] },
            @values;
    }

    sub pop ($$) {

        # Purpose:  pops values off of the requested array property,
        # Returns:  The return value of CORE::pop
        # Usage:    $rv = $obj->pop($prop);

        my $self   = CORE::shift;
        my $prop   = CORE::shift;
        my $caller = caller;
        my $pattr;

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's an array
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't pop values off of a non-array like $prop"
            unless $pattr == CEH_ARRAY;

        # pop the values
        return CORE::pop @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] };
    }

    sub unshift ($$@) {

        # Purpose:  unshifts values onto the requested array property,
        # Returns:  The return value of the CORE::unshift
        # Usage:    $rv = $obj->unshift($prop, @values);

        my $self   = CORE::shift;
        my $prop   = CORE::shift;
        my @values = splice @_;
        my $caller = caller;
        my $pattr;

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's an array
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't unshift values onto a non-array like $prop"
            unless $pattr == CEH_ARRAY;

        # unshift the values
        return CORE::unshift @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] },
            @values;
    }

    sub shift ($$) {

        # Purpose:  shifts values off of the requested array property,
        # Returns:  The return value of CORE::shift
        # Usage:    $rv = $obj->shift($prop);

        my $self   = CORE::shift;
        my $prop   = CORE::shift;
        my $caller = caller;
        my $pattr;

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's an array
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't shift values off of a non-array like $prop"
            unless $pattr == CEH_ARRAY;

        # shift the values
        return CORE::shift @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] };
    }

    # Hash-specific methods

    sub exists ($$$) {

        # Purpose:  checks the existance of a key in the property hash
        # Returns:  The return value of CORE::exists
        # Usage:    $rv = $obj->exists($prop, $key);

        my $self   = CORE::shift;
        my $prop   = CORE::shift;
        my $key    = CORE::shift;
        my $caller = caller;
        my $pattr;

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's a hash
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't check for a key in a non-hash like $prop"
            unless $pattr == CEH_HASH;

        # Check for the key
        return CORE::exists ${ ${ $properties[$$self] }{$prop}[CEH_PVAL] }
            {$key};
    }

    sub keys ($$) {

        # Purpose:  Retrieves a list of keys of the given hash property
        # Returns:  The return value of CORE::keys
        # Usage:    $rv = $obj->keys($prop, $key);

        my $self   = CORE::shift;
        my $prop   = CORE::shift;
        my $caller = caller;
        my $pattr;

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's a hash
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't check for keys in a non-hash like $prop"
            unless $pattr == CEH_HASH;

        # Get the keys
        return CORE::keys %{ ${ $properties[$$self] }{$prop}[CEH_PVAL] };
    }

    # Unified hash/array methods

    sub store ($$@) {

        # Purpose:  Adds elements to either an array or hash
        # Returns:  Boolean
        # Usage:    $rv = $obj->add($prop, foo => bar);
        # Usage:    $rv = $obj->add($prop, 4 => foo, 5 => bar);

        my $self   = CORE::shift;
        my $prop   = CORE::shift;
        my @pairs  = splice @_;
        my $caller = caller;
        my ( $pattr, $i, $v );

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's an array or hash
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't retrieve values for non-hash/arrays like $prop"
            unless $pattr == CEH_HASH
                or $pattr == CEH_ARRAY;

        if ( $pattr == CEH_HASH ) {

            # Add the key-pairs
            %{ ${ $properties[$$self] }{$prop}[CEH_PVAL] } =
                ( %{ ${ $properties[$$self] }{$prop}[CEH_PVAL] }, @pairs );

        } else {

            # Set the values to the specified indices
            while (@pairs) {
                $i = CORE::shift @pairs;
                $v = CORE::shift @pairs;
                ${ $properties[$$self] }{$prop}[CEH_PVAL][$i] = $v;
            }
        }

        return 1;
    }

    sub retrieve ($$@) {

        # Purpose:  Retrieves all the requested array or hash property
        #           elements
        # Returns:  List of values
        # Usage:    @values = $obj->retrieve($array, 3 .. 5 );
        # Usage:    @values = $obj->retrieve($hash, qw(foo bar) );

        my $self     = CORE::shift;
        my $prop     = CORE::shift;
        my @elements = splice @_;
        my $caller   = caller;
        my ( $pattr, $rv );

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's an array or hash
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't retrieve values for non-hash/arrays like $prop"
            unless $pattr == CEH_HASH
                or $pattr == CEH_ARRAY;

        if ( $pattr == CEH_ARRAY ) {
            if ( @elements == 1 and !wantarray ) {
                return ${ ${ $properties[$$self] }{$prop}[CEH_PVAL] }
                    [ $elements[0] ];
            } else {
                return @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] }
                    [@elements];
            }
        } else {
            if ( @elements == 1 and !wantarray ) {
                return ${ ${ $properties[$$self] }{$prop}[CEH_PVAL] }
                    { $elements[0] };
            } else {
                return @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] }
                    {@elements};
            }
        }

        return 1;
    }

    sub remove ($$@) {

        # Purpose:  Removes the specified elements from the hash or array
        # Returns:  Boolean
        # Usage:    $obj->remove($prop, @keys);

        my $self     = CORE::shift;
        my $prop     = CORE::shift;
        my @elements = splice @_;
        my $caller   = caller;
        my ( $pattr, $i, @narray );

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's an array or hash
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't remove values for non-hash/arrays like $prop"
            unless $pattr == CEH_HASH
                or $pattr == CEH_ARRAY;

        if ( $pattr == CEH_ARRAY ) {
            @narray = @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] };
            ${ $properties[$$self] }{$prop}[CEH_PVAL] = [];
            foreach ( $i = 0; $i <= $#narray; $i++ ) {
                next if grep { $_ == $i } @elements;
                CORE::push @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] },
                    $narray[$i];
            }
        } else {
            delete @{ ${ $properties[$$self] }{$prop}[CEH_PVAL] }{@elements};
        }

        return 1;
    }

    sub purge ($$) {

        # Purpose:  Empties the specified hash or array property
        # Returns:  Boolean
        # Usage:    $obj->remove($prop);

        my $self     = CORE::shift;
        my $prop     = CORE::shift;
        my @elements = splice @_;
        my $caller   = caller;
        my ( $pattr, $i, @narray );

        # Check for access rights
        $prop = _chkAccess( $self, $caller, $prop );

        # Make sure it's an array or hash
        $pattr = ${ $properties[$$self] }{$prop}[CEH_ATTR] & CEH_ATTR_TYPE;
        croak "Can't remove values for non-hash/arrays like $prop"
            unless $pattr == CEH_HASH
                or $pattr == CEH_ARRAY;

        ${ $properties[$$self] }{$prop}[CEH_PVAL] =
            $pattr == CEH_ARRAY ? [] : {};

        return 1;
    }

    sub DESTROY ($) {

        # Purpose:  Walks the child heirarchy and releases all those
        #           children before finally releasing this object
        # Returns:  Boolean
        # Usage:    $obj->DESTROY;

        my $self = CORE::shift;
        my ( @descendants, $child, $parent );

        if ( defined $objects[$$self] ) {

            # Working backwards we'll disown each child and release it
            @descendants = $self->descendants;
            foreach $child ( reverse @descendants ) {
                $parent = $child->parent;
                $parent = $self unless defined $parent;
                $parent->disown($child);
                $child = undef;
            }

            # Third, execute the _deconstruct method if it exists
            $self->_deconstruct if $self->can('_deconstruct');

            # Fourth, deregister object
            _deregObj($self);
        }

        return 1;
    }
}

1;

__END__

=head1 NAME

Class::EHierarchy - Base class for hierarchally ordered objects

=head1 VERSION

$Id: EHierarchy.pm,v 0.92 2013/06/18 23:13:22 acorliss Exp $

=head1 SYNOPSIS

    package TelDirectory;

    use Class::EHierarchy qw(:all);
    use vars qw(@ISA @_properties @_methods);

    @ISA = qw(Class::EHierarchy);
    @_properties = (
        [ CEH_PRIV | CEH_SCALAR, 'counter',  0 ],
        [ CEH_PUB | CEH_SCALAR,  'first',   '' ],
        [ CEH_PUB | CEH_SCALAR,  'last',    '' ],
        [ CEH_PUB | CEH_ARRAY,   'telephone'   ]
        );
    @_methods = (
        [ CEH_PRIV,    '_incrCounter' ],
        [ CEH_PUB,     'addTel'       ]
        );

    sub _initalize {
        my $obj     = shift;
        my %args    = @_;
        my $rv      = 1;

        # Statically defined properties and methods are 
        # defined above.  Dynamically generated/defined 
        # poperties and methods can be done here.

        return $rv;
    }

    ...

    package main;

    use TelDirectory;

    my $entry = new TelDirectory;

    $entry->property('first', 'John');
    $entry->property('last',  'Doe');
    $entry->push('telephone', '555-111-2222', '555-555'5555');

=head1 DESCRIPTION

B<Class::EHierarchy> is intended for use as a base class for custom objects,
but objects that need one or more of the following features:

=over

=item * orderly bottom-up destruction of objects

=item * opaque objects

=item * class-based access restrictions for properties and methods

=item * primitive strict property type awareness

=item * alias-based object retrieval

=back

Each of the above features are described in more depth in the following
subsections:

=head2 ORDERLY DESTRUCTION

Objects can I<adopt> other objects which creates a tracked relationship 
within the class itself.  Those child objects can, in turn, adopt objects 
of their own.  The result is a hierarchal tree of objects, with the parent 
being the trunk.

Perl uses a reference-counting garbage collection system which destroys
objects and data structures as the last reference to it goes out of scope.
This results in an object being destroyed before any internal data structures
or objects referenced internally.  In most cases this works just fine since
many programs really don't care how things are destroyed, just as long as they
are.

Occasionally, though, we do care.  Take, for instance, a database-backed
application that delays commits to the database until after all changes are
made.  Updates made to a collection of records can be flushed as as the parent
object goes out of scope.  In a regular object framework the parent object
would be released, which could be a problem if it owned the database
connection object.  In this framework, though, the children are pre-emptively
released first, triggering their DESTROY methods beforehand, in which the
database commit is made:

    Database Object
        +--> Table1
        |       +--> Row1
        |       +--> Row2
        +--> Table2
                +--> Row1

This, in a nutshell, is the primary purpose of this class.

=head2 OPAQUE OBJECTS

Objects based on this class will be opaque objects instead of the traditional
blessed hash references in which the hash elements could be access directly
through dereferencing.  This prevents access to internal data structures 
outside of the published interface.  This does mean, though, that you can't
access your data directly, either.  You must use a provided method to
retrieve that data from the class storage.

=head2 ACCESS RESTRICTIONS

A benefit of having an opaque object is that allows for scoping of both
properties and methods.  This provides for the following access restrictions:

    private         accessible only to members of this object's class
    restricted      accessible to members of this object's class  
                    and subclasses
    public          globally accessible

Attempts to access either from outside the approved scope will cause the code
to croak.  There is an exception, however:  private properties.  This aren't
just protected, they're hidden.  This allows various subclasses to use the
same names for internal properties without fear of name space violations.

=head2 PROPERTY TYPE AWARENESS

Properties can be explicitly declared to be of certain primitive data types.
This allows some built in validation of values being set.  Known scalar value
types are scalar, code, glob, and reference.

Properties can also house hashes and arrays.  When this is leveraged it allows
for properties contents to be managed in ways similar to their raw
counterparts.  You can retrieve individual elements, add, set, test for, and
so on.

=head2 ALIASES

In a hierarchal system of object ownership the parent objects have strong
references to their children.  This frees you from having to code and track
object references yourself.  Sometimes, however, it's not always convenient or
intuitive to remember which parent owns what objects when you have a
multilevel hierarchy.  Because of that this class implements an alias system
to make retrieval simpler.

Aliases are unique within each hierarchy or tree.  Consider the following
hierarchy in which every node is an object member:

  Application
     +--> Display
     |       +--> Window1
     |       |      +--> Widget1
     |       |      +--> Widget2
     |       |      +--> Widget3
     |       +--> Window2
     |              +--> Widget1
     +--> Database Handle
     +--> Network Connections

Giving each node a plain name, where it makes sense, makes it trivial for a
widget to retrieve a reference to the database object to get or update data.

Aliases can also be search via base names, making it trival to get a list of
windows that may need to be updated in a display.

=head1 SUBROUTINES/METHODS

Subroutines and constants are provided strictly for use by derived classes 
within their defined methods.  To avoid any confusion all of our exportable 
symbols are *not* exported by default.  You have to specifically import the 
B<all> tag set.  Because these subroutines should not be used outside of the 
class they are all preceded by an underscore, like any other private function.

Methods, on the other hand, are meant for direct and global use.  With the
exception of B<new> and B<DESTROY> they should all be safe to override.

The following subroutines, methods, and/or constants are are orgnanized
according to their functional domain (as outlined above).

=head2 INSTANTIATION/DESTRUCTION

All classes based on this class must use the I<new> constructor and I<DESTROY>
deconstructor provided by this class.  That said, subclasses still have an
opportunity to do work in both phases.

Before that, however, B<Class::EHierarchy> prepares the base object, defining
and scoping properties and methods automatically based on the presence of
class variables I<@_properties> and I<@_methods>:

    package Contact;

    use Class::EHierarchy qw(:all);
    use vars qw(@ISA @_properties @_methods);

    @ISA = qw(Class::EHierarchy);
    @_properties = (
        [ CEH_PUB | CEH_SCALAR, 'first' ],
        [ CEH_PUB | CEH_SCALAR, 'last' ],
        [ CEH_PUB | CEH_ARRAY,  'telephone' ],
        [ CEH_PUB | CEH_SCALAR, 'email' ],
        );
    @_methods = (
        [ CEH_PUB, 'full_name' ],
        );

    sub _initialize {
        my $obj = shift;
        my $rv  = 1;

        ....

        return $rv;
    }

    sub _deconstruct {
        my $obj = shift;
        my $rv  = 1;

        ....

        return $rv;
    }

    sub full_name {
        my $obj = shift;

        return $obj->property('first') . ' ' .
               $obj->property('last');
    }

Both methods and properties are defined by their access scope.  Properties
also add in primitive data types.  The constants used to designate these
attributes are as follows:

    Scope
    ---------------------------------------------------------
    CEH_PRIV        private scope
    CEH_RESTR       restricted scope
    CEH_PUB         public scope

    Type
    ---------------------------------------------------------
    CEH_SCALAR      scalar value or reference
    CEH_ARRAY       array
    CEH_HASH        hash
    CEH_CODE        code reference
    CEH_GLOB        glob reference
    CEH_REF         object reference

    Flag
    ---------------------------------------------------------
    CEH_NO_UNDEF    No undef values are allowed to be 
                    assigned to the property

You'll note that both I<@_properties> and I<@_methods> are arrays of arrays,
which each subarray containing the elements for each property or method.  The
first element is always the attributes and the second the name of the property
or method.  In the case of the former a third argument is also allowed:  a
default value for the property:

  @_properties = (
        [ CEH_PUB | CEH_SCALAR, 'first',     'John' ],
        [ CEH_PUB | CEH_SCALAR, 'last',      'Doe' ],
        [ CEH_PUB | CEH_ARRAY,  'telephone', 
            [ qw(555-555-1212 555-555-5555) ] ],
    );

Properties lacking a data type attribute default to B<CEH_SCALAR>.  Likewise,
scope defaults to B<CEH_PUB>.  Public methods can be omitted from I<@_methods> 
since they will be assumed to be public.

=head3 new

    $obj = Class::Foo->new(@args);

This method must not be overridden in any subclass, but be used as-is.  That
said, subclasses still have complete control over whether this method call
succeeds via the B<_initialize> method, which all subclasses must provide
themselves.

When the object contsructor is called an object is instantiated, then
B<_initialize> is called with all of the B<new> arguments passed on unaltered.
The B<_initialize> method is responsible for an internal initialization
necessary as well as any validation.  It must return a boolean value which
determines whether a valid object reference is returned by the B<new> method,
or undef.

B<NOTE:> all superclasses based on L<Class::EHierarchy> containing a 
B<_initialize> method will also be called, all prior to the current subclass' 
method.

=head3 _initialize

    sub _initialize {
        my $obj  = shift;
        my %args = @_;       # or @args = $_;
        my $rv   = 1;

        # Random initialization stuff here

        return $rv;
    }

Once the basic object has been constructed it calls the I<_initialize> method,
giving it a complete set of the arguments the constructor was called with.
The form of those arguments, whether as an associative array or simple array,
is up to the coder.

You can do whatever you want in this method, including creating and adopting
child objects.  You can also dynamically generate properties and methods using
the I<_declProp> and I<_declMethod> class functions.  Both are documented below.

This method must return a boolean value.  A false return value will cause the
constructor to tear everything back down and return B<undef> to the caller.

=head3 _declProp

    $rv = _declProp($obj, SCOPE | TYPE | FLAG, @propNames);

This function is used to create named properties while declaring they access 
scope and type.

Constants describing property attributes are OR'ed together, and only one
scope and one type from each list should be used at a time.  Using multiple
types or scopes to describe any particular property will make it essentially
inaccessible.

Type, if omitted, defaults to I<CEH_SCALAR>,  Scope defaults to I<CEH_PUB>.

B<NOTE:>  I<CEH_NO_UNDEF> only applies to psuedo-scalar types like proper
scalars, references, etc.  This has no effect on array members or hash values.

=head3 _declMethod

    $rv = _declMethod($attr, @methods);

This function is is used to create wrappers for those functions whose access 
you want to restrict.  It works along the same lines as properties and uses 
the same scoping constants for the attribute.

Only methods defined within the subclass can have scoping declared.  You
cannot call this method for inherited methods.

B<NOTE:> Since scoping is applied to the class symbol table (B<not> on a 
per object basis) any given method can only be scoped once.  That means you 
can't do crazy things like make public methods private, or vice-versa.

=head3 DESTROY

A B<DESTROY> method is provided by this class and must not be overridden by
any subclass.  It is this method that provides the ordered termination
property of hierarchal objects.  Any code you wish to be executed during this
phase can be put into a B<_deconstruct> method in your subclass.  If it's
available it will be executed after any children have been released.

=head3 _deconstruct

    sub _deconstruct {
        my $obj = shift;
        my $rv  = 1;

        # Do random cleanup stuff here

        return $rv;
    }

This method is optional, but if needed must be provided by the subclass.  It
will be called during the B<DESTROY> phase of the object.

=head2 ORDERLY DESTRUCTION

In order for objects to be destroyed from the bottom up it is important to
track the hierarchal relationship between them.  This class uses a familial
parent/child paradigm for doing so.

In short, objects can I<adopt> and I<disown> other objects.  Adopted objects
become children of the parent object.  Any object being destroyed preemptively
triggers deconstruction routines on all of its children before cleaning up
itself.  This ensures that any child needing parental resources for final
commits, etc., has those available.

Additional methods are also present to make it easier for objects to interact
with their immediate family of objects.  Those are documented in this section.
More powerful methods also exist as part of the alias system and are
documented in their own section.

=head3 adopt

    $rv = $obj->adopt($cobj1, $cobj2);

This method attempts to adopt the passed objects as children.  It returns a
boolean value which is true only if all objects were successfully adopted.
Only subclasses for L<Class::EHierarchy> can be adopted.  Any object that
isn't based on this class will cause this method to return a false value.

=head3 disown

    $rv = $obj->disown($cobj1, $cobj2);

This method attempts to disown all the passed objects as children.  It returns
a boolean value based on its success in doing so.  Asking it to disown an
object it had never adopted in the first place will be silently ignored and
still return true.

Disowning objects is a prerequisite for Perl's garbage collection to work and
release those objects completely from memory.  The B<DESTROY> method provided
by this class automatically does this for parent objects going out of scope.
You may still need to do this explicitly if your parent object manages objects
which may need to be released well prior to any garbage collection on the
parent.

=head3 parent

    $parent = $obj->parent;

This method returns a reference to this object's parent object, or undef if it
has no parent.

=head3 children

    @crefs = $obj->children;

This method returns an array of object references to every object that was
adopted by the current object.

=head3 descendants

    @descendants = $obj->descendants;

This method returns an array of object references to every object descended
from the current object.

=head3 siblings

    @crefs = $obj->siblings;

This method returns an array of object references to every object that shares
the same parent as the current object.

=head3 root

    $root = $obj->root;

This method returns a reference to the root object in this object's ancestral
tree.  In other words, the senior most parent in the current hierarchy.

=head2 OPAQUE OBJECTS

Opaque objects can't access their own data directly, and so must use methods
to access them.  There is one principle method for doing so, but note that in
a later section a whole suite of convenience functions also exist to make hash
and array property access easier.

=head3 property

    $val = $obj->property('FooScalar');
    @val = $obj->property('FooArray');
    %val = $obj->property('FooHash');
    $rv  = $obj->property('FooScalar', 'random text or reference');
    $rv  = $obj->property('FooArray', @foo);
    $rv  = $obj->property('FooHash',  %foo);

This method provides a generic property accessor that abides by the scoping
attributes given by B<_declProp>.  This means that basic reference types are
checked for during assignment, as well as flags like B<CEH_NO_UNDEF>.

A boolean value is returned on attempts to set values.

Any attempt to access a nonexistent property will cause the code to croak.

B<NOTE:> Given that the presence of additional arguments after the property
name sets this method into 'write' mode, there is obviously no way to use this
to empty a hash or array property.  For that please see the L<purge> method 
below.

=head3 propertyNames

    @properties = $obj->propertyNames;

This method returns a list of all registered properties for the current
object.  Property names will be filtered appropriately by the caller's 
context.

=head2 ACCESS RESTRICTIONS

This section is actually covered as part of L<INSTANTIATION/DESTRUCTION>
above.

=head2 PROPERTY TYPE AWARENESS

Properties are validated automatically on set attempts for the various scalar
types (code, glob, reference, scalar value), as well as arrays and hashes.
Working through a single accessor method for individual array or hash
elements, however, can be very inconvenient.  For that reason many common
array/hash functions have been implemented as methods.

=head3 push

    $rv = $obj->push($prop, @values);

This method pushes additional elements onto the specified array property.
Calling this method on any non-array property will cause the program to croak.
It returns the return value from the B<push> function.

=head3 pop

    $rv = $obj->pop($prop);

This method pops an element off of the specified array property.  Calling 
this method on any non-array property will cause the program to croak.  It 
returns the return value from the B<pop> function.

=head3 unshift

    $rv = $obj->unshift($prop, @values);

This method unshifts additional elements onto the specified array property.
Calling this method on any non-array property will cause the program to croak.
It returns the return value from the B<unshift> operation.

=head3 shift

    $rv = $obj->shift($prop);

This method shifts an element off of the specified array property.  Calling 
this method on any non-array property will cause the program to croak.  It 
returns the return value from the B<shift> operation.

=head3 exists

    $rv = $obj->exists($prop, $key);

This method checks for the existance of the specified key in the hash
property.  Calling this method on any non-hash property will cause the program
to croack.  It returns the return value from the B<exists> function.

=head3 keys

    @keys = $obj->keys($prop);

This method returns a list of keys from the specified hash property.  Calling
this method on any non-hash property will cause the program to croak.  It
returns the return value from the B<keys> function.

=head3 store

    $obj->add($prop, foo => bar);
    $obj->add($prop, 4 => foo, 5 => bar);

This method is a unified method for storing elements in both hashes and 
arrays.  Hashes elements are simply key/value pairs, while array elements 
are provided as ordinal index/value pairs.

=head3 retrieve

    @values = $obj->retrieve($hash, qw(foo bar) );
    @values = $obj->retrieve($array, 3 .. 5 );

This method is a unified method for retrieving specific element(s) from both
hashes and arrays.  Hash values are retrieved in the order of the specified
keys, while array elements are retrieved in the order of the specified ordinal
indexes.

=head3 remove

    $obj->remove($prop, @keys);
    $obj->remove($prop, 5, 8 .. 10);

This method is a unified method for removing specific elements from both
hashes and arrays.  A list of keys is needed for hash elements, a list of
ordinal indexes is needed for arrays.

B<NOTE:> In the case of arrays please note that an element removed in the
middle of an array does cause the following elements to be shifted
accordingly.  This method is really only useful for removing a few elements at
a time from an array.  Using it for large swaths of elements will likely prove
it to be poorly performing.  You're better of retrieving the entire array
yourself via the B<property> method, splicing what you need, and calling
B<property> again to set the new array contents.

=head3 purge

    $obj->purge($prop);

This is a unified method for purging the contents of both array and hash
properties.

=head2 ALIASES

=head3 alias

    $rv = $obj->alias($new_alias);
    $alias = $obj->alias;

This method gets/sets the alias for the object.  Gets always return a string,
while sets return a boolean value.  This can be false if the proposed alias is
already in use by another object in its hierarchy.

=head3 relative

  $oref = $obj->relative($name);

This method retrieves the object known under the passed alias.

=head3 relatives

  @orefs = $obj->relatives($name);

This method retrieves a list of all objects with aliases beginning with the
passed name.

=head1 DEPENDENCIES

None.

=head1 BUGS AND LIMITATIONS 

As noted in the L<CREDIT> section below portions of the concept and
implementation of opaque objects were taken from Damian Conway's module
L<Class::Std(3)>.  I have chosen to deviate from his implementation in a 
few key areas, and any or all of them might be considered bugs and/or 
limitations.

Damian relies on an I<ident> function in his module to provide each module
with a unique identifier.  Unfortunately, when retrieving internal data
structures he wants you to use them for each and every retrieval.  While
effective, this exercises the stack a bit more and provides a performance
penalty.

To avoid that penalty I chose to store the ID in the anonymous
scalar we referenced as part of object instantiation.  While in theory this
could be overwritten and wreak havoc in the class data structures I think the
performance benefits outweigh it.  I am hedging that most of us won't
accidentally dereference our object reference and overwrite it.

Another benefit of storing the ID directly is that the code you'll write based
on this class looks a lot more like traditional Perl OO.  If you're a devout
Damian disciple that's probably not a benefit, but his 'I<$attr_foo{ident
$self}>' notation really rubs me the wrong way.

Another performance concern I had with Class::Std was the heavy reliance on
internal hashes.  This penalizes you on both memory and performance
utilization.  So, I changed my internal I<_ident> function to be based purely
on an ordinal index value, which allowed me to use arrays to store all of the
applicable class data.

End sum, this module gives you the hierarchal qualities I needed along with
some of the opaque object benefits of L<Class::Std(3)>, but in a manner 
that possibly interferes less with one's natural style of coding while being
generally more efficient and system friendly.

=head1 CREDIT

The notion and portions of the implementation of opaque objects were lifted
from Damian Conway's L<Class::Std(3)> module.  Conway has a multitude of great
ideas, and I'm grateful that he shares so much with the community.

=head1 AUTHOR 

Arthur Corliss (corliss@digitalmages.com)

=head1 LICENSE AND COPYRIGHT

This software is licensed under the same terms as Perl, itself. 
Please see http://dev.perl.org/licenses/ for more information.

(c) 2009, Arthur Corliss (corliss@digitalmages.com)

