# Copyright (C) 2013-2015 Michael Daum http://michaeldaumconsulting.com
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
use Error qw( :try );

use Data::Dumper;

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

        $this->writeDebug("source topics:");
        foreach (@source) {
            foreach my $item ( split(/\s*,\s*/) ) {

      # $item is of the form: source_topic_name => target_topic_name [copy_type]
                $this->writeDebug("... item: $item");
                my ( $from, $to, $type ) = ( $item =~
                      m!\A\s*([\/\.\w]+)\s*(?:=>\s*(\w+))?\s*(\[\w+\])?\s*\Z! );
                unless ($from) {
                    $this->writeDebug(
                        "   >>> not a valid input source parameter. Ignored.");
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
                $this->writeDebug("... web.topic=>target: $web.$topic => $to");
            }
        }
    }

    # Get the destination parameter and put it in dstWeb
    unless ( defined $this->{dstWeb} ) {
        $this->{dstWeb} = $request->param('destination');
        $request->delete('destination');
        $this->writeDebug("dstWeb=$this->{dstWeb}") if defined $this->{dstWeb};
    }

    # Get the template web. SMELL: Why don't we delete the parameter?
    $this->{templateWeb} = $request->param('template')
      unless defined $this->{templateWeb};

    return $this;
}

###############################################################################
sub copy {
    my $this = shift;

    $this->writeDebug(
        "called copy() " . ( $this->{dry} ? '...dry run' : '' ) );

## check destination web. If it does not exists. create it as is done in the WebAgent (Can't use web agent. It expects source topics.)
## check source list and use topic agent to copy each [normal] topic
## Consider a StubAgent, which copies a given topic to a stub. Web must extist.

    throw Error::Simple("No destination") unless defined $this->{dstWeb};

    my $count   = 0;
    my $request = Foswiki::Func::getRequestObject();

    unless ( Foswiki::Func::webExists( $this->{dstWeb} ) ) {
        my $template = $this->{templateWeb} || '_default';
        $this->writeDebug(
"creating destination web '$this->{dstWeb}' using template '$template'"
        );
        Foswiki::Func::createWeb( $this->{dstWeb}, $template )
          unless $this->{dry};
    }

    #print "=== Sleeping...\n"; sleep(60);

    if ( Foswiki::Func::webExists( $this->{dstWeb} ) ) {

        # copy all topics to a destination web
        #BvO    $this->{dstWeb} = $this->{dst};

        foreach my $item ( @{ $this->{srcTopics} } ) {
            if ( $item->{type} eq '[stub]' ) {
                $count++;
                $this->writeDebug(
"... copying $item->{web}.$item->{topic} to $this->{dstWeb}.$item->{target} AS STUB"
                );
                copyStub( $this, $item );
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

                $count++;
                $this->writeDebug(
"... copying $item->{web}.$item->{topic} to $this->{dstWeb}.$item->{target}"
                );
                $agent->parseRequestObject($request)->copy();
            }
        }

        return ( "topiclist_success", $count, $this->{dstWeb} );
    }
}

sub copyStub {
    my ( $this, $item ) = @_;

    #  Foswiki::Func::saveTopic( $web, $topic, $meta, $text );
    Foswiki::Func::saveTopic( $this->{dstWeb}, $item->{target}, undef(),
        topicStubTemplate( $item->{web}, $item->{web} . '.' . $item->{topic} )
    );

}

sub topicStubTemplate {
    my ( $application, $target ) = @_;
    my $text = <<"END_HERE";
%META:FORM{name="Applications.TopicStub"}%
%META:FIELD{name="TopicType" title="TopicType" value="TopicStub, TopicType"}%
%META:FIELD{name="TopicTitle" title="<nop>TopicTitle" value=""}%
%META:FIELD{name="Summary" title="Summary" value=""}%
%META:FIELD{name="WikiApplication" title="WikiApplication" value="$application"}%
%META:FIELD{name="Target" title="Target" value="$target"}%
END_HERE

    return $text;
}

1;

