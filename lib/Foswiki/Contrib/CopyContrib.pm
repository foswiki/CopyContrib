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

package Foswiki::Contrib::CopyContrib;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Plugins();
use Error qw( :try );
use Encode();
use Foswiki::OopsException ();

our $VERSION = '5.10';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'Copies webs, topics, attachments, or part of them';
our $LICENSECODE = '%$LICENSECODE%';

our %agentImpls = (
  'topic' => 'Foswiki::Contrib::CopyContrib::TopicAgent',
  'topics' => 'Foswiki::Contrib::CopyContrib::TopicListAgent',
  'stub' => 'Foswiki::Contrib::CopyContrib::TopicStubAgent',
  'web' => 'Foswiki::Contrib::CopyContrib::WebAgent',
  'application' => 'Foswiki::Contrib::CopyContrib::ApplicationAgent', 
#  'webs' => 'Foswiki::Contrib::CopyContrib::WebListAgent',
);

sub registerAgent {
  my ($mode, $package) = @_;

  my $prevImpl = $agentImpls{$mode};

  $agentImpls{$mode} = $package;

  return $prevImpl;
}

sub copy {
  my $mode = shift;

  my $impl = $agentImpls{$mode};
  throw Error::Simple("Unknown copy mode '$mode'") unless defined $impl;

  my $path = $impl . '.pm';
  $path =~ s/::/\//g;
  eval {require $path};
  throw Error::Simple($@) if $@;

  my $session = $Foswik::Plugins::SESSION;
  my $agent = $impl->new($session, @_);
  my @result = $agent->copy();

  $agent->finish();

  return @result;
}

sub copyCgi {
  my $session = shift;

  my @result = ();
  my $msg = '';
  my $isCommandLine = Foswiki::Func::getContext()->{command_line};

  try {
    my $request = Foswiki::Func::getRequestObject();

    # check method
    unless ($isCommandLine) {
      my $method = $request->method();
      throw Error::Simple("Bad request: method $method not allowed")
        unless $method =~ /^post$/i;
    }

    my $mode = $request->param("mode");
    throw Error::Simple("No copy mode") unless defined $mode;

    my $impl = $agentImpls{$mode};
    throw Error::Simple("Unknown copy mode '$mode'") unless defined $impl;

    my $path = $impl . '.pm';
    $path =~ s/::/\//g;
    eval {require $path};
    throw Error::Simple($@) if $@;

    my $agent = $impl->new($session);
    @result = $agent->parseRequestObject($request)->copy();
    $agent->finish();
    
  } catch Error::Simple with {
    my $error = shift;
    my $text = $error->{-text};

    if ($isCommandLine) {
      $msg = "ERROR: ".$text;
    } else {
      throw Foswiki::OopsException("copy",
        def => "generic",
        params => [
          "Error during copy operation",
          $text,
        ]
      );
    }
    
  } catch Foswiki::OopsException with {
    my $error = shift;
    if ($isCommandLine) {
      $msg = "ERROR: ".$error->stringify;
    } else {
      throw $error; # forward
    }
  };
  
  if (@result) {
    $msg = renderTemplate(@result);
    $msg = Foswiki::Func::expandCommonVariables($msg);
  }

  if ($isCommandLine) {
    print $msg."\n";
  } else {
    my $target = $session->redirectto();

    if ($target) {
      $session->redirect($target);
    } else {
      my @params = ("Success");
      my $def = shift @result;
      push @params, @result;
      throw Foswiki::OopsException("copy",
        def => $def,
        params => \@params,
      );
    }
  }

  return;
}

our $_doneReadTemplate;

sub renderTemplate {
  my $def = shift;

  Foswiki::Func::readTemplate("oopscopy") unless $_doneReadTemplate;
  $_doneReadTemplate = 1;

  my $msg = Foswiki::Func::expandTemplate($def);

  my $n = 2;
  foreach my $param (@_) {
    $msg =~ s/%PARAM$n%/$param/g;
    $n++;
  }
  $msg =~ s/%PARAM\d+%//g;

  return $msg;
}

sub urlEncode {
  my $text = shift;

  $text = Encode::encode_utf8($text) if $Foswiki::UNICODE;
  $text =~ s/([^0-9a-zA-Z-_.:~!*'\/])/'%'.sprintf('%02x',ord($1))/ge;

  return $text;
}

1;
