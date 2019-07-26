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

package Foswiki::Contrib::CopyContrib::TopicListAgent;

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

  unless (defined $this->{srcTopics}) {
    $this->{srcTopics} = ();

    my @source = $request->param('source');
    @source = ($this->{baseWeb}.'.'.$this->{baseTopic}) unless @source;

    $request->delete('source');

    $this->writeDebug("source topics:");
    foreach (@source) {
      foreach my $item (split(/\s*,\s*/)) {
        my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($this->{baseWeb}, $item);
        push @{$this->{srcTopics}}, {
          web => $web, 
          topic => $topic
        };
        $this->writeDebug("... $web.$topic");
      }
    }
  }

  unless (defined $this->{dst}) {
    $this->{dst} = $request->param('destination');
    $request->delete('destination');
    $this->writeDebug("dst=$this->{dst}") if defined $this->{dst};
  }

  return $this;
}

###############################################################################
sub finish {
  my $this = shift;

  $this->SUPER::finish();

  undef $this->{srcTopics};
}

###############################################################################
sub copy {
  my $this = shift;

  #$this->writeDebug("called copy() ".($this->{dry}?'...dry run':''));

  throw Error::Simple("No destination") unless defined $this->{dst};

  my $count = 0;
  my $request = Foswiki::Func::getRequestObject();

  if (Foswiki::Func::webExists($this->{dst})) {

    # copy all topics to a destination web
    $this->{dstWeb} = $this->{dst};

    foreach my $item (@{$this->{srcTopics}}) {
      my $agent = new Foswiki::Contrib::CopyContrib::TopicAgent($this->{session},
         srcWeb => $item->{web},
         srcTopic => $item->{topic},
         dstWeb => $this->{dstWeb},
         dstTopic => $item->{topic},
         doClear => $this->{doClear},
         dry => $this->{dry},
      );
      $count++;
      $this->writeDebug("... copying $item->{web}.$item->{topic} to $this->{dstWeb}");
      $agent->parseRequestObject($request)->copy();
    }

    return ("topiclist_success", $count, $this->{dstWeb});
  } 

  # merge all topics to one destination topic
  ($this->{dstWeb}, $this->{dstTopic}) = Foswiki::Func::normalizeWebTopicName($this->{baseWeb}, $this->{dst})
    unless defined $this->{dstWeb} && defined $this->{dstTopic};

  throw Error::Simple("No such web '$this->{dstWeb}'") 
    unless Foswiki::Func::webExists($this->{dstWeb});

  foreach my $item (@{$this->{srcTopics}}) {
    my $agent = new Foswiki::Contrib::CopyContrib::TopicAgent($this->{session},
       srcWeb => $item->{web},
       srcTopic => $item->{topic},
       dstWeb => $this->{dstWeb},
       dstTopic => $this->{dstTopic},
       doClear => $this->{doClear},
       dry => $this->{dry},
    );
    $count++;
    $this->writeDebug("... copying $item->{web}.$item->{topic} to $this->{dstWeb}.$this->{dstTopic}");
    $agent->parseRequestObject($request)->copy();
  }

  return ("topiclist_merge_success", $count, "$this->{dstWeb}.$this->{dstTopic}");
}
