# Copyright (C) 2013-2024 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Contrib::CopyContrib::ApplicationAgent;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Contrib::CopyContrib::CopyAgent  ();
use Foswiki::Contrib::CopyContrib::TopicAgent ();
use Foswiki::Contrib::CopyContrib::TopicStubAgent ();
use Error qw( :try );

#use Data::Dumper;

our @ISA = qw( Foswiki::Contrib::CopyContrib::CopyAgent );

###############################################################################
sub parseRequestObject {
    my ( $this, $request ) = @_;

    $this->SUPER::parseRequestObject($request);

    #used parameters: mode, source, destination, template

    unless ( defined $this->{srcTopics} ) {
        $this->{srcTopics} = ();

        # Get source parameter. Use current topic if source is not defined.

        my @source = $request->multi_param('source');
        @source = ( $this->{baseWeb} . '.' . $this->{baseTopic} )
          unless @source;
        $request->delete('source');

#        $this->writeDebug("source topics:");
        foreach (@source) {
            foreach my $item ( split(/\s*,\s*/) ) {

      # $item is of the form: source_topic_name => target_topic_name [copy_type]
#                $this->writeDebug("... item: $item");
                my ( $from, $to, $type ) = ( $item =~
                      m!\A\s*([\/\.\w]+)\s*(?:=>\s*(\w+))?\s*(\[\w+\])?\s*\Z! );
                unless ($from) {
                    next;
                }

                my ( $web, $topic ) =
                  Foswiki::Func::normalizeWebTopicName( $this->{baseWeb},
                    $from );
                $to   = $topic    unless $to;
                $type = '[topic]' unless $type;
                push @{ $this->{srcTopics} },
                  {
                    web    => $web,
                    topic  => $topic,
                    target => $to,
                    type   => $type
                  };
#                $this->writeDebug("... web.topic=>target: $web.$topic => $to");
            }
        }
    }

    # Get the destination parameter and put it in dstWeb
    unless ( defined $this->{dstWeb} ) {
        $this->{dstWeb} = $request->param('destination');
        $request->delete('destination');
#        $this->writeDebug("dstWeb=$this->{dstWeb}") if defined $this->{dstWeb};
    }

    # Get the template web. SMELL: Why don't we delete the parameter?
    $this->{templateWeb} = $request->param('template') || '_default' 
      unless defined $this->{templateWeb};

    return $this;
}

###############################################################################
sub copy {
    my $this = shift;

#    $this->writeDebug("called copy() " . ( $this->{dry} ? '...dry run' : '' ) );

## check destination web. If it does not exists. create it as is done in the WebAgent (Can't use web agent. It expects source topics.)

    throw Error::Simple("No destination") unless defined $this->{dstWeb};

    my $count   = 0;
    my $request = Foswiki::Func::getRequestObject();

    unless ( Foswiki::Func::webExists( $this->{dstWeb} ) ) {
        my $template = $this->{templateWeb} || '_default';
#        $this->writeDebug("creating destination web '$this->{dstWeb}' using template '$this->{templateWeb}'");
        Foswiki::Func::createWeb( $this->{dstWeb}, $this->{templateWeb} )
          unless $this->{dry};
    }

    if ( Foswiki::Func::webExists( $this->{dstWeb} ) ) {

        # copy all topics to a destination web
        foreach my $item ( @{ $this->{srcTopics} } ) {
            if ( $item->{type} eq '[stub]' ) {
                my $agent = new Foswiki::Contrib::CopyContrib::TopicStubAgent(
                    $this->{session},
                    srcWeb   => $item->{web},
                    srcTopic => $item->{topic},
                    dstWeb   => $this->{dstWeb},
                    dstTopic => $item->{target},
                    dry      => $this->{dry},
                    debug    => $this->{debug},
                );
#                $this->writeDebug("... copying $item->{web}.$item->{topic} to $this->{dstWeb}.$item->{target} AS STUB");
                $count++;
                $agent->parseRequestObject($request)->copy();
            }
            else {    # else[topic]
                my $agent = new Foswiki::Contrib::CopyContrib::TopicAgent(
                    $this->{session},
                    srcWeb   => $item->{web},
                    srcTopic => $item->{topic},
                    dstWeb   => $this->{dstWeb},
                    dstTopic => $item->{target},
                    doClear  => $this->{doClear},
                    dry      => $this->{dry},
                    debug    => $this->{debug},
                );

#                $this->writeDebug("... copying $item->{web}.$item->{topic} to $this->{dstWeb}.$item->{target}");
                $count++;
                $agent->parseRequestObject($request)->copy();
            }
        }

        return ( "web_success", $count, $this->{dstWeb} );
    }
}

1;

