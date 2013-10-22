# Copyright (C) 2013 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Contrib::CopyContrib::CopyAgent;

use strict;
use warnings;

use Foswiki::Func ();

###############################################################################
sub new {
  my ($class, $session) = @_;

  my $className = $class;
  $className =~ s/^.*:://;

  my $this = bless({
    className => $className,
    session => $session,
    baseWeb => $session->{webName},
    baseTopic => $session->{topicName},
    @_
  }, $class);

  return $this;
}

###############################################################################
sub writeDebug {
  my $this = shift;
  print STDERR $this->{className}." - $_[0]\n" if $this->{debug};
}

###############################################################################
sub parseRequestObject {
  my ($this, $request) = @_;

  $this->{debug} = Foswiki::Func::isTrue($request->param('debug'), $this->{debug})
    unless defined $this->{debug};

  #$this->writeDebug("called parseRequestObject()");

  $this->{dry} = Foswiki::Func::isTrue($request->param('dry'), $this->{dry})
    unless defined $this->{dry};

  $this->{onlyNew} = Foswiki::Func::isTrue($request->param('onlynew'), 1)
    unless defined $this->{onlyNew};

  $this->{doClear} = Foswiki::Func::isTrue($request->param('clear'), 0)
    unless defined $this->{doClear};

  # TODO
  # redirectto

  return $this;
}

###############################################################################
sub copy {
  my $this = shift;

  die "not implemented";
}

1;
