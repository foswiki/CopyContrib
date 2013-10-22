# ---+ Extensions
# ---++ CopyContrib
# **PERL**
# This setting is required to enable executing the copy script from the bin directory
$Foswiki::cfg{SwitchBoard}{copy} = { 
  package  => 'Foswiki::Contrib::CopyContrib',
  function => 'copyCgi',
  context  => { copy => 1 },
};

1;
