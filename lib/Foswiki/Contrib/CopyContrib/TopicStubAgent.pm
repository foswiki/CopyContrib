# Copyright (C) 2013-2017 Michael Daum http://michaeldaumconsulting.com
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

###############################################################################
# TopicStubAgent performs a specialised copy of TopicAgent.
# TopicStubAgent will copy the source topic as a stub
# TopicStubAgent:
#   * does NOT copy attachments
#   * does NOT copy text
#   * does copy specific named fields, if they exist in the source
#      * Parent
#      * TopicTitle
#      * Summary
#      * WikiApplication
#   * does insert the following meta data (Not available through TopicAgent)
#      * META:FIELD{name="TopicType" title="TopicType" 
#                   value="TopicStub, <types listed in the source topic>"}%
#      * META:FORM{name="Applications.TopicType"}
#      * META:FIELD{name="Target" title="Target" value="<fully qualified source topic>"}
#      * META:FIELD{name="Section" title="Section" value=""}%
#
# Parameters are:
#   * source
#   * destination

###############################################################################
package Foswiki::Contrib::CopyContrib::TopicStubAgent;

use strict;
use warnings;

use Foswiki::Contrib::CopyContrib::TopicAgent ();

our @ISA = qw( Foswiki::Contrib::CopyContrib::TopicAgent );

sub copy {
  my $this = shift;

#  $this->writeDebug("called copy() ".($this->{dry}?'...dry run':''));

  throw Error::Simple("Topic $this->{srcWeb}.$this->{srcTopic} does not exist")
    unless Foswiki::Func::topicExists($this->{srcWeb}, $this->{srcTopic});

  throw Foswiki::OopsException("copy",
    def => "overwrite_error",
    params => [
      "Error during copy operation",
      "$this->{dstWeb}.$this->{dstTopic}"
    ]) if $this->{onlyNew} && Foswiki::Func::topicExists($this->{dstWeb}, $this->{dstTopic});

# check access
  $this->checkAccess;

# Read the source object
  ($this->{srcMeta}) = Foswiki::Func::readTopic($this->{srcWeb}, $this->{srcTopic});

# If the source is a TopicStub, then we can save the topic directly under the destination name.
  if ( $this->isTopicStub() ) {
    if ($this->{srcMeta} && !$this->{dry}) {
#      $this->writeDebug("saving to $this->{dstWeb}.$this->{dstTopic} as copied stub");
      $this->{srcMeta}->saveAs(
                web => $this->{dstWeb},
                topic => $this->{dstTopic},
                forcenewrevision => $this->{forceNewRevision},
                dontlog => $this->{dontLog},
                minor => $this->{minor},
      );
    } 

    return ( "topic_success", "$this->{srcWeb}.$this->{srcTopic}", 
             "$this->{dstWeb}.$this->{dstTopic}");
  }

# Create the destination topic
  $this->{dstMeta} = new Foswiki::Meta($this->{session}, $this->{dstWeb}, $this->{dstTopic});
  $this->addMetadata();

# save the destination topic
  if ($this->{dstMeta} && !$this->{dry}) {
#    $this->writeDebug("saving to $this->{dstWeb}.$this->{dstTopic}");
    $this->{dstMeta}->save(
      forcenewrevision => $this->{forceNewRevision},
      dontlog => $this->{dontLog},
      minor => $this->{minor},
    );
  }

  return ("topic_success", "$this->{srcWeb}.$this->{srcTopic}", "$this->{dstWeb}.$this->{dstTopic}");
}

################################################################
sub isTopicStub {
  my $this = shift;

  my @fields = $this->{srcMeta}->find( 'FIELD' );
  
  foreach my $field ( @fields ) {
    return 1 if $field->{name} eq 'TopicType' && $field->{value} =~ m/\bTopicStub\b/;  
  }
  return 0;
}

################################################################
sub defineFields {
  my $this = shift;

  my @newfields = ();
  my @copylist = ( "TopicType", "TopicTitle", "Summary", "WikiApplication" );

  my @fields = $this->{srcMeta}->find( 'FIELD' );

  foreach my $field ( @fields ) {
    foreach my $item ( @copylist ) {
      next unless $field->{name} eq $item;  
      $field->{value} ='TopicStub, ' . $field->{value} if $field->{name} eq 'TopicType';
      push @newfields, $field;
    }
  }
  
  push @newfields, { name => 'Target', 
                     title => 'Target', 
                     value => sprintf( "%s.%s", $this->{srcWeb}, $this->{srcTopic} ) };
  push @newfields, { name => 'Section', title => 'Section', value => '' };

  return @newfields;
}

################################################################
sub addMetadata {
  my $this = shift;

  $this->{dstMeta}->put( 'TOPICPARENT', $this->{srcMeta}->find( 'TOPICPARENT' ) );

  $this->{dstMeta}->put( 'FORM', { name => 'Applications.TopicStub' } );

  $this->{dstMeta} ->putAll( 'FIELD', $this->defineFields() );
}

1;

