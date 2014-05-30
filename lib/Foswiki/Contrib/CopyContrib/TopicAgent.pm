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

package Foswiki::Contrib::CopyContrib::TopicAgent;

use strict;
use warnings;

use Foswiki::Meta ();
use Foswiki::Func();
use Foswiki::Contrib::CopyContrib::CopyAgent ();
use Error qw( :try );

our @ISA = qw( Foswiki::Contrib::CopyContrib::CopyAgent );


#use Data::Dumper ();
#$Data::Dumper::MaxDepth = 2;

###############################################################################
sub parseRequestObject {
  my ($this, $request) = @_;

  $this->SUPER::parseRequestObject($request);

  $this->{src} = $request->param('source') || $this->{baseWeb}.'.'.$this->{baseTopic};
  ($this->{srcWeb}, $this->{srcTopic}) = Foswiki::Func::normalizeWebTopicName($this->{baseWeb}, $this->{src})
    unless defined $this->{srcWeb} && defined $this->{srcTopic};

  $this->{dst} = $request->param('destination') || $this->{src};
  ($this->{dstWeb}, $this->{dstTopic}) = Foswiki::Func::normalizeWebTopicName($this->{baseWeb}, $this->{dst})
    unless defined $this->{dstWeb} && defined $this->{dstTopic};

  #$this->writeDebug("srcWeb=$this->{srcWeb}, srcTopic=$this->{srcTopic}");
  #$this->writeDebug("dstWeb=$this->{dstWeb}, dstTopic=$this->{dstTopic}");

  my @includeParts = ();
  my $includeParts = $request->param('includeparts');
  if (defined $includeParts) {
    push @includeParts, split(/\s*,\s*/, $includeParts);
  }
  if (scalar($request->param('includepart'))) {
    push @includeParts, $request->param('includepart');
  }
  push @includeParts, "all" unless @includeParts;# default

  my @excludeParts = ();
  my $excludeParts = $request->param('excludeparts');
  if (defined $excludeParts) {
    push @excludeParts, split(/\s*,\s*/, $excludeParts);
  }
  if (scalar($request->param('excludepart'))) {
    push @excludeParts, $request->param('excludepart');
  }

  $this->{includeparts} = {map {$_ => 1} @includeParts};
  $this->{excludeparts} = {map {$_ => 1} @excludeParts};

  #print STDERR Data::Dumper->Dump([$this->{includeparts}])"\n";
  #print STDERR Data::Dumper->Dump([$this->{excludeparts}])"\n";

  #$this->writeDebug("includeparts=".join(", ", sort keys %{$this->{includeparts}}))
  #  if defined $this->{includeparts};
  #$this->writeDebug("excludeparts=".join(", ", sort keys %{$this->{excludeparts}}))
  #  if defined $this->{excludeparts};

  # get include<part-id> and exclude<part-id>
  foreach my $partId ($this->getKnownMetaAliases) {
    #$this->writeDebug("testing for part id $partId");

    foreach my $type (qw(include exclude)) {
      my $val = $request->param($type.$partId);
      if (defined $val) {
        #$this->writeDebug("$type$partId=$val");
        $this->{$type.$partId} = $val;
      }
    }
  }

#  if ($this->{debug}) {
#    print STDERR Data::Dumper->Dump([$this])"\n";
#  }

  return $this;
}

###############################################################################
sub getKnownMetaAliases {
  my $this = shift;

  unless (defined $this->{metaOfAlias}) {

    foreach my $metaDataName (keys %Foswiki::Meta::VALIDATE) {
      next if $metaDataName =~ /^(TOPICINFO|CREATEINFO|TOPICMOVED|DISQUS|VERSIONS)$/; # SMELL: have a cfg value for defaults

      my $validation = $Foswiki::Meta::VALIDATE{$metaDataName};
      my $key = ($validation->{alias} || lc($metaDataName));
      $this->{metaOfAlias}{$key} = $metaDataName;
    }
  }

  return keys %{$this->{metaOfAlias}};
}

###############################################################################
sub getMetaKeyOfAlias {
  my ($this, $alias) = @_;

  $this->getKnownMetaAliases;
  return $this->{metaOfAlias}{$alias};
}

###############################################################################
sub checkAccess {
  my $this = shift;

  my $user = Foswiki::Func::getWikiName();

  throw Error::Simple("Access denied on source $this->{srcWeb}.$this->{srcTopic}")
    unless Foswiki::Func::checkAccessPermission('view', $user, undef, $this->{srcTopic}, $this->{srcWeb});

  throw Error::Simple("Access denied on destination $this->{dstWeb}.$this->{dstTopic}")
    unless Foswiki::Func::checkAccessPermission('change', $user, undef, $this->{dstTopic}, $this->{dstWeb});
}

###############################################################################
sub read {
  my ($this, $doReload) = @_;

  #$this->writeDebug("called read");

  # read/create destination object
  if (!defined($this->{dstMeta}) || $doReload) {
    #$this->writeDebug("... reloading dst $this->{dstWeb}.$this->{dstTopic}");
    if (Foswiki::Func::topicExists($this->{dstWeb}, $this->{dstTopic})) {
      ($this->{dstMeta}) = Foswiki::Func::readTopic($this->{dstWeb}, $this->{dstTopic});
    } else {
      $this->{dstMeta} = new Foswiki::Meta($this->{session}, $this->{dstWeb}, $this->{dstTopic});
    }
  }

  # read the source
  if (!(defined $this->{srcMeta}) || $doReload) {
    #$this->writeDebug("... reloading src $this->{srcWeb}.$this->{srcTopic}");
    ($this->{srcMeta}) = Foswiki::Func::readTopic($this->{srcWeb}, $this->{srcTopic});
  }

  return ($this->{srcMeta}, $this->{dstMeta});
}

