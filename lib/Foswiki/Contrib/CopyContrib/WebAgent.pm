# Copyright (C) 2013-2019 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Contrib::CopyContrib::WebAgent;

use strict;
use warnings;
use Foswiki::Func();
use Foswiki::Contrib::CopyContrib::CopyAgent ();
use Foswiki::Contrib::CopyContrib::TopicAgent ();
use Error qw( :try );

our @ISA = qw( Foswiki::Contrib::CopyContrib::CopyAgent );

###############################################################################
sub parseRequestObject {
  my ($this, $request) = @_;

  $this->SUPER::parseRequestObject($request);

  unless (defined $this->{srcWeb}) {
    $this->{srcWeb} = $request->param('source') || $this->{baseWeb};
    $request->delete('source');
  }

  unless (defined $this->{dstWeb}) {
    $this->{dstWeb} = $request->param('destination');
    $request->delete('destination');
  }

  $this->{search} = $request->param('search') unless defined $this->{search};
  $this->{include} = $request->param('include') unless defined $this->{include};
  $this->{exclude} = $request->param('exclude') unless defined $this->{exclude};
  $this->{templateWeb} = $request->param('template') unless defined $this->{templateWeb};

  return $this;
}

###############################################################################
sub copy {
  my $this = shift;

  $this->writeDebug("called copy() ".($this->{dry}?'...dry run':''));

  throw Error::Simple("No source") unless defined $this->{srcWeb};

  throw Error::Simple("Source web '$this->{srcWeb}' not found")
    unless Foswiki::Func::webExists($this->{srcWeb});

  throw Error::Simple("No destination") unless defined $this->{dstWeb};

  unless (Foswiki::Func::webExists($this->{dstWeb}))  {
    my $template = $this->{templateWeb} || '_empty';
#    $this->writeDebug("creating destination web '$this->{dstWeb}' using template '$template'");
    Foswiki::Func::createWeb($this->{dstWeb}, $this->{templateWeb})
      unless $this->{dry};
  }

  my $searchString = $this->{search};
  $searchString = '1' unless defined $searchString;

#  $this->writeDebug("search=$searchString");  

  my $matches = Foswiki::Func::query(
    $searchString,
    undef,
    {
      type => 'query',
      files_without_match => 1,
      web => $this->{srcWeb},
    }
  );
  
  my $request = Foswiki::Func::getRequestObject();
  my $count = 0;

#  $this->writeDebug("include=$this->{include}") if defined $this->{include};
#  $this->writeDebug("exclude=$this->{exclude}") if defined $this->{exclude};

  if (Foswiki::Func::getContext()->{DBCachePluginEnabled}) {
#   $this->writeDebug("disabling DBCachePlugin's saveHandler temporarily during bulk operation");
#   require Foswiki::Plugins::DBCachePlugin;
#   Foswiki::Plugins::DBCachePlugin::disableSaveHandler();
  }

  try {
    while ($matches->hasNext) {
      my $webTopic = $matches->next;
      my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($this->{srcWeb}, $webTopic);

      next if defined $this->{include} && $topic !~ /$this->{include}/;
      next if defined $this->{exclude} && $topic =~ /$this->{exclude}/;

      my $agent = new Foswiki::Contrib::CopyContrib::TopicAgent($this->{session},
         srcWeb => $web,
         srcTopic => $topic,
         dstWeb => $this->{dstWeb},
         dstTopic => $topic,
         doClear => $this->{doClear},
         dry => $this->{dry},
         debug => $this->{debug},
      );
      $count++;
#      $this->writeDebug("... copying $web.$topic to $this->{dstWeb}.$topic");
      $agent->parseRequestObject($request)->copy();
    }
  } finally {
#   if (Foswiki::Func::getContext()->{DBCachePluginEnabled}) {
#     $this->writeDebug("enabling DBCachePlugin's saveHandler again");
#     Foswiki::Plugins::DBCachePlugin::enableSaveHandler();
#   }
  };

#  $this->writeDebug("copied $count topic(s)") if $count;

  return ("web_success", $count, $this->{dstWeb});
}

1;

