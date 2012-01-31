# Class::EHierarchy -- Base class for hierarchally ordered objects
#
# (c) 2009, Arthur Corliss <corliss@digitalmages.com>
#
# $Id: EHierarchy.pm,v 0.91 2012/01/31 00:36:46 acorliss Exp $
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

use 5.006;

use strict;
use warnings;
use vars qw($VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS);
use base qw(Exporter);
use Carp;

($VERSION) = ( q$Revision: 0.91 $ =~ /(\d+(?:\.(\d+))+)/sm );

# Ordinal indexes for the @objects element records
use constant CEH_PID   => 0;
use constant CEH_PKG   => 1;
use constant CEH_SUPER => 2;
use constant CEH_CREF  => 3;

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
    _declMethod);
%EXPORT_TAGS = ( all => [@EXPORT_OK] );

#####################################################################
#
# Module code follows
#
#####################################################################

{

    # Object list
    #   @objects = ( [ int:parent_id, [ ref:child_obj, ... ] ] );
    my @objects;

    # Available IDs
    my @available;

    # Properties
    #   @properties = ( { propName => [ int:attr, value ] } );
    my @properties;

    # Methods
    #   %methods = ( '__PACKAGE__::method' => 1 );
    my %methods;

    # INTERNAL FUNCTIONS

    sub _ident () {

        # Purpose:  Returns next available ID
        # Returns:  Integer
        # Usage:    $id = _ident();

        return scalar @available ? CORE::shift @available : $#objects + 1;
    }

    sub _regObj (@) {

        # Purpose:  Registers the object for tracking
        # Returns:  True if successful
        # Usage:    $rv = _regObj($oref);

        my $obj = CORE::shift;

        # Initialize internal tracking
        $objects[$$obj]            = [];
        $objects[$$obj][CEH_PID]   = undef;
        $objects[$$obj][CEH_PKG]   = ref $obj;
        $objects[$$obj][CEH_SUPER] = [];
        $objects[$$obj][CEH_CREF]  = [];
        $properties[$$obj]         = {};

        return 1;
    }

    sub _deregObj (@) {

        # Purpose:  Removes the object from tracking
        # Returns:  True if successful
        # Usage:    $rv = _deregObj($oref);

        my $obj = CORE::shift;

        # Remove structures and make ID available
        $objects[$$obj] = $properties[$$obj] = undef;
        CORE::push @available, $$obj;

        return 1;
    }

    sub _assocObj ($@) {

        # Purpose:  Associates objects as children of the parent
        # Returns:  True, unless circular reference is found or
        #           a child candidate already has a parent
        # Usage:    $rv = _assocObj( $parent, $child1, $child2 );

        my $parent  = CORE::shift;
        my @orphans = @_;
        my $rv      = 1;
        my ( $orphan, @descendents, $n, $i, $irv );

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

            } elsif ( defined $objects[$$orphan][CEH_PID] ) {

                # We don't allow kidnapping...
                $@  = "attempted kidnapping of a parented child: $orphan";
                $rv = 0;

            } else {

                # Objects are currently orphans...
                #
                # Now, make sure no (grand)?children of the orphan will create
                # a circular reference
                @descendents = @{ $objects[$$orphan][CEH_CREF] };
                $irv         = 1;

                while (@descendents) {

                    # Stop if our proposed parent is in this list
                    if ( grep { $$_ == $$parent } @descendents ) {
                        $@ = "circular reference detected between $parent "
                            . "& $orphan";
                        $irv = $rv = 0;
                        last;
                    }

                    # Repopulate @descendents with more distant descendents
                    $n = scalar @descendents;
                    for ( $i = 0; $i < $n; $i++ ) {
                        CORE::push @descendents,
                            @{ $objects[ ${ $descendents[$i] } ][CEH_CREF] };
                    }
                    splice @descendents, 0, $n;
                }

                if ($irv) {

                    # No circular references, so now let's update the records
                    $objects[$$orphan][CEH_PID] = $$parent;
                    CORE::push @{ $objects[$$parent][CEH_CREF] }, $orphan;
                }
            }
        }

        return $rv;
    }

    sub _disassocObj ($@) {

        # Purpose:  Removes the child/parent relationship
        # Returns:  True
        # Usage:    $rv = _disassocObj($parent, $child1, $child2):

        my $parent   = CORE::shift;
        my @children = CORE::shift;
        my $child;

        foreach $child (@children) {

            # Make sure the child actually belongs to the parent
            if ( $objects[$$child][CEH_PID] == $$parent ) {

                # Remove the child objref from the parent's list
                @{ $objects[$$parent][CEH_CREF] } =
                    grep { $_ != $child } @{ $objects[$$parent][CEH_CREF] };

                # Update the child's record
                $objects[$$child][CEH_PID] = undef;
            }
        }

        return 1;
    }

    sub _getParentRef ($) {

        # Purpose:  Returns a reference to the parent object of the passed ID
        # Returns:  undef or object ref
        # Usage:    $oref = _getParentRef( $id );

        my $id = CORE::shift;
        my ( $pid, $gpid, $child, $pref );

        # See if we have a parent to go to
        $pid = $objects[$id][CEH_PID];
        if ( defined $pid ) {

            # We have a parent, but do we have a grandparent?
            $gpid = $objects[$pid][CEH_PID];
            if ( defined $gpid ) {

                # Loop through grandparent's children until we find
                # an object that matches our pid
                foreach $child ( @{ $objects[$gpid][CEH_CREF] } ) {
                    if ( $$child == $pid ) {
                        $pref = $child;
                        last;
                    }
                }
            }
        }

        return $pref;
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
        # Returns:  True if successful, False otherwise
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
                    unless $attr ^ CEH_ATTR_TYPE > 0;
                $attr |= CEH_PUB
                    unless $attr ^ CEH_ATTR_SCOPE > 0;

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
        # Returns:  True if all properties were correctly declared
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
        # Returns:  True if successful, false otherwise
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
        # Returns:  True if successful, False otherwise
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
        # Returns:  True if all methods were correctly declared
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

    # UNDOCUMENTED METHODS

    sub _parentID ($) {

        # Purpose:  Returns the parent ID (undef if orphaned)
        # Returns:  undef or int
        # Usage:    $pid = $obj->_parentID;

        my $self = CORE::shift;

        return $objects[$$self][CEH_PID];
    }

    sub _parentRef ($) {

        # Purpose:  Returns a reference to the parent object
        # Returns:  undef or object ref
        # Usage:    $pref = $obj->_parentRef;

        my $self = CORE::shift;

        return _getParentRef($$self);
    }

    # PUBLISHED METHODS

    sub new ($;@) {

        # Purpose:  Object constructor
        # Returns:  Object reference is successful, undef otherwise
        # Usage:    $obj = Class->new(@args);

        my $class = CORE::shift;
        my @args  = @_;
        my $self  = bless \do { my $anon_scalar }, $class;
        my ( $rv, @classes, $tclass, $nclass, $l, $n, $isaref );
        my %super;

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

        return $self;
    }

    sub children ($) {

        # Purpose:  Returns a list of object references to this object's
        #           children
        # Returns:  Array
        # Usage:    @crefs = $obj->children;

        my $self = CORE::shift;

        return @{ $objects[$$self][CEH_CREF] };
    }

    sub siblings ($) {

        # Purpose:  Returns a list of object references to this object's
        #           siblings
        # Returns:  Array
        # Usage:    @crefs = $obj->siblings;

        my $self = CORE::shift;
        my $pid  = $objects[$$self][CEH_PID];
        my @rv;

        @rv = grep { $_ != $self } @{ $objects[$pid][CEH_CREF] }
            if defined $pid;

        return @rv;
    }

    sub adopt ($@) {

        # Purpose:  Adopts the passed object references as children
        # Returns:  True if successful, False otherwise
        # Usage:    $rv = $obj->adopt($cobj1, $cobj2);

        my $self     = CORE::shift;
        my @children = @_;
        my $rv       = 0;

        $rv = _assocObj( $self, @children ) if @children;

        return $rv;
    }

    sub disown ($@) {

        # Purpose:  Disowns the passed object references as children
        # Returns:  True if successful, False otherwise
        # Usage:    $rv = $obj->disown($cobj1, $cobj2);

        my $self     = CORE::shift;
        my @children = @_;

        return _disassocObj( $self, @children );
    }

    sub property ($$;$) {

        # Purpose:  Gets/sets the requested property
        # Returns:  True on value sets, value on gets
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
        # Returns:  True
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
        # Returns:  True
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
        # Returns:  True
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
        # Returns:  True
        # Usage:    $obj->DESTROY;

        my $self = CORE::shift;
        my ( @descendents, @cdesc, @gcdesc, $child, $parent );

        if ( defined $objects[$$self] ) {

            # First, get a list of all descendents
            @cdesc = $self->children;
            while (@cdesc) {
                CORE::push @descendents, @cdesc;
                @gcdesc = ();
                foreach $child (@cdesc) {
                    CORE::push @gcdesc, $child->children;
                }
                @cdesc = @gcdesc;
            }

            # Second, working backwards we'll disown each child and release it
            foreach $child ( reverse @descendents ) {
                $parent = $child->_parentRef;
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

$Id: EHierarchy.pm,v 0.91 2012/01/31 00:36:46 acorliss Exp $

=head1 SYNOPSIS

    package TelDirectory;

    use Class::EHierarchy qw(:all);
    use vars qw(@ISA);

    @ISA = qw(Class::EHierarchy);

    sub _initalize {
        my $obj     = shift;
        my %args    = @_;
        my $rv      = 1;

        
        _declProp( $obj, CEH_PRIV | CEH_SCALAR, 'counter' );
        _declProp( $obj, CEH_PUB | CEH_SCALAR,  'first' );
        _declProp( $obj, CEH_PUB | CEH_SCALAR,  'last' );
        _declProp( $obj, CEH_PUB | CEH_ARRAY,   'telephone' );

        _declMethod( CEH_PRIV,    '_incrCounter' );
        _declMethod( CEH_PUB,     'addTel' ;

        return $rv;
    }

    sub _incrCounter {
        my $obj = shift;

        return $self->property('counter', 
               $self->property('counter') + 1 );
    }

    sub addTel {
        my $obj     = shift;
        my $telno   = shift;

        $obj->_incrCounter;

        return $obj->push('telephone', $telno);
    }

Or, alternatively (the preferred method):

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

        # No longer need just to declare properties/methods

        return $rv;
    }

    ...

=head1 DESCRIPTION

B<Class::EHierarchy> is intended for use as a base class where hierarchally
ordered objects are desired.  This class allows you to define a parent ->
child relationship between objects and ensures an orderly destruction of
objects according to that relationship, instead of perl's reverse order 
destruction sequence based on reference counting.

This class also creates opaque objects to prevent any access to internal data
except by the published interface.

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
database commit is made.

This, in a nutshell, is the primary purpose of this class.

A few things should be mentioned:  because of how the relationships are
tracked in the class child objects do have a reference to them stored in the
class data structures.  This means you can't destroy a reference to them
inside of the parent and have them reaped.  You must I<disown> them first.

=head2 OPAQUE OBJECTS

Objects based on this class will be opaque objects instead of the traditional
blessed hash references in which the hash elements could be access directly
through dereferencing.  This prevents access to internal data structures 
outside of the published interface.  This does mean, though, that you can't
access your data directly, either.  You must use a provided method to
retrieve that data from the class storage.

A side benefit, however, is that this provides some OOP scoping for 
properties.  You can declare your properties as one of three scopes: 

    private         accessible only to members of this object's class
    restricted      accessible to members of this object's class  
                    and subclasses
    public          globally accessible

Likewise, the same can be declared for methods.

Scoping of various members are done during object instantiation.  Examples are
provided below.

B<NOTE:>  private properties are not merely restricted from subclasses, they
are also hidden, so there's no worries about naming conflicts with subclasses.

=head1 SUBROUTINES/METHODS

Subroutines and constants are provided strictly for use by derived classes 
within their defined methods.  To avoid any confusion all of our exportable 
symbols are *not* exported by default.  You have to specifically import the 
B<all> tag set.  Because these subroutines should not be used outside of the 
class they are all preceded by an underscore, like any other private function.

Methods, on the other hand, are meant for direct and global use.  With the
exception of B<new> and B<DESTROY> they should all be safe to override.

=head2 SUBROUTINES/CONSTANTS

=head3 _declProp

    $rv = _declProp($obj, SCOPE | TYPE | FLAG, @propNames);

This function is meant to be called within a subclass' I<_initialize>
method which is called during object instantiation.  It is used to create
named properties while declaring they access scope and type.  The following
constants are used to create the second argument:

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

Constants describing property attributes are OR'ed together, and only one
scope and one type from each list should be used at a time.  Using multiple
types or scopes to describe any particular property will make it essentially
inaccessible.

Type, if omitted, defaults to I<CEH_SCALAR>,  Scope defaults to I<CEH_PUB>.

B<NOTE:>  I<CEH_NO_UNDEF> only applies to psuedo-scalar types like proper
scalars, references, etc.  This has no effect on array members or hash values.

B<NOTE:>  While it is usually not necessary to use this function if using 
the class variable method (B<@_properties>) this function is still useful for
creating dynamically generated properties at runtime.

=head3 _declMethod

    $rv = _declMethod($attr, @methods);

This function is meant to be called within a subclass' I<_initialize> method
which is called during object instantiation.  It is used to create wrappers
for those functions whose access you want to restrict.  It works along the
same lines as properties and uses the same scoping constants for the
attribute.

Only methods defined within the subclass can have scoping declared.  You
cannot call this method for inherited methods.

B<NOTE:> While it is usually not necessary to use this function if using the
class variable method (B<@_methods>) this function is still useful for
dynamically scoping methods at runtime.  That said, note that since scoping is
applied to the class symbol table (B<not> on a per object basis) any given
method can only be scoped once.  That means you can't do crazy things like
make public methods private, or vice-versa.

=head2 METHODS

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

    $rv = $newObj->_initialize(@newArgs);

This method is not provided by this class, but is required to be provided by
subclasses.  It is in this method that you can declare properties and methods
with the applicable attributes, perform validation, etc.  It must return a
boolean value which determines if the object construction can succeed.

=head3 children

    @crefs = $obj->children;

This method returns an array of object references to every object that was
adopted by the current object.

=head3 siblings

    @crefs = $obj->siblings;

This method returns an array of object references to every object that shares
the same parent as the current object.

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

B<NOTE:> Given that the presence of additional arguments after the property
name sets this method into 'write' mode, there is obviously no way to use this
to empty a hash or array property.  For that please see the L<purge> method.

=head3 propertyNames

    @properties = $obj->propertyNames;

This method returns a list of all registered properties for the current
object.  Property names will be filtered appropriately by the caller's 
context.

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
keys, whils array elements are retrieved in the order of the specified ordinal
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

=head3 DESTROY

A B<DESTROY> method is provided by this class and must not be overridden by
any subclass.  It is this method that provides the ordered termination
property of hierarchal objects.  Any code you wish to be executed during this
phase can be put into a B<_deconstruct> method in your subclass.  If it's
available it will be executed after any children have been released.

=head3 _deconstruct

    $obj->_deconstruct

This method is optional, but if needed must be provided by the subclass.  It
will be called during the B<DESTROY> phase of the object.

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