###############################################################################
sub copyPart {
  my ($this, $partId) = @_;

  return unless (
      ($this->{includeparts}{$partId} || $this->{includeparts}{all}) && 
      !$this->{excludeparts}{$partId}
  );

  #$this->writeDebug("called copyPart($partId)");
  $this->read;

  # special handling of attachments 
  if ($partId eq "attachments") {
    $this->trashAttachments;
    $this->copyAttachments;

    return;
  }

  # special handling of text
  if ($partId eq 'text') {
# TODO: let's have an appendtext param for this case
#    if ($this->{doAppendText}) {
#      $this->{dstMeta}->text($this->{dstMeta}->text().$this->{srcMeta}->text());
#    } else {
      $this->{dstMeta}->text($this->{srcMeta}->text());
#    }
    return;
  }

  my $metaDataName = $this->getMetaKeyOfAlias($partId);
  throw Error::Simple("Unknown meta data id '$partId'") 
    unless defined $metaDataName;

  #$this->writeDebug("metaDataName=$metaDataName");

  my $exclude = $this->{'exclude'.$partId};
  my $include = $this->{'include'.$partId};

  my $count = 0;
  $this->{dstMeta}->remove($metaDataName) if $this->{doClear};

  foreach my $item ($this->{srcMeta}->find($metaDataName)) {
    if (defined $item->{name}) {
      if ((defined $exclude && $item->{name} =~ /$exclude/) ||
          (defined $include && $item->{name} !~ /$include/)) {
        $this->writeDebug("... skipping $item->{name}");
        next;
      }
      #print STDERR Data::Dumper->Dump([$item])"\n";
      $this->writeDebug("... copying $item->{name}");
      $this->{dstMeta}->putKeyed($metaDataName, $item);
    } else {
      $this->writeDebug("... copying unnamed item");
      $this->{dstMeta}->put($metaDataName, $item);
    }

    $count++;
  }

  #$this->writeDebug("copied $count $partId item(s)") if $count;
}

###############################################################################
sub trashAttachments {
  my $this = shift;

  return if $this->{dry} || !$this->{doClear};

  $this->read;

  my @attachments = ();
  push @attachments, $_->{name} foreach $this->{dstMeta}->find('FILEATTACHMENT');

  foreach my $attachment (@attachments) {
    $this->writeDebug("trashing attachment $attachment at $this->{dstWeb}.$this->{dstTopic}");
    Foswiki::Func::moveAttachment($this->{dstWeb}, $this->{dstTopic}, $attachment, $Foswiki::cfg{TrashWebName}, 'TrashAttament');
  }
}

###############################################################################
sub copyAttachments {
  my $this = shift;

  #$this->writeDebug("called copyAttachments");

  $this->read;

  # SMELL: can't use Foswiki::Func::getAttachmentList as it returns non-attached files as well
  # that only happen to be in the same pub directory, i.e. thumbnails 

  my @attachments = ();
  push @attachments, $_->{name} foreach $this->{srcMeta}->find('FILEATTACHMENT');

  my $exclude = $this->{excludeattachments};
  foreach my $attachment (@attachments) {
    if (defined $exclude && $attachment =~ /$exclude/) {
      $this->writeDebug("... skipping $attachment");
      next;
    }
    $this->writeDebug("... copying attachment $attachment");
    Foswiki::Func::copyAttachment($this->{srcWeb}, $this->{srcTopic}, $attachment, $this->{dstWeb}, $this->{dstTopic})
      unless $this->{dry};

  }
}

###############################################################################
sub copy {
  my $this = shift;

  #$this->writeDebug("called copy() ".($this->{dry}?'...dry run':''));
  #$this->writeDebug("doClear=".$this->{doClear});

  throw Error::Simple("Topic $this->{srcWeb}.$this->{srcTopic} does not exist")
    unless Foswiki::Func::topicExists($this->{srcWeb}, $this->{srcTopic});

  throw Error::Simple("Cannot overwrite existing destination topic $this->{dstWeb}.$this->{dstTopic}")
    if $this->{onlyNew} && Foswiki::Func::topicExists($this->{dstWeb}, $this->{dstTopic});

  # check access
  $this->checkAccess;

  # check copy to self error
  # throw Error::Simple("Cannot copy topic $srcWeb.$srcTopic on itself")
  #   if "$srcWeb.$srcTopic" eq "$dstWeb.$dstTopic";

  # do attachments first
  $this->copyPart("attachments");

  # reload
  $this->read(1);
  
  # copy the rest
  foreach my $partId (grep {!/attachments/} sort $this->getKnownMetaAliases) {
    $this->copyPart($partId);
  }

  $this->copyPart("text");

  # save
  if ($this->{dstMeta} && !$this->{dry}) {
    $this->writeDebug("saving to $this->{dstWeb}.$this->{dstTopic}");
    $this->{dstMeta}->save(
      forcenewrevision => $this->{forceNewRevision},
      dontlog => $this->{dontLog},
      minor => $this->{minor},
    );
  }

  return "Copied topic [[$this->{srcWeb}.$this->{srcTopic}]] to [[$this->{dstWeb}.$this->{dstTopic}]]";
}

1;
